import Foundation
import SwiftGodot
import GameKit

struct DataPacket:Codable {
	//var peerID: Int32?
	var peerData: PeerData?
	var bytes: [UInt8]?
}

extension GameCenterMultiplayerPeer {
	// func encode(peerID: Int32) -> Data? {
	// 	let data: DataPacket = DataPacket(peerID:peerID)
	// 	return encode(dataPacket:data)
	// }

	// func encode(initiative:UInt32) -> Data? {
	// 	let data:DataPacket = DataPacket(initiative:initiative)
	// 	return encode(dataPacket: data)
	// }

	func encode(peerData:PeerData) -> Data? {
		let data:DataPacket = DataPacket(peerData: peerData)
		return encode(dataPacket: data)
	}

	func encode(packedByteArray:PackedByteArray) -> Data? {
		let bytes = [UInt8](packedByteArray)
		let data: DataPacket = DataPacket(bytes:bytes)
		return encode(dataPacket:data)
	}

	func encode(byteArray:[UInt8]) -> Data? {
		let data: DataPacket = DataPacket(bytes:byteArray)
		return encode(dataPacket:data)
	}

	func encode(dataPacket:DataPacket) -> Data? {
		let encoder: PropertyListEncoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data: Data = try encoder.encode(dataPacket)
			return data
		} catch {
			GD.print("Failed to encode data. Error: \(error)")
			return nil
		}
	}

	func decode(dataPacket:Data) -> DataPacket? {
		return try? PropertyListDecoder().decode(DataPacket.self, from: dataPacket)
	}
}