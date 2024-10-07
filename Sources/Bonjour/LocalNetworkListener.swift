import Network
import SwiftGodot

@Godot
class LocalNetworkListener: RefCounted {
	static let DEFAULT_PORT: Int = 64201
	var listener: NWListener? = nil

	deinit {
		stop()
	}

	@Callable
	func start(typeDescriptor: String, name: String, port: Int, broadcast_port: Int = DEFAULT_PORT) {
		do {
			let broadcast_port: NWEndpoint.Port? = NWEndpoint.Port(rawValue: UInt16(broadcast_port))
			let listener: NWListener = try NWListener(using: .tcp, on: broadcast_port!)
			listener.service = .init(name: name, type: typeDescriptor, txtRecord: NWTXTRecord(["port": String(port)]))

			listener.stateUpdateHandler = self.stateChanged(to:)
			listener.newConnectionHandler = self.newConnection(connection:)
			listener.serviceRegistrationUpdateHandler = self.serviceRegistrationChange

			listener.start(queue: DispatchQueue.global(qos: .userInitiated))

			self.listener = listener
		} catch {
			GD.pushError("Failed to start LocalNetworkListener: \(error)")
		}
	}

	@Callable
	func stop() {
		listener?.stateUpdateHandler = nil
		listener?.newConnectionHandler = nil
		listener?.cancel()
		GD.print("LocalNetworkListener stopped")
	}

	func stateChanged(to newState: NWListener.State) {
		switch newState {
		case .ready:
			GD.print(
				"LocalNetworkListener listening on \(self.listener.debugDescription), port \(self.listener?.port?.debugDescription)"
			)
		case .failed(let error):
			GD.print("LocalNetworkListener failed, error: \(error)")
		default:
			break
		}
	}

	func serviceRegistrationChange(change: NWListener.ServiceRegistrationChange) {
		switch change {
		case .add(let endpoint):
			GD.print("LocalNetworkListener added: \(endpoint)")
		case .remove(let endpoint):
			GD.print("LocalNetworkListener removed: \(endpoint)")
		}
	}

	func newConnection(connection: NWConnection) {
		// We need to start the connection here to allow client to resolve the endpoint
		// Client closes the connection as soon as they are done
		connection.start(queue: DispatchQueue.global(qos: .background))
	}
}
