import SwiftGodot

@Godot
class GameCenterPlayer:RefCounted
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
	var isUnderage:Bool = false
	@Export
	var isMultiplayerGamingRestricted:Bool = false
	@Export
	var isPersonalizedCommunicationRestricted:Bool = false
}
