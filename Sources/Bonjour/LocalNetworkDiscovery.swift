import Network
import SwiftGodot

let OK: Int = 0

@Godot
class LocalNetworkDiscovery: RefCounted {
	/// Signal that triggers when a device is discovered
	///
	/// > NOTE: If you need the address of the device you can use `resolveEndpoint` with the hash_value
	#signal("device_discovered", arguments: ["name": String.self, "port": Int.self, "hash_value": Int.self])
	/// Signal that triggers when a device is lost
	#signal("device_lost", arguments: ["name": String.self, "hash_value": Int.self])
	/// Signal that triggers when a device is updated
	#signal(
		"device_updated",
		arguments: ["name": String.self, "port": Int.self, "old_hash_value": Int.self, "new_hash_value": Int.self]
	)
	/// Signal that triggers when the local network permission is known
	#signal("permission_denied")

	enum LocalNetworkStatus: Int {
		case permissionGranted = 0
		case permissionDenied = 1
		case error = 2
	}

	enum NetworkDiscoveryError: Int, Error {
		case failedToResolveEndpoint = 1
		case incompatibleIPV6Address = 2
	}

	var browser: NWBrowser? = nil
	var connection: NWConnection? = nil
	var discoveredDevices: [Int: (NWBrowser.Result)] = [:]

	deinit {
		self.stop()
	}

	/// Start looking for Bonjour devices on the local network.
	///
	/// - Parameter:
	/// 	- typeDescriptor: A service descriptor used to discover a Bonjour service.
	@Callable
	func start(typeDescriptor: String) {
		DispatchQueue.main.async {
			let descriptor: NWBrowser.Descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
				type: typeDescriptor,
				domain: "local."
			)
			let browser: NWBrowser = NWBrowser(for: descriptor, using: .tcp)

			browser.stateUpdateHandler = self.stateChanged(to:)
			browser.browseResultsChangedHandler = self.resultsChanged

			browser.start(queue: DispatchQueue.global(qos: .userInitiated))
			self.browser = browser
		}
	}

	/// Stop looking for Bonjour devices
	@Callable
	func stop() {
		if browser == nil {
			return
		}

		browser?.stateUpdateHandler = nil
		browser?.browseResultsChangedHandler = nil
		browser?.cancel()
		browser = nil
	}

	// MARK: Internal

	/// Resolve a Bonjour endpoint into an ip address and port.
	///
	/// - Parameters:
	///		- hashValue: The hash value for the discovered bonjour service.
	///		- onComplete: Callback with parameter: (error: Variant, address: Variant, port: Variant) -> (error: Int, address: String, port: Int)
	func resolveEndpoint(hashValue: Int, onComplete: Callable) {
		DispatchQueue.main.async {
			// This whole thing is unfortunately necessary since you can't resolve an endpoint to host:port
			if let result: NWBrowser.Result = self.discoveredDevices[hashValue] {
				GD.print("Resolving endpoint \(result.endpoint)...")
				let endpoint: NWEndpoint = result.endpoint
				var port: Int = 0
				switch result.metadata {
				case .bonjour(let record):
					port = Int(record.dictionary["port"] ?? "0") ?? 0
				default:
					break
				}

				let networkParams: NWParameters = NWParameters.tcp
				networkParams.prohibitedInterfaceTypes = [.loopback]
				networkParams.serviceClass = NWParameters.ServiceClass.responsiveData

				let ip: NWProtocolIP.Options =
					networkParams.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
				ip.version = .v4

				self.connection = NWConnection(to: endpoint, using: networkParams)
				self.connection?.stateUpdateHandler = { state in
					GD.print("Resolver state: \(state)")
					switch state {
					case .ready:
						if let innerEndpoint: NWEndpoint = self.connection?.currentPath?.remoteEndpoint,
							case .hostPort(let host, let tempPort) = innerEndpoint
						{
							self.connection?.cancel()

							var address_string: String = ""
							switch host {
							case .ipv4(let address):
								address_string = self.ipAddressToString(address)
								break
							case .ipv6(let address):
								if let ipv4Address = address.asIPv4 {
									address_string = self.ipAddressToString(ipv4Address)
								} else {
									GD.pushError("[Bonjour] Failed to resolve endpoint: Got incompatible IPv6 address")
									onComplete.callDeferred(
										Variant(NetworkDiscoveryError.incompatibleIPV6Address.rawValue),
										Variant(),
										Variant()
									)
									return
								}
							default:
								break
							}

							onComplete.callDeferred(Variant(OK), Variant(address_string), Variant(port))
						}
					default:
						break
					}
				}
				self.connection?.start(queue: DispatchQueue.global(qos: .userInteractive))
			} else {
				GD.pushError("[Bonjour] Failed to resolve endpoint. Error: No endpoint corresponding to: \(hashValue)")
				onComplete.callDeferred(
					Variant(NetworkDiscoveryError.failedToResolveEndpoint.rawValue),
					Variant(),
					Variant()
				)
			}
		}
	}

	func stateChanged(to newState: NWBrowser.State) {
		switch newState {
		case .failed(let error):
			GD.pushError("[Bonjour] LocalNetworkDiscovery failed: \(error)")
		case let .waiting(error):
			emit(signal: LocalNetworkDiscovery.permissionDenied)
		default:
			break
		}
	}

	func resultsChanged(updated: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
		DispatchQueue.main.async {
			for change: NWBrowser.Result.Change in changes {
				switch change
				{
				case .added(let result):
					var server_port: Int = 0

					switch result.metadata
					{
					case .bonjour(let record):
						server_port = Int(record.dictionary["port"] ?? "0") ?? 0
					default:
						break
					}

					switch result.endpoint
					{
					case .service(let service):
						self.emit(
							signal: LocalNetworkDiscovery.deviceDiscovered,
							service.name,
							server_port,
							result.hashValue
						)
					default:
						break
					}

					self.discoveredDevices[result.hashValue] = result

				case .removed(let result):
					self.discoveredDevices.removeValue(forKey: result.hashValue)

					switch result.endpoint
					{
					case .service(let service):
						self.emit(signal: LocalNetworkDiscovery.deviceLost, service.name, result.hashValue)
					default:
						break
					}

				case .changed(let old, let new, flags: _):
					var server_port: Int = 0
					switch new.metadata
					{
					case .bonjour(let record):
						server_port = Int(record.dictionary["port"] ?? "0") ?? 0
					default:
						break
					}

					switch new.endpoint
					{
					case .service(let service):
						self.emit(
							signal: LocalNetworkDiscovery.deviceUpdated,
							service.name,
							server_port,
							old.hashValue,
							new.hashValue
						)
					default:
						break
					}

					self.discoveredDevices.removeValue(forKey: old.hashValue)
					self.discoveredDevices[new.hashValue] = new
				case .identical:
					break
				}
			}
		}
	}

	func ipAddressToString(_ address: IPv4Address) -> String {
		return String("\(address.rawValue[0]).\(address.rawValue[1]).\(address.rawValue[2]).\(address.rawValue[3])")
	}

	// MARK: Godot callables

	@Callable
	func resolve_endpoint(hashValue: Int, onComplete: Callable) {
		resolveEndpoint(hashValue: hashValue, onComplete: onComplete)
	}
}
