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
				sendPeerData(localPeerData, to: [player])
				validateHandshakes()
			} else {
				GD.pushError("[GameCenterPeer] Found no local peerData to send")
			}

		case .disconnected:
			requiredHandshakes += 1			
			removePlayer(player)

		case .unknown:
			GD.pushWarning("[GameCenterPeer] \(player.displayName) Connection Unknown")
		}
	}

	func match(_ match: GKMatch, didFailWithError error: Error?) {
		if error != nil {
			GD.pushError("[GameCenterPeer] Match failed with error: \(error)")
		} else {
			GD.pushError("[GameCenterPeer] Match failed with unknown error")
		}

		self.matchmakingStatusUpdated.emit(MatchmakingStatus.failed.rawValue)
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
				// Received peerData from player
				guard !hasPeerData(for: player.gamePlayerID) else {
					GD.pushWarning("[GameCenterPeer] Got duplicate peerData, ignoring")
					return
				}

				//GD.print("<- RECEIVED\t peerData(\(data.count ?? 0) bytes) from \(player.displayName) (peerID: \(peerData.id!), mode: \(getTransferMode()))")
				setPeerData(for: player, data: peerData)

				requiredHandshakes -= 1
				if requiredHandshakes == 0 {
					setHandshakesComplete(for: GKLocalPlayer.local.gamePlayerID)
				}
				sendPingData(.handshakeCompleted(requiredHandshakes), to: [player])

				if isHandshakesComplete() && self.hostOriginalID == nil {
					decideHost()
				}

			} else if let data: [UInt8] = gameData?.bytes {
				guard let fromPeer = getPeerID(for: player) else {
					GD.pushError("[GameCenterPeer] Got data (\(data.count ?? 0) bytes) from unknown peer, peerData might have gotten lost.")
					self.inviteStatusUpdated.emit(InviteStatus.handshakeFailed.rawValue, player.displayName)
					disconnect()
					return
				}

				//GD.print("<- RECEIVED\t gameData(\(data.count ?? 0) bytes) from \(player.displayName) (peerID: \(fromPeer), mode: \(getTransferMode()))")
				let packet: Packet = Packet(data: data, from: fromPeer, channel: 0)
				incomingPackets.append(packet)

			} else if let pingData = gameData?.ping {
				switch pingData.type {
				case .handshakeRequest:
					if let localPeerData: PeerData = getPeerData(for: GKLocalPlayer.local) {
						sendPeerData(localPeerData, to: [player])
					} else {
						GD.pushError("[GameCenterPeer] Found no local peerData to send")
					}
				case .handshakeCompleted(let remaining):
					if remaining <= 0 {
						setHandshakesComplete(for: player.gamePlayerID)
					}

					if remaining == 0 && requiredHandshakes == 0 {
						decideHost()
					}
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
			self.inviteStatusUpdated.emit(InviteStatus.accepted.rawValue, player.displayName)
		case .declined:
			self.inviteStatusUpdated.emit(InviteStatus.declined.rawValue, player.displayName)
		case .failed:
			self.inviteStatusUpdated.emit(InviteStatus.failed.rawValue, player.displayName)
		case .incompatible:
			self.inviteStatusUpdated.emit(InviteStatus.incompatible.rawValue, player.displayName)
		case .unableToConnect:
			self.inviteStatusUpdated.emit(InviteStatus.unableToConnect.rawValue, player.displayName)
		case .noAnswer:
			self.inviteStatusUpdated.emit(InviteStatus.timeout.rawValue, player.displayName)
		}
	}

	// MARK: MatchDelegate

	// This class is just an intermediate because a @Godot class doesn't inherit from NSObject
	// which is required for GKMatchDelegate and GKLocalPlayerListener
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
