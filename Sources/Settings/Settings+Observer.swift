#if canImport(Foundation)
import Foundation
import SwiftGodot

extension Settings {
	class SettingsObserver: NSObject {
		let id: String
		private var onChange: (Any, Any) -> Void

		init(for id: String, onChange: @escaping (Any, Any) -> Void) {
			self.onChange = onChange
			self.id = id
			super.init()
			UserDefaults.standard.addObserver(self, forKeyPath: id, options: [.old, .new], context: nil)
		}

		deinit {
			UserDefaults.standard.removeObserver(self, forKeyPath: id, context: nil)
		}

		override func observeValue(
			forKeyPath keyPath: String?,
			of object: Any?,
			change: [NSKeyValueChangeKey: Any]?,
			context: UnsafeMutableRawPointer?
		) {
			guard let change = change, object != nil, keyPath == self.id else { return }
			onChange(change[.oldKey] as Any, change[.newKey] as Any)
		}
	}
}
#endif
