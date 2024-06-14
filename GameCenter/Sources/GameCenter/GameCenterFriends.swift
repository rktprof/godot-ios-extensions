import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

@Godot
class GameCenterFriends:RefCounted
{
	let AUTHORIZATION_NOT_DETERMINED:Int = 0
	let AUTHORIZATION_AUTHORIZED:Int = 1
	let AUTHORIZATION_DENIED:Int = 2
	let AUTHORIZATION_RESTRICTED:Int = 3

	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif

	@Callable
	func getFriends(onComplete:Callable)
	{
		Task
		{
			do {
				var players:GArray = GArray()
				let friends: [GKPlayer] = try await GKLocalPlayer.local.loadFriends()
				for friend:GKPlayer in friends
				{
					var player:GameCenterFriend = GameCenterFriend()
					player.displayName = friend.displayName
					player.alias = friend.alias
					player.gamePlayerID = friend.gamePlayerID
					player.teamPlayerID = friend.teamPlayerID
					player.isInvitable = friend.isInvitable

					players.append(Variant(player))
				}

				onComplete.callDeferred(Variant(OK), Variant(players))
			} catch {
				GD.pushError("Error getting friends: \(error).")
				onComplete.callDeferred(Variant(ERROR_ACCESSING_FRIENDS), Variant())
			}
		}
	}

	@Callable
	func showFriendRequestCreator(onClose:Callable)
	{
		#if os(iOS)
		do
		{
			//var rootController 
			//try GKLocalPlayer.local.presentFriendRequestCreator(from: viewController.getRootController())
		}
		catch
		{
			GD.pushError("Error: \(error.localizedDescription).")
		}
		#endif
	}

	@Callable
	func canAccessFriends(onComplete:Callable)
	{
		do
		{
			GKLocalPlayer.local.loadFriendsAuthorizationStatus() { status, error in
				var authorizationStatus = self.AUTHORIZATION_NOT_DETERMINED
				switch status
				{
				case .notDetermined:
					authorizationStatus = self.AUTHORIZATION_NOT_DETERMINED
				case .authorized:
					authorizationStatus = self.AUTHORIZATION_AUTHORIZED
				case .denied:
					authorizationStatus = self.AUTHORIZATION_DENIED
				case .restricted:
					authorizationStatus = self.AUTHORIZATION_RESTRICTED
				}
				onComplete.callDeferred(Variant(OK), Variant(authorizationStatus))
			}
		}
		catch
		{
			GD.pushError("Error accessing friends: \(error).")
			onComplete.callDeferred(Variant(ERROR_ACCESSING_FRIENDS), Variant())
		}
	}

	@Callable
	func showFriendsOverlay(onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .localPlayerFriendsList), onClose: onClose)
		#endif
	}
}