import SwiftGodot

@Godot
class GameCenterLeaderboardPlayer:RefCounted
{
	@Export var rank:Int = 0
	@Export var displayName:String = ""

	@Export var score:Int = 0
	@Export var formattedScore:String = ""

	@Export var date:Double = 0.0

	@Export var image:Image?
}