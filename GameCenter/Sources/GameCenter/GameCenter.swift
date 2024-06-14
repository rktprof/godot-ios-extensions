// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

#initSwiftExtension(cdecl: "swift_entry_point", types: [
	GameCenter.self,
	GameCenterPlayer.self,
	GameCenterFriends.self,
	GameCenterFriend.self,
	GameCenterLeaderboards.self,
	GameCenterLeaderboardEntry.self,
	GameCenterAchievements.self,
	GameCenterAchievement.self,
	GameCenterMultiplayerPeer.self,
])

let OK:Int = 0
let ERROR:Int = 1
let NOT_AUTHENTICATED:Int = 2
let ERROR_NOT_AVAILABLE: Int = 3
let ERROR_FAILED_TO_AUTHENTICATE:Int = 4

let ERROR_ACCESSING_FRIENDS:Int = 6

let ERROR_FAILED_TO_SUBMIT_SCORE:Int = 7
let ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES:Int = 8

let FAILED_TO_LOAD_ACHIEVEMENTS:Int = 9
let FAILED_TO_RESET_ACHIEVEMENTS:Int = 10
let FAILED_TO_SET_PROGRESS:Int = 11
let FAILED_TO_LOAD_PROGRESS:Int = 12
let FAILED_TO_REPORT_PROGRESS:Int = 13
let NOTHING_TO_REPORT:Int = 14

@Godot
class GameCenter:RefCounted
{
	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif
	
	@Callable
	func authenticate(onComplete:Callable = Callable())
	{
		#if os(iOS)
		if (GKLocalPlayer.local.isAuthenticated)
		{
			onComplete.call(Variant(OK), Variant(getGameCenterPlayer(localPlayer: GKLocalPlayer.local)))
			return
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
				onComplete.callDeferred(Variant(ERROR_FAILED_TO_AUTHENTICATE), Variant())
				return
			}

			if (self.delegate != nil) {
				GKLocalPlayer.local.register(self.delegate!)
			}

			onComplete.callDeferred(Variant(OK), Variant(self.getGameCenterPlayer(localPlayer: GKLocalPlayer.local)))
		}

		#else
		GD.pushWarning("GameCenter not available on this platform")

		onComplete.call(Variant(ERROR_NOT_AVAILABLE))
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
		if (GKLocalPlayer.local.isAuthenticated)
		{
			onComplete.call(Variant(OK), Variant(getGameCenterPlayer(localPlayer: GKLocalPlayer.local)))
		}
		else
		{
			onComplete.call(Variant(NOT_AUTHENTICATED))
		}
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
