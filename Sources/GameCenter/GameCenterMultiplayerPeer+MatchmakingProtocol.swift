import GameKit
import SwiftGodot

extension GameCenterMultiplayerPeer: GameCenterMatchmakingProtocol {
	// Connection flow
	// The Godot MultiplayerPeerExtension system has some requirements that we have to work around, so the connection flow looks something like this:
	// connect to player -> send id + initiative roll -> add player locally -> if enough players -> decide host -> if we fail to decide host, use initiative roll -> connection complete

	func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
		switch state {
		case .connected:
			// Send my peer data to player
			if let localPeerData: PeerData = getPeerData(for: GKLocalPlayer.local) {
				sendPeerData(localPeerData, to: [player], with: .reliable)
			} else {
				GD.pushError("[GameCenterPeer] Found no local peerData to send")
			}

		case .disconnected:
			removePlayer(player)

		default:
			GD.pushWarning("[GameCenterPeer] \(player.displayName) Connection Unknown \(state)")
		}
	}

	func match(_ match: GKMatch, didFailWithError error: Error?) {
		if error != nil {
			GD.pushError("[GameCenterPeer] Match failed with error: \(error)")
		} else {
			GD.pushError("[GameCenterPeer] Match failed with unknown error")
		}

		emit(signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated, MatchmakingStatus.failed.rawValue)
	}

	func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
		GD.print("[GameCenterPeer] Disconnected, should reinvite: \(shouldReinvite)")
		if shouldReinvite {
			shouldReinvite = false
			return true
		} else {
			return false
		}
	}

	func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
		do {
			let gameData = decode(dataPacket: data)

			if let peerData: PeerData = gameData?.peerData {
				// Player sent peerData
				//GD.print("<- RECEIVED\t peerData from \(player.displayName), id: \(peerData.id!)")
				setPeerData(for: player, data: peerData)

				if match.expectedPlayerCount == 0 {
					decideHost()
				}
			} else if let data: [UInt8] = gameData?.bytes {
				if let fromPeer: Int32 = getPeerID(for: player) {
					//GD.print("<- RECEIVED\t gameData(\(data.count) bytes) from \(player.displayName) (id: \(fromPeer))")
					let packet: Packet = Packet(data: data, from: fromPeer, channel: 0)
					incomingPackets.append(packet)
				} else {
					GD.pushError(
						"[GameCenterPeer] ERROR: Got data from unknown peer, peerData might have gotten lost. Closing connection"
					)
					emit(
						signal: GameCenterMultiplayerPeer.inviteStatusUpdated,
						InviteStatus.handshakeFailed.rawValue,
						player.displayName
					)
					shouldReinvite = true
					disconnect()
				}
			} else {
				GD.pushWarning("[GameCenterPeer] Got unhandled data packet")
			}
		} catch {
			GD.pushError("[GameCenterPeer] Error when reciving data \(error)")
		}
	}

	func match(
		_ match: GKMatch,
		didReceive data: Data,
		forRecipient recipient: GKPlayer,
		fromRemotePlayer player: GKPlayer
	) {
		if recipient == GKLocalPlayer.local {
			self.match(match, didReceive: data, fromRemotePlayer: player)
		} else {
			// TODO: Handle this case, are we a relay?
		}
	}

	func invitationResponseHandler(player: GKPlayer, response: GKInviteRecipientResponse) {
		switch response {
		case .accepted:
			emit(
				signal: GameCenterMultiplayerPeer.inviteStatusUpdated,
				InviteStatus.accepted.rawValue,
				player.displayName
			)
		case .declined:
			emit(
				signal: GameCenterMultiplayerPeer.inviteStatusUpdated,
				InviteStatus.declined.rawValue,
				player.displayName
			)
		case .failed:
			emit(
				signal: GameCenterMultiplayerPeer.inviteStatusUpdated,
				InviteStatus.failed.rawValue,
				player.displayName
			)
		case .incompatible:
			emit(
				signal: GameCenterMultiplayerPeer.inviteStatusUpdated,
				InviteStatus.incompatible.rawValue,
				player.displayName
			)
		case .unableToConnect:
			emit(
				signal: GameCenterMultiplayerPeer.inviteStatusUpdated,
				InviteStatus.unableToConnect.rawValue,
				player.displayName
			)
		case .noAnswer:
			emit(
				signal: GameCenterMultiplayerPeer.inviteStatusUpdated,
				InviteStatus.timeout.rawValue,
				player.displayName
			)
		}
	}

	// MARK: MatchDelegate

	// This class is just an intermediate because a @Godot class doesn't inherit from NSObject
	// which is required for GKMatchDelegate and GKLocalPlayerListener
	// TODO: Move GKLocalPlayerListener elsewhere
	class MatchDelegate: NSObject, GKMatchDelegate {
		var delegate: GameCenterMatchmakingProtocol

		required init(withDelegate delegate: GameCenterMatchmakingProtocol) {
			self.delegate = delegate
			super.init()
		}

		func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
			delegate.match(match, player: player, didChange: state)
		}

		func match(_ match: GKMatch, didFailWithError error: Error?) {
			delegate.match(match, didFailWithError: error)
		}

		func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
			return delegate.match(match, shouldReinviteDisconnectedPlayer: player)
		}

		func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
			delegate.match(match, didReceive: data, fromRemotePlayer: player)
		}

		func match(
			_ match: GKMatch,
			didReceive data: Data,
			forRecipient recipient: GKPlayer,
			fromRemotePlayer player: GKPlayer
		) {
			delegate.match(match, didReceive: data, forRecipient: recipient, fromRemotePlayer: player)
		}
	}
}
