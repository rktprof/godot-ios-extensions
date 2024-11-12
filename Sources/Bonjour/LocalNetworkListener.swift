import Network
import SwiftGodot

@Godot
class LocalNetworkListener: RefCounted {
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

			listener.stateUpdateHandler = self.stateChanged(to:)
			listener.newConnectionHandler = self.newConnection(connection:)
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
		listener?.stateUpdateHandler = nil
		listener?.newConnectionHandler = nil
	}

	func stateChanged(to newState: NWListener.State) {
		switch newState {
		case .ready:
			break
		case .failed(let error):
			GD.pushError("[Bonjour] Listener failed. Error: \(error)")
			break
		case .setup:
			break
		case .waiting(_):
			break
		case .cancelled:
			break
		}
	}

	func serviceRegistrationChange(change: NWListener.ServiceRegistrationChange) {
		// switch change {
		// case .add(let endpoint):
		// 	GD.print("[Bonjour] Added endpoint: \(endpoint)")
		// case .remove(let endpoint):
		// 	GD.print("[Bonjour] Removed endpoint: \(endpoint)")
		// }
	}

	func newConnection(connection: NWConnection) {
		// We need to start the connection here to allow client to resolve the endpoint
		// Client closes the connection as soon as they are done
		connection.start(queue: DispatchQueue.global(qos: .background))
	}
}
