import Network
import SwiftGodot

@Godot
class LocalNetworkListener: RefCounted {
	/// Signal that triggers when the local network permission is known
	/// NOTE: Does NOT work the same as for the browser, use the NetworkMonitor instead
	@Signal var permissionDenied: SimpleSignal

	@Signal var endpointAdded: SignalWithArguments<String, Int, Int>
	@Signal var endpointRemoved: SignalWithArguments<String, Int, Int>

	enum InterfaceType: Int {
		case wifi = 0
		case cellular = 1
		case wiredEthernet = 2
		case loopback = 3
		case other = 4
	}

	static let DEFAULT_PORT: Int = 64201
	var listener: NWListener? = nil

	deinit {
		stop()
	}

	/// Start listening for incoming network connections.
	///
	/// - Parameter:
	/// 	- typeDescriptor: A service descriptor used to identify a Bonjour service.
	/// 	- name: The name that will show up when this device is discovered.
	/// 	- port: The port that will accept connections.
	/// 	- broadcastPort: The port that will be used to listen for connections (Default: 64201)
	@Callable
	func start(typeDescriptor: String, name: String, port: Int, broadcastPort: Int = DEFAULT_PORT) {
		do {
			let broadcast_port: NWEndpoint.Port? = NWEndpoint.Port(rawValue: UInt16(broadcastPort))
			let listener: NWListener = try NWListener(using: .tcp, on: broadcast_port!)
			listener.service = .init(name: name, type: typeDescriptor, txtRecord: NWTXTRecord(["port": String(port)]))

			listener.stateUpdateHandler = self.stateChanged
			listener.newConnectionHandler = self.newConnection
			listener.serviceRegistrationUpdateHandler = self.serviceRegistrationChange

			listener.start(queue: DispatchQueue.global(qos: .userInitiated))

			self.listener = listener
		} catch {
			GD.pushError("[Bonjour] Failed to start LocalNetworkListener: \(error)")
		}
	}

	/// Stop listening for incoming network connections.
	@Callable
	func stop() {
		listener?.cancel()
	}

	// MARK: Internal

	func stateChanged(to newState: NWListener.State) {
		// NOTE: The state is changed to ready even if there are no local network permissions
		switch newState {
		case .failed(let error):
			GD.pushError("[Bonjour] Listener failed. Error: \(error)")
		case let .waiting(error):
			// This does not seem to trigger, need a better solution
			GD.pushError("[Bonjour] Listener waiting: \(error)")
			self.permissionDenied.emit()
		default:
			break
		}
	}

	func serviceRegistrationChange(change: NWListener.ServiceRegistrationChange) {
		switch change {
		case .add(let endpoint):
			if let interface = endpoint.interface {
				var type: InterfaceType = .other
				switch interface.type {
				case .wifi: type = .wifi
				case .cellular: type = .cellular
				case .wiredEthernet: type = .wiredEthernet
				case .loopback: type = .loopback
				case .other: type = .other
				}
				self.endpointAdded.emit(interface.name, type.rawValue, interface.index)
			} else {
				self.endpointAdded.emit("unknown", InterfaceType.other.rawValue, 0)
			}

		case .remove(let endpoint):
			if let interface = endpoint.interface {
				var type: InterfaceType = .other
				switch interface.type {
				case .wifi: type = .wifi
				case .cellular: type = .cellular
				case .wiredEthernet: type = .wiredEthernet
				case .loopback: type = .loopback
				case .other: type = .other
				}
				self.endpointRemoved.emit(interface.name, type.rawValue, interface.index)
			} else {
				self.endpointRemoved.emit("unknown", InterfaceType.other.rawValue, 0)
			}
		}
	}

	func newConnection(connection: NWConnection) {
		// We need to start the connection here to allow client to resolve the endpoint
		// Client closes the connection as soon as they are done
		connection.start(queue: DispatchQueue.global(qos: .background))
	}
}
