import GameKit
import SwiftGodot

/// Holds player data in a Godot friendly format
@Godot
class GameCenterPlayer: RefCounted {
	@Export var alias: String = ""
	@Export var displayName: String = ""

	@Export var gamePlayerID: String = ""
	@Export var teamPlayerID: String = ""

	@Export var isInvitable: Bool = false

	convenience init(_ player: GKPlayer) {
		self.init()

		alias = player.alias
		displayName = player.displayName
		gamePlayerID = player.gamePlayerID
		teamPlayerID = player.teamPlayerID
		isInvitable = player.isInvitable
	}
}
