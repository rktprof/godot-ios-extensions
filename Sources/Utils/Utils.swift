import StoreKit
import SwiftGodot

#initSwiftExtension(
	cdecl: "swift_entry_point",
	types: [
		Utils.self
	]
)

let OK: Int = 0
let UNVERIFIED: Int = 1
let ERROR: Int = 2

@Godot
class Utils: RefCounted {

	// MARK: AppTransaction

	/// Gets the current environment.
	///
	/// NOTE: Only works after authenticating, otherwise it might ask the user to authenticate
	@Callable
	public func getEnvironment(onComplete: Callable) {
		if #available(iOS 16.0, *) {
			Task {
				do {
					let result = try await AppTransaction.shared
					switch result {
					case .verified(let appTransaction):
						onComplete.callDeferred(Variant(OK), Variant(appTransaction.environment.rawValue))
					case .unverified(let appTransaction, let verificationError):
						onComplete.callDeferred(Variant(UNVERIFIED), Variant(appTransaction.environment.rawValue))
					}
				} catch {
					GD.print("Failed to get appTransaction, error: \(error)")
					onComplete.callDeferred(Variant(ERROR), Variant(""))
				}
			}
		} else {
			guard let path = Bundle.main.appStoreReceiptURL?.path else {
				onComplete.callDeferred(Variant(ERROR), Variant(""))
				return
			}

			if path.contains("CoreSimulator") {
				onComplete.callDeferred(Variant(OK), Variant("xcode"))
			} else if path.contains("sandboxReceipt") {
				onComplete.callDeferred(Variant(OK), Variant("sandbox"))
			} else {
				onComplete.callDeferred(Variant(OK), Variant("production"))
			}
		}
	}

	/// Refresh the App Store signed app transaction (only iOS 16+)
	///
	/// NOTE: This will display a system prompt that asks users to authenticate
	@Callable
	public func refreshAppTransaction(onComplete: Callable) {
		if #available(iOS 16.0, *) {
			Task {
				do {
					try await AppTransaction.refresh()
					onComplete.callDeferred(Variant(OK))
				} catch {
					onComplete.callDeferred(Variant(ERROR))
				}
			}
		} else {
			onComplete.callDeferred(Variant(OK))
		}
	}
}
