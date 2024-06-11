import GameKit

protocol GameCenterMatchmakingProtocol {
	func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState)
	func match(_ match: GKMatch, didFailWithError error: Error?)
	func match(_ match: GKMatch, shoudlReinviteDisconnectedPlayer player: GKPlayer) -> Bool
	func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer)
	func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer)
}
