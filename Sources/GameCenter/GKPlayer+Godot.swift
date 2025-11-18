// Extension to convert UIImage & NSImage to the Godot friendly Image type

import GameKit
import SwiftGodotRuntime

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

extension GKPlayer {
	enum ImageConversionError: Error {
		case unsupportedPlatform
		case failedToGetImageData
	}

	func loadImage(size: GKPlayer.PhotoSize) async throws -> [UInt8] {
		#if canImport(UIKit)
		let photo: UIImage = try await self.loadPhoto(for: size)
		let picture = try convertImage(photo)
		return picture
		#elseif canImport(AppKit)
		let photo: NSImage = try await self.loadPhoto(for: size)
		let picture = try convertImage(photo)
		return picture
		#else
		throw ImageConversionError.unsupportedPlatform
		#endif
	}

	#if canImport(AppKit)
	func convertImage(_ image: NSImage) throws -> [UInt8] {
		guard let tiffRepresentation = image.tiffRepresentation else {
			throw ImageConversionError.failedToGetImageData
		}

		guard
			let pngData = NSBitmapImageRep(data: tiffRepresentation)?.representation(
				using: .png,
				properties: [:]
			)
		else {
			throw ImageConversionError.failedToGetImageData
		}

		return [UInt8](pngData)
	}
	#endif

	#if canImport(UIKit)
	func convertImage(_ image: UIImage) throws -> [UInt8] {
		guard let pngData: Data = image.pngData() else {
			throw ImageConversionError.failedToGetImageData
		}

		return [UInt8](pngData)
	}
	#endif
}
