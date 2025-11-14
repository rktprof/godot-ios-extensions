import GameKit
import SwiftGodotRuntime

/// Holds invite data in a Godot friendly format
@Godot
class GameCenterInvite: RefCounted {
	@Export var sender: GameCenterPlayer?

	@Export var playerAttributes: Int = 0
	@Export var playerGroup: Int = 0
	@Export var isHosted: Bool = false
	
	@Export var index:Int = 0

	convenience init(_ invite: GKInvite, index:Int) {
		self.init()

		self.sender = GameCenterPlayer(invite.sender)
		self.playerAttributes = Int(invite.playerAttributes)  // Not ideal, but godot doesn't support UInt32
		self.playerGroup = invite.playerGroup
		self.isHosted = invite.isHosted
		self.index = index
	}
}
