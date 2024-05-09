// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

#initSwiftExtension(cdecl: "gamecenter_init", types: [
	GameCenter.self,
	GameCenterFriends.self,
	GameCenterLeaderboards.self,
	GameCenterPlayer.self,
	GameCenterFriend.self,
])

@Godot
class GameCenter:Object
{
	#if os(iOS)
	var viewController:UIGameCenterViewController = UIGameCenterViewController()
	#endif
	
	var localPlayer:GameCenterPlayer?// = GameCenterPlayer()
	var localPlayerListener:GameCenterListener = GameCenterListener()

	// Called when user initializes this class
	required init()
	{
		super.init()
	}

	// Called when godot initializes this class
	required init(nativeHandle:UnsafeRawPointer)
	{
		super.init(nativeHandle: nativeHandle)
	}

	@Callable
	func authenticate(onComplete:Callable = Callable())
	{
		var params:GArray = GArray()

		#if os(iOS)
		if (GKLocalPlayer.local.isAuthenticated)
		{
			params.append(value: Variant(true))
			params.append(value: Variant(localPlayer ?? GameCenterPlayer()))
			onComplete.callv(arguments: params)
			return
		}

		GKLocalPlayer.local.authenticateHandler = { viewController, error in
			if (viewController != nil)
			{
				// Present the view controller so the player can log in
				// TODO: Figure out how to get rootViewController
				//self.view.window.rootViewController.presentViewController(viewController, animated:true, completion:nil)
				return
			}

			if (error != nil)
			{
				var error:String = error?.localizedDescription ?? ""
				GD.pushWarning(error)
				
				var params:GArray = GArray()
				params.append(value: Variant(false))
				params.append(value: Variant(error))
				onComplete.callv(arguments: params)
				return
			}

			// Player was successfully authenticated.
			var player = GameCenterPlayer()
			player.alias = GKLocalPlayer.local.alias
			player.displayName = GKLocalPlayer.local.displayName
			player.gamePlayerID = GKLocalPlayer.local.gamePlayerID
			player.teamPlayerID = GKLocalPlayer.local.teamPlayerID
			
			// Check if there are any player restrictions
			player.isUnderage = GKLocalPlayer.local.isUnderage
			player.isMultiplayerGamingRestricted = GKLocalPlayer.local.isMultiplayerGamingRestricted
			player.isPersonalizedCommunicationRestricted = GKLocalPlayer.local.isPersonalizedCommunicationRestricted
			
			self.localPlayer = player

			params.append(value: Variant(true))
			params.append(value: Variant(player))
			onComplete.callv(arguments: params)

			return
		}

		#else
		GD.pushWarning("GameCenter not available on this platform")

		params.append(value: Variant(false))
		params.append(value: Variant("GameCenter not available on this platform"))
		onComplete.callv(arguments: params)
		#endif
	}

	@Callable
	func isAuthenticated() -> Bool
	{
		#if os(iOS)
		return GKLocalPlayer.local.isAuthenticated
		#else
		return false
		#endif
	}

	@Callable
	func getPlayer() -> GameCenterPlayer?
	{
		return localPlayer
	}

	@Callable
	func showOverlay(onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .dashboard), onClose: onClose)
		//viewController.showDashboard(onClose: onClose)
		#endif
	}
}
