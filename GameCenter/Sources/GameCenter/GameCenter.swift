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
	GameCenterLeaderboardEntry.self,
	GameCenterAchievements.self,
	GameCenterPlayer.self,
	GameCenterFriend.self,
	GameCenterAchievement.self,
	GameCenterMultiplayerPeer.self,
])

let OK:Int = 0
let ERROR:Int = 1
let NOT_AUTHENTICATED:Int = 2
let ERROR_NOT_AVAILABLE: Int = 3
let ERROR_FAILED_TO_AUTHENTICATE:Int = 4
let ERROR_FAILED_TO_SUBMIT_SCORE:Int = 5
let ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES:Int = 6
let ERROR_ACCESSING_FRIENDS:Int = 7

@Godot
class GameCenter:RefCounted
{
	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif
	
	@Callable
	func authenticate(onComplete:Callable = Callable())
	{
		var params:GArray = GArray()

		#if os(iOS)
		if (GKLocalPlayer.local.isAuthenticated)
		{
			params.append(value: Variant(OK))
			params.append(value: Variant(getGameCenterPlayer(localPlayer: GKLocalPlayer.local)))
			onComplete.callv(arguments: params)
		}

		GKLocalPlayer.local.authenticateHandler = { loginController, error in
			if let loginController = loginController
			{
				do
				{
					#if os(iOS)
					// Present the view controller so the player can log in
					try self.viewController.getRootController()?.present(loginController, animated: true, completion: nil)
					#endif
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

			params.append(value: Variant(OK))
			params.append(value: Variant(self.getGameCenterPlayer(localPlayer: GKLocalPlayer.local)))
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
	func getLocalPlayer(onComplete:Callable)
	{
		var params:GArray = GArray()
		if (GKLocalPlayer.local.isAuthenticated)
		{
			params.append(value: Variant(OK))
			params.append(value: Variant(getGameCenterPlayer(localPlayer: GKLocalPlayer.local)))
		}
		else
		{
			params.append(value: Variant(NOT_AUTHENTICATED))
		}
		
		onComplete.callv(arguments: params)
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

	// Internal

	func getGameCenterPlayer(localPlayer:GKLocalPlayer) -> GameCenterPlayer
	{
		// Player was successfully authenticated.
		var player: GameCenterPlayer = GameCenterPlayer()
		player.alias = localPlayer.alias
		player.displayName = localPlayer.displayName
		player.gamePlayerID = localPlayer.gamePlayerID
		player.teamPlayerID = localPlayer.teamPlayerID
			
		// Check if there are any player restrictions
		player.isUnderage = localPlayer.isUnderage
		player.isMultiplayerGamingRestricted = localPlayer.isMultiplayerGamingRestricted
		player.isPersonalizedCommunicationRestricted = localPlayer.isPersonalizedCommunicationRestricted

		return player
	}
}