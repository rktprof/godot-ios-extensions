// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

#initSwiftExtension(cdecl: "game_center_init", types: [
	GameCenter.self,
	GameCenterFriends.self,
	GameCenterLeaderboards.self,
	GameCenterAchievements.self,
	GameCenterPlayer.self,
	GameCenterFriend.self,
	GameCenterLeaderboardPlayer.self,
	GameCenterAchievement.self,
])

let OK:Int = 0
let ERROR:Int = 1
let ERROR_NOT_AVAILABLE: Int = 2
let ERROR_FAILED_TO_AUTHENTICATE:Int = 3
let ERROR_FAILED_TO_SUBMIT_SCORE:Int = 4
let ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES:Int = 5
let ERROR_ACCESSING_FRIENDS:Int = 6

@Godot
class GameCenter:RefCounted
{
	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif
	
	var localPlayer:GameCenterPlayer? = nil

	@Callable
	func authenticate(onComplete:Callable = Callable())
	{
		var params:GArray = GArray()

		#if os(iOS)
		if (GKLocalPlayer.local.isAuthenticated && localPlayer != nil)
		{
			params.append(value: Variant(OK))
			params.append(value: Variant(localPlayer!))
			onComplete.callv(arguments: params)
		}

		GKLocalPlayer.local.authenticateHandler = { loginController, error in
			if let loginController = loginController
			{
				do
				{
					// Present the view controller so the player can log in
					try self.viewController.getRootController()?.present(loginController, animated: true, completion: nil)
				}
				catch
				{
					GD.pushError("Failed to present login window \(error)")
				}

				return
			}

			if (error != nil)
			{
				GD.pushError(error)
				
				params.append(value: Variant(ERROR_FAILED_TO_AUTHENTICATE))
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

			params.append(value: Variant(OK))
			params.append(value: Variant(player))
			onComplete.callv(arguments: params)

			return
		}

		#else
		GD.pushWarning("GameCenter not available on this platform")

		params.append(value: Variant(ERROR_NOT_AVAILABLE))
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
	func showOverlay(onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .dashboard), onClose: onClose)
		#endif
	}

	@Callable
	func showAccessPoint(showHighlights:Bool)
	{
		#if os(iOS)
		GKAccessPoint.shared.location = .topTrailing
		GKAccessPoint.shared.showHighlights = showHighlights
		GKAccessPoint.shared.isActive = true
		#endif
	}

	@Callable
	func hideAccessPoint()
	{
		#if os(iOS)
		GKAccessPoint.shared.isActive = false
		#endif
	}
}

\ No newline at end of file
