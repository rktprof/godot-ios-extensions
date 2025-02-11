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
	#signal("value_changed", arguments: ["id": String.self])

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

	@Callable
	func getString(id: String) -> String {
		guard let value = settings.string(forKey: id) else {
			return ""
		}
		return value
		//return settings.string(forKey: id)
	}

	@Callable
	func setString(id: String, value: String) {
		settings.set(value, forKey: id)
	}

	// MARK: Bool

	@Callable
	func getBool(id: String) -> Bool {
		return settings.bool(forKey: id)
	}

	@Callable
	func setBool(id: String, value: Bool) {
		settings.set(value, forKey: id)
	}

	// MARK: Integer

	@Callable
	func getInt(id: String) -> Int {
		return settings.integer(forKey: id)
	}

	@Callable
	func setInt(id: String, value: Int) {
		settings.set(value, forKey: id)
	}

	// MARK: Float

	@Callable
	func getFloat(id: String) -> Float {
		return settings.float(forKey: id)
	}

	@Callable
	func setFloat(id: String, value: Float) {
		settings.set(value, forKey: id)
	}

	// MARK: General

	@Callable
	func getValue(id: String) -> Variant {
		guard let value = settings.value(forKey: id) else {
			GD.pushWarning("Unknown id: \(id)")
			return Variant()
		}

		switch value {
		case is Int: return Variant(value as! Int)
		case is Float: return Variant(value as! Float)
		case is String: return Variant(value as! String)
		case is Bool: return Variant(value as! Bool)
		default:
			GD.pushWarning("Unhandled value: \(value) for \(id)")
			return Variant()
		}
	}

	@Callable
	func getKeys() -> GArray {
		var keys: GArray = GArray()

		for key in self.settings.dictionaryRepresentation().keys {
			keys.append(Variant(key))
		}

		return keys
	}

	@Callable
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
				// 	emit(signal: Settings.valueChanged, key, Variant(Int(new)))
				// case is Float:
				// 	emit(signal: Settings.valueChanged, key, Variant(Float(new))
				// case is String:
				// 	emit(signal: Settings.valueChanged, key, Variant(String(new))
				// case is Bool:
				// 	emit(signal: Settings.valueChanged, key, Variant(Bool(new))
				// default: GD.pushWarning("Unhandled value changed: \(new)")
				// }
			}
		}
	}

	func valueChanged(key: String) {
		emit(signal: Settings.valueChanged, key)
	}
}
#endif
