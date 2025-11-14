import Foundation
import GameKit
import SwiftGodotRuntime

struct DataPacket: Codable {
	var peerData: PeerData?
	var bytes: [UInt8]?
	var ping: PingData?
}

struct PingData: Codable {
	enum PingType: Codable {
		case handshakeRequest
		case handshakeCompleted(Int)
	}

	var type: PingType

	init(_ type: PingType) {
		self.type = type
	}
}

extension GameCenterMultiplayerPeer {
	func encode(peerData: PeerData) -> Data? {
		let data: DataPacket = DataPacket(peerData: peerData)
		return encode(dataPacket: data)
	}

	func encode(pingData: PingData) -> Data? {
		let data: DataPacket = DataPacket(ping: pingData)
		return encode(dataPacket: data)
	}

	func encode(packedByteArray: PackedByteArray) -> Data? {
		let data: DataPacket = DataPacket(bytes: packedByteArray.asBytes())
		return encode(dataPacket: data)
	}

	func encode(byteArray: [UInt8]) -> Data? {
		let data: DataPacket = DataPacket(bytes: byteArray)
		return encode(dataPacket: data)
	}

	func encode(dataPacket: DataPacket) -> Data? {
		let encoder: PropertyListEncoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data: Data = try encoder.encode(dataPacket)
			return data
		} catch {
			GD.pushError("Failed to encode data. Error: \(error)")
			return nil
		}
	}

	func decode(dataPacket: Data) -> DataPacket? {
		do {
			return try PropertyListDecoder().decode(DataPacket.self, from: dataPacket)
		} catch {
			GD.pushError("Failed to decode data. Error: \(error)")
			return nil
		}
	}
}
