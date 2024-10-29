import GameKit
import SwiftGodot

struct PeerData: Codable {
	var id: Int32?
	var initiative: UInt32?
}

extension GameCenterMultiplayerPeer {

	func setPeerData(for player: GKPlayer, data: PeerData) {
		setPeerData(for: player.gamePlayerID, data: data)
	}

	func setPeerData(for gamePlayerID: String, data: PeerData) {
		peerMap[gamePlayerID] = data
	}

	func getPeerData(for player: GKPlayer) -> PeerData? {
		return getPeerData(for: player.gamePlayerID)
	}

	func getPeerData(for gamePlayerID: String) -> PeerData? {
		return peerMap[gamePlayerID]
	}

	func getNameFor(for peerID: Int32) -> String {
		if peerID == 0 {
			return "All players"
		}
		if peerID < 0 {
			var exclude: Int32 = -peerID
			if let currentMatch = match {
				for player in currentMatch.players {
					if let exclude = getPeerData(for: player)?.id {
						return "All players, excluding \(player.displayName)"
					}
				}
			}

			return "All players, excluding Unknown"
		}

		if peerID == uniqueID {
			return GameKit.GKLocalPlayer.local.displayName
		}

		if let currentMatch = match {
			for player in currentMatch.players {
				if let peerID = getPeerData(for: player)?.id {
					return player.displayName
				}
			}
		}

		return "Unknown"
	}

	func setPeerID(for player: GKPlayer, id: Int32) {
		setPeerID(for: player.gamePlayerID, id: id)
	}

	func setPeerID(for gamePlayerID: String, id: Int32) {
		if let peerData = peerMap[gamePlayerID] {
			peerMap[gamePlayerID] = PeerData(id: id, initiative: peerData.initiative)
		} else {
			peerMap[gamePlayerID] = PeerData(id: id)
		}
	}

	func getPeerID(for player: GKPlayer) -> Int32? {
		return getPeerID(for: player.gamePlayerID)
	}

	func getPeerID(for gamePlayerID: String) -> Int32? {
		return peerMap[gamePlayerID]?.id
	}

	func removePeer(withID gamePlayerID: String) -> PeerData? {
		return peerMap.removeValue(forKey: gamePlayerID)
	}

	func getInitiative(for player: GKPlayer) -> UInt32? {
		return getInitiative(for: player.gamePlayerID)
	}

	func getInitiative(for gamePlayerID: String) -> UInt32? {
		return peerMap[gamePlayerID]?.initiative
	}

	func getPlayerWithHighestInitiative() -> GKPlayer? {
		var highestInitiative: UInt32 = 0
		var playerID: String = ""

		for key: String in peerMap.keys {
			if let initiative = peerMap[key]?.initiative {
				if initiative > highestInitiative {
					highestInitiative = initiative
					playerID = key
				}
			}
		}

		return getPlayerWithID(gamePlayerID: playerID)
	}

	func getPlayerWithID(gamePlayerID: String) -> GKPlayer? {
		if let players: [GKPlayer] = match?.players {
			for player: GKPlayer in players {
				if player.gamePlayerID == gamePlayerID {
					return player
				}
			}
		}

		return nil
	}

	func getPlayerWithID(peerID: Int32) -> GKPlayer? {
		if let players: [GKPlayer] = match?.players {
			for player: GKPlayer in players {
				if getPeerID(for: player.gamePlayerID) == peerID {
					return player
				}
			}
		}

		return nil
	}

	func getPlayerCount() -> Int {
		return peerMap.count
	}

	func clearPeers() {
		peerMap.removeAll()
	}

	func generateInitiative() -> UInt32 {
		return UInt32.random(in: 1..<UInt32.max)
	}
}
