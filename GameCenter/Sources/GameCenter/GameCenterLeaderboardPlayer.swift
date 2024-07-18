import SwiftGodot
import GameKit

@Godot
class GameCenterLeaderboardEntry:RefCounted {
	@Export var rank:Int = 0
	@Export var displayName:String = ""

	@Export var score:Int = 0
	@Export var formattedScore:String = ""

	@Export var date:Double = 0.0

	@Export var image:Image?

	init(_ entry:GKLeaderboard.Entry, image:Image? = nil) {
		self.rank = entry.rank
		self.displayName = entry.player.displayName
		self.score = entry.score
		self.formattedScore = entry.formattedScore
		// TODO: Figure out how to best send dates to godot
		//self.date = entry.date
		self.image = image

		super.init()
	}

	required init() {
		super.init()
	}
	
	required init(nativeHandle: UnsafeRawPointer) {	
	 	super.init(nativeHandle: nativeHandle)
	} 
}