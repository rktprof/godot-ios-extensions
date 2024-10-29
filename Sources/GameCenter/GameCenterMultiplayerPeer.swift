import GameKit
import SwiftGodot

@Godot
class GameCenterMultiplayerPeer: MultiplayerPeerExtension, GameCenterMatchmakingProtocol {
	let HOST_ID: Int32 = 1
	let RESERVED_CHANNELS: Int32 = 2

	/// Called when a match is finalized
	#signal("server_created")
	/// Called when the `MatchmakingStatus` changes
	#signal("matchmaking_status_updated", arguments: ["status": Int.self])
	/// Called when `InviteStatus` is updated
	#signal("invite_status_updated", arguments: ["status": Int.self, "player": String.self])

	enum Mode: Int {
		case none = 0
		case server, client, mesh
	}

	/// MatchmakingStatus
	enum MatchmakingStatus: Int {
		case successful = 0
		case failed = 1
		case timeout = 2
	}

	/// InviteStatus
	enum InviteStatus: Int {
		case accepted = 0
		case declined = 1
		case failed = 2
		case incompatible = 3
		case unableToConnect = 4
		case timeout = 5
		case invalid = 6
		case notFound = 7
		/// Triggered when we receive data from an unkown peer, usually because peerData was dropped
		case handshakeFailed = 8
	}

	enum MultiplayerPeerError: Int, Error {
		case unknownPeer = 1
	}

	struct Packet {
		var data: [UInt8]
		var from: Int32 = 0
		var channel: Int32 = 0
		var transferMode: MultiplayerPeer.TransferMode = .reliable
	}

	var delegate: MatchDelegate?

	var activeMode: Mode = .none
	var uniqueID: Int32 = 0
	var targetPeer: Int32 = 0

	var connectionStatus: MultiplayerPeer.ConnectionStatus = .disconnected

	var currentTransferMode: MultiplayerPeer.TransferMode = .reliable
	var currentTransferChannel: Int32 = 0
	var refuseConnections: Bool = false

	var incomingPackets: [Packet] = []
	var currentPacket: Packet?

	var peerMap: [String: PeerData] = [:]  // Maps gamePlayerID to PeerData
	var hostOriginalID: Int32?
	var match: GKMatch?
	var isMatching: Bool = false
	var shouldReinvite: Bool = false

	required init() {
		super.init()
		connectionStatus = .connecting
		delegate = MatchDelegate(withDelegate: self)
	}

	required init(nativeHandle: UnsafeRawPointer) {
		super.init(nativeHandle: nativeHandle)
		connectionStatus = .connecting
		delegate = MatchDelegate(withDelegate: self)
	}

	// MARK: Godot functions

	/// Start a game by inviting players
	///
	/// - Parameters:
	/// 	- playerIDs: An array of playerIDs to invite
	@Callable
	func invitePlayers(playerIDs: [String]) {
		Task {
			if isMatching {
				stopMatchmaking()
			}

			isMatching = true
			connectionStatus = .connecting

			// Generate PeerData
			// Note that generateUniqueID generates a UInt32 but they always request an Int32, so it's potentially
			// truncated here which might cause issues
			// TODO: Make sure we handle duplicate id's
			setPeerData(
				for: GKLocalPlayer.local,
				data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative())
			)

			let request: GKMatchRequest = GKMatchRequest()
			let players: [GKPlayer]

			do {
				let players: [GKPlayer] = try await GKLocalPlayer.local.loadFriends(identifiedBy: playerIDs)
				request.recipients = players
				request.recipientResponseHandler = invitationResponseHandler
			} catch {
				GD.pushError("[GameCenterPeer] Could not find player. Error: \(error)")
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, InviteStatus.notFound.rawValue, "")
				return
			}

			do {
				match = try await GKMatchmaker.shared().findMatch(for: request)
				match?.delegate = self.delegate
			} catch {
				GD.pushError("[GameCenterPeer] Failed to invite player. Error: \(error)")
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, InviteStatus.timeout.rawValue, "")
				return
			}
		}
	}

	/// Join a game recieved through an invite
	///
	/// > NOTE: You need to listen to the ``invite_received`` signal in the GameCenter class
	/// 		in order to get the invite index.
	///
	/// - Parameters:
	/// 	- inviteIndex: The index of the invite you wish to join.
	@Callable
	func joinGame(inviteIndex: Int) {
		Task {
			if isMatching {
				stopMatchmaking()
			}

			connectionStatus = .connecting

			// Generate PeerData
			// Note that generateUniqueID generates a UInt32 but they always request an Int32, so it's potentially
			// truncated here which might cause issues
			// TODO: Make sure we handle duplicate id's
			setPeerData(
				for: GKLocalPlayer.local,
				data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative())
			)

			if let invite: GKInvite = GameCenter.instance?.getInvite(withIndex: inviteIndex) {
				do {
					isMatching = true
					match = try await GKMatchmaker.shared().match(for: invite)
					match?.delegate = self.delegate

					GameCenter.instance?.removeInvite(withIndex: inviteIndex)
				} catch {
					GD.pushError("[GameCenterPeer] Unable to join game: \(error)")
					emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, InviteStatus.timeout.rawValue, "")

					// NOTE: Removing the invite here will prevent retrying it, which might not be ideal
					GameCenter.instance?.removeInvite(withIndex: inviteIndex)
					return
				}
			} else {
				GD.pushError("[GameCenterPeer] Unable to join game: No invite at index \(inviteIndex)")
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, InviteStatus.invalid.rawValue, "")
				return
			}
		}
	}

	/// Start matchmaking
	///
	/// - Parameters:
	/// 	- minPlayers: The minimum amount of players required to start a game.
	/// 	- maxPlayers: The maximum amount of players.
	/// 	- playerGroup: A number identifying a subset of players invited to join a match. This number must match for players to find eachother
	/// 	- playerAttributes: A mask that specifies the role that the local player would like to play in the game.
	@Callable
	func startMatchmaking(minPlayers: Int, maxPlayers: Int, playerGroup: Int, playerAttributes: Int) {
		Task {
			if isMatching {
				stopMatchmaking()
			}

			connectionStatus = .connecting

			// Generate PeerData
			// Note that generateUniqueID generates a UInt32 but they always request an Int32, so it's potentially
			// truncated here which might cause issues
			// TODO: Make sure we handle duplicate id's
			setPeerData(
				for: GKLocalPlayer.local,
				data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative())
			)

			let request: GKMatchRequest = GKMatchRequest()
			request.minPlayers = minPlayers
			request.maxPlayers = maxPlayers
			request.playerGroup = playerGroup
			request.playerAttributes = UInt32(playerAttributes)

			do {
				isMatching = true
				match = try await GKMatchmaker.shared().findMatch(for: request)
				match?.delegate = self.delegate
			} catch GKError.cancelled {
				// Handling user cancelled separately here because trying to emit a signal here causes a crash
				return
			} catch {
				GD.pushError("[GameCenterPeer] Unable to find players: \(error)")
				emit(
					signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated,
					MatchmakingStatus.timeout.rawValue
				)
				return
			}

			isMatching = false
			if match != nil {
				GKMatchmaker.shared().finishMatchmaking(for: match!)
			}

			emit(
				signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated,
				MatchmakingStatus.successful.rawValue
			)
		}
	}

	/// Cancel matchmaking
	@Callable
	func stopMatchmaking() {
		isMatching = false
		GKMatchmaker.shared().cancel()
	}

	/// Get current player activity
	///
	/// Finds the number of players, across player groups, who recently requested a match.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant, players: Variant) -> (error: Int, players: Int)
	@Callable
	func getPlayerActivity(onComplete: Callable) {
		Task {
			// For some reason try await GKMatchmaker.shared().queryActivity() does not work, even though the docs say it should
			GKMatchmaker.shared().queryActivity { players, error in
				if error != nil {
					GD.pushError("[GameCenterPeer] Failed to get matchmaking activity. Error \(error!)")

					onComplete.callDeferred(Variant(GameCenterError.unknownError.rawValue), Variant(0))
					return
				}
				onComplete.callDeferred(Variant(OK), Variant(players))
			}
		}
	}

	/// Get the current localPlayerID
	///
	/// - Returns: The local player ID, or 0 if nothing is found
	@Callable
	func getLocalPlayerID() -> Int {
		return Int(getPeerID(for: GKLocalPlayer.local) ?? 0)
	}

	// MARK: MultiplayerPeer implementation

	override func _poll() {
		// We don't need polling since GKMatchDelegate supplies the data
	}

	override func _close() {
		stopMatchmaking()
		disconnect()
	}

	override func _disconnectPeer(pPeer: Int32, pForce: Bool) {
		GD.pushWarning("[GameCenterPeer] GKMatch is unable to disconnect players")
	}

	override func _getPacketScript() -> PackedByteArray {
		guard incomingPackets.count > 0 else {
			return PackedByteArray()
		}

		var currentPacket = incomingPackets.removeFirst()
		if currentPacket.from == hostOriginalID {
			currentPacket.from = HOST_ID
		}

		return PackedByteArray(currentPacket.data)
	}

	override func _putPacketScript(pBuffer: PackedByteArray) -> GodotError {
		if let currentMatch = match {
			do {
				let data = encode(packedByteArray: pBuffer)
				if activeMode == .server {
					if targetPeer == 0 {
						// Send to all players
						try currentMatch.sendData(toAllPlayers: data!, with: getTransferMode())

					} else if targetPeer < 0 {
						// Send to all but one
						var exclude: Int32 = -targetPeer

						var players: [GKPlayer] = []
						for player: GKPlayer in currentMatch.players {
							if getPeerID(for: player) == exclude {
								continue
							}
							players.append(player)
						}

						try currentMatch.send(data!, to: players, dataMode: getTransferMode())

					} else {
						// Send to specific player
						if let player: GKPlayer = getPlayerWithID(peerID: targetPeer) {
							try currentMatch.send(data!, to: [player], dataMode: getTransferMode())
						}
					}
					return GodotError.ok
				} else {
					if let player: GKPlayer = getPlayerWithID(peerID: HOST_ID) {
						try currentMatch.send(data!, to: [player], dataMode: getTransferMode())
					}
					return GodotError.ok
				}

			} catch {
				GD.pushError("[GameCenterPeer] Failed to send data. Error \(error)")
				return GodotError.errConnectionError
			}
		} else {
			GD.pushError("[GameCenterPeer] Tried to send data before match was established.")
			return GodotError.errConnectionError
		}
	}

	override func _setTargetPeer(pPeer: Int32) {
		targetPeer = pPeer
	}

	override func _getAvailablePacketCount() -> Int32 {
		return Int32(incomingPackets.count)
	}

	override func _getPacketPeer() -> Int32 {
		if let packet = incomingPackets.first {
			if packet.from == hostOriginalID {
				return HOST_ID
			}

			return packet.from
		}

		return 0
	}

	override func _getPacketMode() -> MultiplayerPeer.TransferMode {
		if let packet = incomingPackets.first {
			return packet.transferMode
		}

		return .reliable
	}

	override func _getPacketChannel() -> Int32 {
		if let packet = incomingPackets.first {
			return packet.channel - RESERVED_CHANNELS + 1
		}

		return 0
	}

	override func _setTransferChannel(pChannel: Int32) {
		currentTransferChannel = pChannel
	}

	override func _getTransferChannel() -> Int32 {
		// A bug somewhere in the GDExtension implementations complains that this function isn't overridden
		return currentTransferChannel
	}

	override func _setTransferMode(pMode: MultiplayerPeer.TransferMode) {
		currentTransferMode = pMode
	}

	override func _getTransferMode() -> MultiplayerPeer.TransferMode {
		// A bug somewhere in the GDExtension implementations complains that this function isn't overridden
		return currentTransferMode
	}

	override func _setRefuseNewConnections(pEnable: Bool) {
		refuseConnections = pEnable
	}

	override func _isRefusingNewConnections() -> Bool {
		return refuseConnections
	}

	override func _isServer() -> Bool {
		return activeMode == .server
	}

	override func _isServerRelaySupported() -> Bool {
		return activeMode == .server || activeMode == .client
	}

	override func _getConnectionStatus() -> MultiplayerPeer.ConnectionStatus {
		return connectionStatus
	}

	override func _getMaxPacketSize() -> Int32 {
		return Int32.max
	}

	override func _getUniqueId() -> Int32 {
		return uniqueID
	}

	// MARK: Host management

	func decideHost() {
		Task {
			if let currentMatch = match {
				if let player = await currentMatch.chooseBestHostingPlayer() {
					// We got a new host
					self.setHost(player)

				} else if let player = self.getPlayerWithHighestInitiative() {
					// We need to pick a random host
					self.setHost(player)
				}
			}
		}
	}

	func setHost(_ host: GKPlayer) {
		//GD.print("[GameCenterPeer] Making \(host.displayName) the host (ID: \(getPeerID(for: host)) -> \(HOST_ID))")
		hostOriginalID = getPeerID(for: host)
		setPeerID(for: host, id: HOST_ID)

		if host == GKLocalPlayer.local {
			activeMode = .server
		} else {
			activeMode = .client
		}

		finalizeMatch()
	}

	func finalizeMatch() {
		GD.print("[GameCenterPeer] Finalizing match")
		// When the host has been decided we can consider ourselves connected
		// The reason we do this is that we need to pick a player to be HOST_ID before then
		if let localPeerID = getPeerID(for: GKLocalPlayer.local) {
			// Setting the connectionStatus will trigger the connected_to_server event
			connectionStatus = .connected
			uniqueID = localPeerID

			// Because connected_to_server never triggers on servers (uniqueID == HOST_ID),
			// we need to let the host known that the connection is ready
			if uniqueID == HOST_ID {
				emit(signal: GameCenterMultiplayerPeer.serverCreated)
			}
		} else {
			GD.pushError("[GameCenterPeer] Failed to finalize match")
			connectionStatus = .disconnected
			close()

			emit(
				signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated,
				MatchmakingStatus.failed.rawValue
			)
		}

		if let players = match?.players {
			for player in players {
				if let peerID = getPeerID(for: player) {
					emit(signal: SignalWith1Argument("peer_connected", argument1Name: "id"), Int(peerID))
				}
			}
		}
	}

	func removePlayer(_ player: GKPlayer) {
		if let peerID: Int32 = getPeerID(for: player) {
			removePeer(withID: player.gamePlayerID)

			if peerID == HOST_ID && getLocalPlayerID() != peerID {
				GD.print("[GameCenterPeer] Host disconnected")
				disconnect()
			} else {
				GD.print("[GameCenterPeer] Player disconnected")
				emit(signal: SignalWith1Argument("peer_disconnected", argument1Name: "id"), Int(peerID))
			}
		} else {
			GD.pushError("[GameCenterPeer] Tried to remove player but player wasn't mapped")
		}
	}

	func sendPeerData(_ peerData: PeerData, to players: [GKPlayer], with mode: GKMatch.SendDataMode) {
		do {
			let data = encode(peerData: peerData)
			try match?.send(data!, to: players, dataMode: mode)
		} catch {
			GD.pushError("[GameCenterPeer] Failed to send peerData: \(error)")
		}
	}

	func disconnect() {
		// TODO: I suspect some things here happen too fast, but only sometimes
		// The result is that sometimes the disconnect signal is sent immediately
		// and sometimes it will time out after a time.

		// Theory: A disconnect is sent and awaits a return, but if it takes more than a certain time
		// the sender doesn't exist and all clients will wait for timeout
		// Solution: Maybe wait a second after match?.disconnect()

		connectionStatus = .disconnected
		activeMode = .none
		uniqueID = 0

		match?.disconnect()
		match = nil

		incomingPackets.removeAll()
		currentPacket = nil
		clearPeers()

		refuseConnections = false
	}

	func getTransferMode() -> GKMatch.SendDataMode {
		switch _getTransferMode() {
		case .reliable:
			return GKMatch.SendDataMode.reliable
		case .unreliable:
			return GKMatch.SendDataMode.unreliable
		case .unreliableOrdered:
			return GKMatch.SendDataMode.reliable
		}
	}

	// MARK: Matchmaking protocol

	// Connection flow
	// The MultiplayerPeer system has some requirements that we have to work around, so the connection flow looks something like this:
	// connect to player -> send id + initiative roll -> add player locally -> if enough players -> decide host -> connection complete

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
				setPeerData(for: player, data: peerData)

				if match.expectedPlayerCount == 0 {
					decideHost()
				}

			} else if let data: [UInt8] = gameData?.bytes {
				if let fromPeer: Int32 = getPeerID(for: player) {
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
