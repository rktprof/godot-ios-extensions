import Network
import SwiftGodot

@Godot
class NetworkMonitor: RefCounted {
	/// Signal that triggers when the network path changes
	///
	/// NOTE: This does not take into account Local Network permissions
	@Signal var networkStatusUpdated: SignalWithArguments<Int>

	enum NetworkStatus: Int {
		case available = 0
		case unavailable = 1
		case unknown = 2
	}

	enum NetworkPermission: Int {
		case allowed = 0
		case denied = 1
		case unknown = 2
	}

	var monitor: NWPathMonitor? = nil
	var connectionStatus: NetworkStatus = .unknown
	var permissionStatus: NetworkPermission = .unknown

	deinit {
		stop()
	}

	@Callable
	func start() {
		let monitor = NWPathMonitor()
		monitor.pathUpdateHandler = { path in
			switch path.status {
			case .satisfied:
				self.connectionStatus = NetworkStatus.available
			case .unsatisfied:
				self.connectionStatus = NetworkStatus.unavailable
			case .requiresConnection:
				self.connectionStatus = NetworkStatus.unknown
			}

			self.networkStatusUpdated.emit(self.connectionStatus.rawValue)
		}

		monitor.start(queue: DispatchQueue(label: "Monitor"))

		self.monitor = monitor
	}

	@Callable
	func stop() {
		monitor?.cancel()
	}

	@Callable(autoSnakeCase: true)
	func getCurrentStatus() -> Int {
		return connectionStatus.rawValue
	}

	@Callable(autoSnakeCase: true)
	func testLocalNetworkPermission(onComplete: Callable) {
		// NOTE: This is not a great solution, but until NWListener reports status correctly it's the only way
		// that I could think of.
		Task {
			do {
				let descriptor: NWBrowser.Descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
					type: "_bonjour._tcp",
					domain: "local."
				)

				let browser: NWBrowser = NWBrowser(for: descriptor, using: .tcp)
				self.permissionStatus = .allowed

				browser.stateUpdateHandler = { newState in
					GD.print("[Bonjour] LocalNetwork permission test status: \(newState)")
					switch newState {
					case let .waiting(error):
						if error.errorCode == -65570 {
							self.permissionStatus = .denied
							browser.cancel()
						}
					case .cancelled:
						switch self.permissionStatus {
						case .allowed: onComplete.callDeferred(Variant(true))
						case .denied: onComplete.callDeferred(Variant(false))
						case .unknown: onComplete.callDeferred(Variant(true))
						}
					default:
						// NOTE: Can't use .ready here since it sometimes triggers before .waiting
						break
					}
				}

				browser.start(queue: DispatchQueue.global(qos: .userInitiated))
				try await Task.sleep(nanoseconds: UInt64(0.5 * Double(NSEC_PER_SEC)))
				browser.cancel()
			} catch {
				GD.pushError("[Bonjour] Failed to test Local Network permission: \(error)")
				onComplete.callDeferred(Variant(false))
			}

		}
	}
}
