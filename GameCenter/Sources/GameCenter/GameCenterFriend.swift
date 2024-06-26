import SwiftGodot

@Godot
class GameCenterFriend:RefCounted
{
	@Export
	var alias:String = ""
	@Export
	var displayName:String = ""
	
	@Export
	var gamePlayerID:String = ""
	@Export
	var teamPlayerID:String = ""
	
	@Export
	var isInvitable:Bool = false
}
