import SwiftGodot

@Godot
class GameCenterAchievement:RefCounted
{
	@Export var identifier:String = ""
	@Export var title:String = ""
	@Export var unachievedDescription:String = ""
	@Export var achievedDescription:String = ""
	
	@Export var maximumPoints:Int = 0
	
	@Export var isHidden:Bool = false
	@Export var isReplayable:Bool = false

	@Export var percentComplete:Double = 0
	@Export var isCompleted:Bool = false

	@Export var rarityPercent:Double?
	@Export var image:Image?
}