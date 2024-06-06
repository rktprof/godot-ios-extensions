import SwiftGodot
import GameKit

@Godot
class GameCenterMultiplayerPeer:MultiplayerPeerExtension, GameCenterMatchmakingProtocol {

	#signal("server_created")

	let HOST_ID:Int32 = 1
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
			if (isMatching) { return }

			connectionStatus = MultiplayerPeer.ConnectionStatus.connecting
			
			// Generate PeerData 
			setPeerData(for: GKLocalPlayer.local, data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative()))
			GD.print("[MMPeer] Create peer with id: \(getPeerID(for: GKLocalPlayer.local))")

			let request: GKMatchRequest = GKMatchRequest()
			let players: [GKPlayer]

			do {
				let players: [GKPlayer] = try await GKLocalPlayer.local.loadFriends(identifiedBy: playerIDs)
				request.recipients = players
			} catch {
				GD.pushError("[MMPeer] Could not find player. Error: \(error)")
				return
			}

			do {
				isMatching = true
				match = try await GKMatchmaker.shared().findMatch(for: request)
				match?.delegate = self.delegate
			} catch {
				GD.pushError("[MMPeer] Failed to invite player. Error: \(error)")
				return
			}

			isMatching = false
		}
	}

	@Callable
	func findPlayers(minPlayers:Int, maxPlayers:Int) {
		Task {
			if (isMatching) { return }
			connectionStatus = MultiplayerPeer.ConnectionStatus.connecting

			// Generate PeerData
			// Note that generateUniqueID generates a UInt32 but they always request an Int32, so it's potentially
			// truncated here which might cause issues
			// TODO: Make sure we handle duplicate id's
			setPeerData(for: GKLocalPlayer.local, data: PeerData(id: Int32(generateUniqueId()), initiative: generateInitiative()))
			GD.print("[MMPeer] Create peer with id: \(getPeerID(for: GKLocalPlayer.local))")

			let request: GKMatchRequest = GKMatchRequest()
			request.minPlayers = minPlayers
			request.maxPlayers = maxPlayers

			do {
				GD.print("[MMPeer] Matchmaking...")
				isMatching = true
				match = try await GKMatchmaker.shared().findMatch(for: request)
				match?.delegate = self.delegate
			} catch {
				GD.pushError("[MMPeer] Unable to find players: \(error)")
				return
			}

			if match != nil {
				GKMatchmaker.shared().finishMatchmaking(for: match!)
			}
			isMatching = false
		}
	}

	// TODO: Investigate this
	// @Callable
	// func findNearbyPlayers() {
	// 	Task {
	// 		do {
	// 			match = try await GKMatchmaker.shared().startBrowsingForNearbyPlayers()
	// 			match?.delegate = self.delegate
	// 		}
	// 	}
	// }

	@Callable
	func getPlayerActivity(onComplete:Callable) {
		Task {
			// For some reason try await GKMatchmaker.shared().queryActivity() does not work, even though the docs say it should
			GKMatchmaker.shared().queryActivity() { players, error in
				if error != nil {
					GD.pushError("Failed to get matchmaking activity. Error \(error!)")

					var params:GArray = GArray()
					params.append(Variant(1))
					params.append(Variant(0))
					onComplete.callv(arguments: params)

					return
				}
			
				var params:GArray = GArray()
				params.append(Variant(0))
				params.append(Variant(players))
				onComplete.callv(arguments: params)
			}
		}
	}
	
	@Callable
	func stopMatchmaking() {
		if (isMatching) {
			GD.print("[MMPeer] Cancelling matchmaking")
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
		GD.print("[MMPeer] Closing connection")
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
		GD.print("[MMPeer] GKMatch is unable to disconnect players")
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
				GD.pushError("Failed to send data. Error \(error)")
				return GodotError.errConnectionError
			}
		}
		else
		{
			GD.pushError("Tried to send data before match was established.")
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
				GD.print("[MMPeer] Deciding host...")
				// NOTE: Choosing best host might not be deterministic, so all players might not pick the same best host
				if let player = await currentMatch.chooseBestHostingPlayer() {
					// We got a new host
					GD.print("[MMPeer] HostMigration found a new host: \(player.displayName)")
					self.setHost(player)

				} else if let player = self.getPlayerWithHighestInitiative() {
					// We need to pick a random host
					GD.print("[MMPeer] HostMigration couldn't find an ideal host, picking based on initiative...")
					self.setHost(player)
				}
			}
		}
	}

	func setHost(_ host:GKPlayer) {
		GD.print("[MMPeer] Making \(host.displayName) the host (ID: \(getPeerID(for: host)) -> \(HOST_ID))")
		setPeerID(for: host, id: HOST_ID)

		if (host == GKLocalPlayer.local) {
			activeMode = Mode.Server
		} else {
			activeMode = Mode.Client
		}

		finalizeMatch()
	}

	func finalizeMatch() {
		GD.print("[MMPeer] Finalizing match...")

		// When the host has been decided we can consider ourselves connected
		// The reason we do this is that we need to pick a player to be HOST_ID before then
		if let localPeerID = getPeerID(for: GKLocalPlayer.local) {
			GD.print("[MMPeer] Successfully established local peer \(localPeerID)")
			// Setting the connectionStatus will trigger the connected_to_server event
			connectionStatus = MultiplayerPeer.ConnectionStatus.connected
			uniqueID = localPeerID

			// Because connected_to_server never triggers on servers (uniqueID == HOST_ID),
			// we need to let the host known that the conenciton is ready
			if (uniqueID == HOST_ID) {
				emit(signal: GameCenterMultiplayerPeer.serverCreated)
			}
		} else {
			GD.pushError("[MMPeer] Failed to finalize match")
			connectionStatus = MultiplayerPeer.ConnectionStatus.disconnected
			close()
		}

		if let players = match?.players {
			for player in players {
				if let peerID = getPeerID(for: player) {
					GD.print("[MMPeer] Successfully connected peer \(peerID)")
					emit(signal: SignalWith1Argument("peer_connected", argument1Name: "id"), Int(peerID))
				}
			}
		}
	}

	func removePlayer(_ player:GKPlayer) {
		if let peerID: Int32 = getPeerID(for: player) {
			peerMap.removeValue(forKey: player.gamePlayerID)

			GD.print("[MMPeer] Removed player: \(player.displayName) (\(peerID))")
			emit(signal: SignalWith1Argument("peer_disconnected", argument1Name: "id"), Int(peerID))
		} else {
			GD.print("[MMPeer] Tried to remove player but player wasn't mapped")
		}
	}

	func sendPeerData(_ peerData:PeerData, to players:[GKPlayer], with mode:GKMatch.SendDataMode) {
		do {
			let data = encode(peerData: peerData)
			try match?.send(data!, to: players, dataMode: mode)
		} catch {
			GD.pushError("Failed to end peerData: \(error)")
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
				GD.print("[MMPeer] \(player.displayName) Connected")
				// Send my peer data to player
				if let localPeerData: PeerData = getPeerData(for: GKLocalPlayer.local) {
					sendPeerData(localPeerData, to: [player], with: .reliable)
				} else {
					GD.pushError("[MMPeer] Found no local peerData to send")
				}
				
			case .disconnected:
				GD.print("[MMPeer] \(player.displayName) Disconnected")
				removePlayer(player)

			default:
				GD.print("[MMPeer] \(player.displayName) Connection Unknown \(state)")
		}
	}

	func match(_ match:GKMatch, didFailWithError error: Error?) {
		if error != nil {
			GD.pushError("[MMPeer] Match failed with error: \(error)")
		} else {
			GD.pushError("[MMPeer] Match failed with unknown error")
		}
	}

	func match(_ match: GKMatch, shoudlReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
		return false
	}

	func match(_ match: GKMatch, didReceive data:Data, fromRemotePlayer player: GKPlayer) {
		do {
			let gameData = decode(dataPacket: data)

			if let peerData: PeerData = gameData?.peerData {
				GD.print("[MMPeer] Got PeerData from \(player.displayName) (ID: \(peerData.id))")
				// Player sent peerData
				setPeerData(for: player, data: peerData)

				if match.expectedPlayerCount == 0 {
					decideHost()
				}

			} else if let data: [UInt8] = gameData?.bytes {
				//GD.print("[MMPeer] Got data from \(player.displayName) (ID: \(getPeerID(for: player)))")
				if let fromPeer: Int32 = getPeerID(for: player) {
					let packet:Packet = Packet(data: data, from: fromPeer, channel: 0)
					incomingPackets.append(packet)
				}
			} else {
				GD.print("[MMPeer] Got unknown data")
			}
		} catch {
			GD.pushError("Error when reciving data \(error)")
		}
	}

	func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer) {
		if recipient == GKLocalPlayer.local {
			self.match(match, didReceive: data, fromRemotePlayer: player)
		} else {
			GD.print("Received data for another player, am I a server?")
		}
	}

	func player(_ player:GKPlayer, didAccept invite: GKInvite) {
		GD.print("Recieved invite!")
	}

	func player(_ player:GKPlayer, didRequestMatchWithRecipients recipientPlayers:[GKPlayer]) {
		GD.print("Sending invite")
	}

	// This class is just an intermediate because a @Godot class doesn't inherit from NSObject
	// which is required for GKMatchDelegate and GKLocalPlayerListener
	// TODO: Move GKLocalPlayerListener elsewhere
	class MatchDelegate:NSObject, GKMatchDelegate, GKLocalPlayerListener {
		var delegate:GameCenterMatchmakingProtocol

		required init(withDelegate delegate:GameCenterMatchmakingProtocol) {	
			self.delegate = delegate
			super.init()
			GKLocalPlayer.local.register(self)
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

		func player(_ player:GKPlayer, didAccept invite: GKInvite) {
			delegate.player(player, didAccept: invite)
		}

		func player(_ player:GKPlayer, didRequestMatchWithRecipients recipientPlayers:[GKPlayer]) {
			delegate.player(player, didRequestMatchWithRecipients: recipientPlayers)
		}
	}
}
