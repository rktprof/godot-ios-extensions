import SwiftGodot

@Godot
class GameCenterLeaderboardPlayer:RefCounted
{
	@Export var displayName:String = ""
	@Export var score:Int = 0
	@Export var image:Image?
}