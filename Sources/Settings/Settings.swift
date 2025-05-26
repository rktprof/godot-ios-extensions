#if canImport(Foundation)
import Foundation
import SwiftGodot

#if canImport(UIKit)
import UIKit
#endif

#initSwiftExtension(
	cdecl: "swift_entry_point",
	types: [
		Settings.self
	]
)

@Godot
class Settings: RefCounted {

	/// Signal called when an invite is send
	@Signal var valueChanged: SignalWithArguments<String>

	let settings: UserDefaults!
	var subscriptions = Set<NSKeyValueObservation>()

	required init() {
		self.settings = UserDefaults.standard
		super.init()

		observeChanges()
	}

	required init(nativeHandle: UnsafeRawPointer) {
		self.settings = UserDefaults.standard
		super.init(nativeHandle: nativeHandle)

		observeChanges()
	}

	// MARK: String

	@Callable(autoSnakeCase: true)
	func getString(id: String) -> String {
		guard let value = settings.string(forKey: id) else {
			return ""
		}

		return value
	}

	@Callable(autoSnakeCase: true)
	func setString(id: String, value: String) {
		settings.set(value, forKey: id)
	}

	// MARK: Bool

	@Callable(autoSnakeCase: true)
	func getBool(id: String) -> Bool {
		return settings.bool(forKey: id)
	}

	@Callable(autoSnakeCase: true)
	func setBool(id: String, value: Bool) {
		settings.set(value, forKey: id)
	}

	// MARK: Integer

	@Callable(autoSnakeCase: true)
	func getInt(id: String) -> Int {
		return settings.integer(forKey: id)
	}

	@Callable(autoSnakeCase: true)
	func setInt(id: String, value: Int) {
		settings.set(value, forKey: id)
	}

	// MARK: Float

	@Callable(autoSnakeCase: true)
	func getFloat(id: String) -> Float {
		return settings.float(forKey: id)
	}

	@Callable(autoSnakeCase: true)
	func setFloat(id: String, value: Float) {
		settings.set(value, forKey: id)
	}

	// MARK: General

	@Callable(autoSnakeCase: true)
	func getValue(id: String) -> Variant? {
		guard let value = settings.value(forKey: id) else {
			GD.pushWarning("Unknown id: \(id)")
			return nil
		}

		switch value {
		case is Int: return Variant(value as! Int)
		case is Float: return Variant(value as! Float)
		case is String: return Variant(value as! String)
		case is Bool: return Variant(value as! Bool)
		default:
			GD.pushWarning("Unhandled value: \(value) for \(id)")
			return nil
		}
	}

	@Callable(autoSnakeCase: true)
	func getKeys() -> VariantArray {
		var keys = VariantArray()

		for key in self.settings.dictionaryRepresentation().keys {
			keys.append(Variant(key))
		}

		return keys
	}

	@Callable(autoSnakeCase: true)
	func openAppSettings() {
		#if canImport(UIKit)
		if let appSettings = URL(string: UIApplication.openSettingsURLString) {
			UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
		}
		#endif
	}

	// MARK: Internal

	func observeChanges() {
		for key in self.settings.dictionaryRepresentation().keys {
			SettingsObserver(for: key) { old, new in
				GD.print("Setting \(key) changed: \(old) -> \(new)")
				self.valueChanged(key: key)

				// TODO: Figure out how to include the new value.
				// switch new {
				// case is Int:
				// 	valueChanged.emit(key, Variant(Int(new)))
				// case is Float:
				// 	valueChanged.emit(key, Variant(Float(new))
				// case is String:
				// 	valueChanged.emit(key, Variant(String(new))
				// case is Bool:
				// 	valueChanged.emit(key, Variant(Bool(new))
				// default: GD.pushWarning("Unhandled value changed: \(new)")
				// }
			}
		}
	}

	func valueChanged(key: String) {
		valueChanged.emit(key)
	}
}
#endif
