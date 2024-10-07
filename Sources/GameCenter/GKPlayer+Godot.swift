// Extension to convert UIImage & NSImage to the Godot friendly Image type

import GameKit
import SwiftGodot

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

	func loadImage(size: GKPlayer.PhotoSize) async throws -> Image {
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
	func convertImage(_ image: NSImage) throws -> Image {
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

		let image: Image = Image()
		image.loadPngFromBuffer(PackedByteArray([UInt8](pngData)))
		return image
	}
	#endif

	#if canImport(UIKit)
	func convertImage(_ image: UIImage) throws -> Image {
		guard let pngData: Data = image.pngData() else {
			throw ImageConversionError.failedToGetImageData
		}

		let image: Image = Image()
		image.loadPngFromBuffer(PackedByteArray([UInt8](pngData)))
		return image
	}
	#endif
}
