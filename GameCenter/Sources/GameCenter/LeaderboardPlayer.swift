import SwiftGodot

@Godot
class LeaderboardPlayer:Object
{
	@Export var displayName:String = ""
	@Export var score:Int = 0
	@Export var image:Image?
}