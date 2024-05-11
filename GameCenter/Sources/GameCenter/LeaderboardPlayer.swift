import SwiftGodot

@Godot
class LeaderboardPlayer:RefCounted
{
	@Export var displayName:String = ""
	@Export var score:Int = 0
	@Export var image:Image?
}