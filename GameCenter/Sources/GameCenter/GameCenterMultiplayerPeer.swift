import SwiftGodot
import GameKit

let HOST_ID:Int32 = 1

let MATCHMAKING_STATUS_SUCCESSFUL:Int = 0
let MATCHMAKING_STATUS_FAILED:Int = 1
let MATCHMAKING_STATUS_TIMEOUT:Int = 2

let INVITE_STATUS_ACCEPTED:Int = 0
let INVITE_STATUS_DECLINED:Int = 1
let INVITE_STATUS_FAILED:Int = 2
let INVITE_STATUS_INCOMPATIBLE:Int = 3
let INVITE_STATUS_UNABLE_TO_CONNECT:Int = 4
let INVITE_STATUS_TIMEOUT:Int = 5
let INVITE_STATUS_INVALID_INVITE:Int = 6
let INVITE_STATUS_PLAYER_NOT_FOUND:Int = 7

@Godot
class GameCenterMultiplayerPeer:MultiplayerPeerExtension, GameCenterMatchmakingProtocol {
	#signal("server_created")
	#signal("matchmaking_status_updated", arguments: ["status": Int.self])
	#signal("invite_status_updated", arguments: ["status": Int.self, "player": String.self])

	let reservedChannels:Int32 = 2

	enum Mode:Int {
		case None = 0, Server, Client, Mesh
	}

	enum MessageType:Int {
		case PeerConnected = 0
		case PeerUpdated = 1
		case Unknown = 2
	}

	struct Packet {
		var data:[UInt8]
		var from:Int32 = 0
		var channel:Int32 = 0
		var transferMode:MultiplayerPeer.TransferMode = MultiplayerPeer.TransferMode.reliable
	}

	var delegate:MatchDelegate?

	var activeMode:Mode = Mode.None
	var uniqueID:Int32 = 0
	var targetPeer:Int32 = 0

	var connectionStatus:MultiplayerPeer.ConnectionStatus = MultiplayerPeer.ConnectionStatus.disconnected

	var currentTransferMode:MultiplayerPeer.TransferMode = MultiplayerPeer.TransferMode.reliable
	var currentTransferChannel:Int32 = 0
	var refuseConnections:Bool = false

	var peerMap:[String:PeerData] = [:] // Maps gamePlayerID to PeerData

	var incomingPackets:[Packet] =  []
	var currentPacket:Packet?

	var isMatching:Bool = false
	var match:GKMatch?

	required init() {
		super.init()
		connectionStatus = MultiplayerPeer.ConnectionStatus.connecting
		delegate = MatchDelegate(withDelegate: self)
	}

	required init(nativeHandle:UnsafeRawPointer) {
		super.init(nativeHandle: nativeHandle)
		connectionStatus = MultiplayerPeer.ConnectionStatus.connecting
		delegate = MatchDelegate(withDelegate: self)
	}
	
	@Callable
	func invitePlayers(playerIDs:[String]) {
		Task {
			if (isMatching) {
				stopMatchmaking()
			}

			isMatching = true
			connectionStatus = MultiplayerPeer.ConnectionStatus.connecting
			
			// Generate PeerData
			// Note that generateUniqueID generates a UInt32 but they always request an Int32, so it's potentially
			// truncated here which might cause issues
			// TODO: Make sure we handle duplicate id's
			setPeerData(for: GKLocalPlayer.local, data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative()))

			let request: GKMatchRequest = GKMatchRequest()
			let players: [GKPlayer]

			do {
				let players: [GKPlayer] = try await GKLocalPlayer.local.loadFriends(identifiedBy: playerIDs)
				request.recipients = players
				request.recipientResponseHandler = invitationResponseHandler
			} catch {
				GD.pushError("[Matchmaking] Could not find player. Error: \(error)")
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_PLAYER_NOT_FOUND, "")
				return
			}

			do {
				match = try await GKMatchmaker.shared().findMatch(for: request)
				match?.delegate = self.delegate
			} catch {
				GD.pushError("[Matchmaking] Failed to invite player. Error: \(error)")
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_TIMEOUT, "")
				return
			}
		}
	}

	@Callable
	func joinGame(inviteIndex:Int) {
		Task {
			if (isMatching)
			{
				stopMatchmaking()
			}

			connectionStatus = MultiplayerPeer.ConnectionStatus.connecting

			// Generate PeerData
			// Note that generateUniqueID generates a UInt32 but they always request an Int32, so it's potentially
			// truncated here which might cause issues
			// TODO: Make sure we handle duplicate id's
			setPeerData(for: GKLocalPlayer.local, data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative()))

			if let invite: GKInvite = GameCenter.instance?.getInvite(withIndex: inviteIndex) {
				do {
					isMatching = true
					match = try await GKMatchmaker.shared().match(for: invite)
					match?.delegate = self.delegate
					
					GameCenter.instance?.removeInvite(withIndex: inviteIndex)
				} catch {
					GD.pushError("[Matchmaking] Unable to join game: \(error)")
					emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_TIMEOUT, "")

					// NOTE: Removing the invite here will prevent retrying it, which might not be ideal
					GameCenter.instance?.removeInvite(withIndex: inviteIndex)
					return
				}
			} else {
				GD.pushError("[Matchmaking] Unable to join game: No invite at index \(inviteIndex)")
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_INVALID_INVITE, "")
				return
			}
		}
	}

	@Callable
	func findPlayers(minPlayers:Int, maxPlayers:Int, playerGroup:Int, playerAttributes:Int) {
		Task {
			if (isMatching)
			{
				stopMatchmaking()
			}

			connectionStatus = MultiplayerPeer.ConnectionStatus.connecting

			// Generate PeerData
			// Note that generateUniqueID generates a UInt32 but they always request an Int32, so it's potentially
			// truncated here which might cause issues
			// TODO: Make sure we handle duplicate id's
			setPeerData(for: GKLocalPlayer.local, data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative()))
			
			let request: GKMatchRequest = GKMatchRequest()
			request.minPlayers = minPlayers
			request.maxPlayers = maxPlayers
			request.playerGroup = playerGroup
			request.playerAttributes = UInt32(playerAttributes)

			do {
				isMatching = true
				match = try await GKMatchmaker.shared().findMatch(for: request)
				match?.delegate = self.delegate
			} catch {
				GD.pushError("[Matchmaking] Unable to find players: \(error)")
				emit(signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated, MATCHMAKING_STATUS_TIMEOUT)
				return
			}

			if match != nil {
				GKMatchmaker.shared().finishMatchmaking(for: match!)
			}

			isMatching = false
			emit(signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated, MATCHMAKING_STATUS_SUCCESSFUL)
		}
	}

	@Callable
	func getPlayerActivity(onComplete:Callable) {
		Task {
			// For some reason try await GKMatchmaker.shared().queryActivity() does not work, even though the docs say it should
			GKMatchmaker.shared().queryActivity() { players, error in
				if error != nil {
					GD.pushError("[Matchmaking] Failed to get matchmaking activity. Error \(error!)")

					onComplete.callDeferred(Variant(ERROR), Variant(0))
					return
				}
				onComplete.callDeferred(Variant(OK), Variant(players))
			}
		}
	}
	
	@Callable
	func stopMatchmaking() {
		if (isMatching) {
			isMatching = false
			GKMatchmaker.shared().cancel()
		}
	}

	@Callable
	func getLocalPlayerID() -> Int {
		return Int(getPeerID(for: GKLocalPlayer.local) ?? 0)
	}

	// Interface overrides

	override func _poll()
	{
		// We don't need polling since GKMatchDelegate supplies the data
	}

	override func _close()
	{
		GD.print("[Matchmaking] Closing connection...")
		stopMatchmaking()
		match?.disconnect()
		incomingPackets.removeAll()
		currentPacket = nil
		peerMap.removeAll()

		connectionStatus = MultiplayerPeer.ConnectionStatus.disconnected
		activeMode = Mode.None
		uniqueID = 0
		refuseConnections = false
	}

	override func _disconnectPeer(pPeer:Int32, pForce:Bool) {
		GD.pushWarning("[Matchmaking] GKMatch is unable to disconnect players")
	}

	override func _getPacketScript() -> PackedByteArray {
		if incomingPackets.count == 0 {
			return PackedByteArray()
		}

		currentPacket = incomingPackets.removeFirst()
		if let data: [UInt8] = currentPacket?.data {
			return PackedByteArray(data)
		}

		return PackedByteArray()
	}

	override func _putPacketScript(pBuffer: PackedByteArray) -> GodotError {
		if let currentMatch = match {
			do {
				let data = encode(packedByteArray: pBuffer)
				if (activeMode == Mode.Server)
				{
					if (targetPeer == 0) {
						// Send to all players
						try currentMatch.sendData(toAllPlayers: data!, with: getTransferMode())
						
					} else if targetPeer < 0 {
						// Send to all but one
						var exclude:Int32 = -targetPeer

						var players:[GKPlayer] = []
						for player: GKPlayer in currentMatch.players {
							if (getPeerID(for: player) == exclude) {
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
				GD.pushError("[Matchmaking] Failed to send data. Error \(error)")
				return GodotError.errConnectionError
			}
		}
		else
		{
			GD.pushError("[Matchmaking] Tried to send data before match was established.")
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
			return packet.from
		}

		return 0
	}

	override func _getPacketMode() -> MultiplayerPeer.TransferMode {
		if let packet = incomingPackets.first {
			return packet.transferMode
		}

		return MultiplayerPeer.TransferMode.reliable
	}

	override func _getPacketChannel() -> Int32 {
		if let packet = incomingPackets.first {
			return packet.channel - reservedChannels + 1
		}

		return 0
	}

	override func _setTransferChannel(pChannel: Int32) {
		currentTransferChannel = pChannel
	}

	override func _getTransferChannel() -> Int32 {
		return currentTransferChannel
	}

	func _get_transfer_channel() -> Int32 {
		return currentTransferChannel
	}

	override func _setTransferMode(pMode: MultiplayerPeer.TransferMode) {
		currentTransferMode = pMode
	}

	override func _getTransferMode() -> MultiplayerPeer.TransferMode {
		return currentTransferMode
	}

	func _get_transfer_mode() -> MultiplayerPeer.TransferMode {
		return currentTransferMode
	}

	override func _setRefuseNewConnections(pEnable:Bool) {
		refuseConnections = pEnable
	}
	
	override func _isRefusingNewConnections() -> Bool {
		return refuseConnections
	}

	override func _isServer() -> Bool {
		return activeMode == Mode.Server
	}

	override func _isServerRelaySupported() -> Bool {
		return activeMode == Mode.Server || activeMode == Mode.Client
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

	// Internal

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

	func setHost(_ host:GKPlayer) {
		//GD.print("[Matchmaking] Making \(host.displayName) the host (ID: \(getPeerID(for: host)) -> \(HOST_ID))")
		setPeerID(for: host, id: HOST_ID)

		if (host == GKLocalPlayer.local) {
			activeMode = Mode.Server
		} else {
			activeMode = Mode.Client
		}

		finalizeMatch()
	}

	func finalizeMatch() {
		// When the host has been decided we can consider ourselves connected
		// The reason we do this is that we need to pick a player to be HOST_ID before then
		if let localPeerID = getPeerID(for: GKLocalPlayer.local) {
			// Setting the connectionStatus will trigger the connected_to_server event
			connectionStatus = MultiplayerPeer.ConnectionStatus.connected
			uniqueID = localPeerID

			// Because connected_to_server never triggers on servers (uniqueID == HOST_ID),
			// we need to let the host known that the conneciton is ready
			if (uniqueID == HOST_ID) {
				emit(signal: GameCenterMultiplayerPeer.serverCreated)
			}
		} else {
			GD.pushError("[Matchmaking] Failed to finalize match")
			connectionStatus = MultiplayerPeer.ConnectionStatus.disconnected
			close()

			emit(signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated, MATCHMAKING_STATUS_FAILED)
		}

		if let players = match?.players {
			for player in players {
				if let peerID = getPeerID(for: player) {
					emit(signal: SignalWith1Argument("peer_connected", argument1Name: "id"), Int(peerID))
				}
			}
		}
	}

	func removePlayer(_ player:GKPlayer) {
		if let peerID: Int32 = getPeerID(for: player) {
			peerMap.removeValue(forKey: player.gamePlayerID)
			emit(signal: SignalWith1Argument("peer_disconnected", argument1Name: "id"), Int(peerID))
		} else {
			GD.pushError("[Matchmaking] Tried to remove player but player wasn't mapped")
		}
	}

	func sendPeerData(_ peerData:PeerData, to players:[GKPlayer], with mode:GKMatch.SendDataMode) {
		do {
			let data = encode(peerData: peerData)
			try match?.send(data!, to: players, dataMode: mode)
		} catch {
			GD.pushError("[Matchmaking] Failed to send peerData: \(error)")
		}
	}

	func getTransferMode() -> GKMatch.SendDataMode {
		switch _getTransferMode() {
			case MultiplayerPeer.TransferMode.reliable:
				return GKMatch.SendDataMode.reliable
			case MultiplayerPeer.TransferMode.unreliable:
				return GKMatch.SendDataMode.unreliable
			case MultiplayerPeer.TransferMode.unreliableOrdered:
				return GKMatch.SendDataMode.reliable
		}
	}

	// Listener callbacks

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
					GD.pushError("[Matchmaking] Found no local peerData to send")
				}
				
			case .disconnected:
				removePlayer(player)

			default:
				GD.pushWarning("[Matchmaking] \(player.displayName) Connection Unknown \(state)")
		}
	}

	func match(_ match:GKMatch, didFailWithError error: Error?) {
		if error != nil {
			GD.pushError("[Matchmaking] Match failed with error: \(error)")
		} else {
			GD.pushError("[Matchmaking] Match failed with unknown error")
		}

		emit(signal: GameCenterMultiplayerPeer.matchmakingStatusUpdated, MATCHMAKING_STATUS_FAILED)
	}

	func match(_ match: GKMatch, shoudlReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
		return false
	}

	func match(_ match: GKMatch, didReceive data:Data, fromRemotePlayer player: GKPlayer) {
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
					let packet:Packet = Packet(data: data, from: fromPeer, channel: 0)
					incomingPackets.append(packet)
				}
			} else {
				GD.pushWarning("[Matchmaking] Got unhandled data packet")
			}
		} catch {
			GD.pushError("[Matchmaking] Error when reciving data \(error)")
		}
	}

	func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer) {
		if recipient == GKLocalPlayer.local {
			self.match(match, didReceive: data, fromRemotePlayer: player)
		} else {
			// TODO: Handle this case, are we a relay?
		}
	}

	func invitationResponseHandler(player:GKPlayer, response:GKInviteRecipientResponse) {
		switch response {
			case .accepted:
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_ACCEPTED, player.displayName)
			case .declined:
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_DECLINED, player.displayName)
			case .failed:
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_FAILED, player.displayName)
			case .incompatible:
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_INCOMPATIBLE, player.displayName)
			case .unableToConnect:
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_UNABLE_TO_CONNECT, player.displayName)
			case .noAnswer:
				emit(signal: GameCenterMultiplayerPeer.inviteStatusUpdated, INVITE_STATUS_TIMEOUT, player.displayName)
		}

		if match != nil {
			GKMatchmaker.shared().finishMatchmaking(for: match!)
		}

		self.isMatching = false
	}

	// This class is just an intermediate because a @Godot class doesn't inherit from NSObject
	// which is required for GKMatchDelegate and GKLocalPlayerListener
	// TODO: Move GKLocalPlayerListener elsewhere
	class MatchDelegate:NSObject, GKMatchDelegate {
		var delegate:GameCenterMatchmakingProtocol

		required init(withDelegate delegate:GameCenterMatchmakingProtocol) {	
			self.delegate = delegate
			super.init()
		}

		func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
			delegate.match(match, player: player, didChange: state)
		}

		func match(_ match:GKMatch, didFailWithError error: Error?) {
			delegate.match(match, didFailWithError: error)
		}

		func match(_ match: GKMatch, shoudlReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
			return delegate.match(match, shoudlReinviteDisconnectedPlayer: player)
		}

		func match(_ match: GKMatch, didReceive data:Data, fromRemotePlayer player: GKPlayer) {
			delegate.match(match, didReceive: data, fromRemotePlayer: player)
		}

		func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer) {
			delegate.match(match, didReceive: data, forRecipient: recipient, fromRemotePlayer: player)
		}
	}
}
