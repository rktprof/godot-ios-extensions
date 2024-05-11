import SwiftGodot
import Network

@Godot
class LocalNetworkDiscovery:RefCounted
{
	#signal("device_discovered", arguments: ["name": String.self, "port": Int.self, "hash_value": Int.self])
	#signal("device_lost", arguments: ["name": String.self, "hash_value": Int.self])
	#signal("device_updated", arguments: ["name": String.self, "old_hash_value":Int.self, "new_hash_value": Int.self])

	var browser:NWBrowser? = nil
	var connection:NWConnection? = nil
	var discoveredDevices: [Int: NWEndpoint] = [:]

	deinit
	{
		stop()
	}

	@Callable
	func start(typeDescriptor:String)
	{
		GD.print("Starting LocalNetworkDiscovery for \(typeDescriptor)...")
		let descriptor: NWBrowser.Descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(type: typeDescriptor, domain: "local.")
		let browser: NWBrowser = NWBrowser(for: descriptor, using: .tcp)

		browser.stateUpdateHandler = stateChanged(to:)
		browser.browseResultsChangedHandler = resultsChanged

		browser.start(queue: DispatchQueue.global(qos: .userInitiated))
		self.browser = browser
	}

	@Callable
	func stop()
	{
		browser?.stateUpdateHandler = nil
		browser?.browseResultsChangedHandler = nil
		browser?.cancel()
		GD.print("LocalNetworkDiscovery stopped")
	}

	@Callable
	func resolveEndpoint(hashValue:Int, port:Int, onComplete:Callable)
	{
		// This whole thing is unfortunately necessary since you can't resolve an endpoint to host:port
		if let endpoint: NWEndpoint = discoveredDevices[hashValue]
		{
			GD.print("Resolving endpoint \(endpoint)...")
			let params: NWParameters = NWParameters.tcp
			params.prohibitedInterfaceTypes = [.loopback]
			params.serviceClass = NWParameters.ServiceClass.responsiveData
			
			let ip: NWProtocolIP.Options = params.defaultProtocolStack.internetProtocol! as! NWProtocolIP.Options
			ip.version = .v4

			connection = NWConnection(to: endpoint, using: params)
			connection?.stateUpdateHandler = { state in
				switch state
				{
					case .ready:
						if let innerEndpoint: NWEndpoint = self.connection?.currentPath?.remoteEndpoint,
						case .hostPort(let host, let tempPort) = innerEndpoint {
							GD.print("Resolving... Success (\(host):\(tempPort))")
							self.connection?.cancel()

							var hostName:String = ""
							switch host
							{
								case .ipv4(let address):
									hostName = self.ipAddressToString(address)
									break;
								case .ipv6(let address):
									if let ipv4Address = address.asIPv4
									{
										hostName = self.ipAddressToString(ipv4Address)
									}
									else
									{
										GD.pushError("Resolving... Failed: Got incompatible IPv6 address")
									}
								default:
									break;

							}

							var params:GArray = GArray()
							params.append(value:Variant(hostName))
							params.append(value:Variant(port))
							onComplete.callv(arguments: params)
						}
					default:
						GD.print("Resolving... (\(state))")
						break
				}
			}
			connection?.start(queue: DispatchQueue.global(qos: .userInteractive))
			//connection?.start(queue: .global())
		}
		else
		{
			GD.pushError("Found no endpoint corresponding to the hashValue \(hashValue)")
		}
	}

	func stateChanged(to newState:NWBrowser.State)
	{
		switch newState
		{
			case .failed(let error):
				GD.pushError("LocalNetworkDiscovery failed: \(error.localizedDescription)")
			default:
				break
		}
	}

	func resultsChanged(updated:Set<NWBrowser.Result>, changes:Set<NWBrowser.Result.Change>)
	{
		for change: NWBrowser.Result.Change in changes
		{
			switch change
			{
				case .added(let result):
					GD.print("LocalNetworkDiscovery discovered server: \(result.endpoint.debugDescription), Meta: \(result.metadata) (\(result.hashValue))")
					var server_port:Int = 0

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
							emit(signal: LocalNetworkDiscovery.deviceDiscovered, service.name, server_port, result.hashValue)
						default:
							break
					}

					discoveredDevices[result.hashValue] = result.endpoint

				case .removed(let result):
					GD.print("LocalNetworkDiscovery lost server \(result.endpoint.debugDescription), Meta: \(result.metadata) (\(result.hashValue))")
					discoveredDevices.removeValue(forKey: result.hashValue)
					
					switch result.endpoint
					{
						case .service(let service):
							emit(signal: LocalNetworkDiscovery.deviceLost, service.name, result.hashValue)
						default:
							break
					}

				case .changed(old: let old, new: let new, flags: _):
					GD.print("LocalNetworkDiscovery server changed \(old.endpoint) -> \(new.endpoint)")

					discoveredDevices.removeValue(forKey: old.hashValue)
					discoveredDevices[new.hashValue] = new.endpoint

					switch new.endpoint
					{
						case .service(let service):
							emit(signal: LocalNetworkDiscovery.deviceUpdated, service.name, old.hashValue, new.hashValue)
						default:
							break
					}
				case .identical:
					break
			}
		}
	}

	// Helpers

	func ipAddressToString(_ address:IPv4Address) -> String
	{
		return String("\(address.rawValue[0]).\(address.rawValue[1]).\(address.rawValue[2]).\(address.rawValue[3])")
	}
}