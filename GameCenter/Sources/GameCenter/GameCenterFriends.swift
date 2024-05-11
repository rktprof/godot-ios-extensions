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
	var viewController:UIGameCenterViewController = UIGameCenterViewController()
	#endif

	@Callable
	func getFriends(onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
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

					players.append(value: Variant(player))
				}

				params.append(value: Variant(OK))
				params.append(value: Variant(players))
				onComplete.callv(arguments: params)

			} catch {
				GD.pushError("Error getting friends: \(error).")
				params.append(value:Variant(ERROR_ACCESSING_FRIENDS))
				onComplete.callv(arguments: params)
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
		var params:GArray = GArray()
		do
		{
			GKLocalPlayer.local.loadFriendsAuthorizationStatus() 
			{ (status: GKFriendsAuthorizationStatus, error: (any Error)?) in
				params.append(value:Variant(OK))
				switch status
				{
					case .notDetermined:
						params.append(value:Variant(self.AUTHORIZATION_NOT_DETERMINED))
					case .authorized:
						params.append(value:Variant(self.AUTHORIZATION_AUTHORIZED))
					case .denied:
						params.append(value:Variant(self.AUTHORIZATION_DENIED))
					case .restricted:
						params.append(value:Variant(self.AUTHORIZATION_RESTRICTED))
				}

				onComplete.callv(arguments: params)
			}
		}
		catch
		{
			GD.pushError("Error accessing friends: \(error).")

			params.append(value:Variant(ERROR_ACCESSING_FRIENDS))
			onComplete.callv(arguments: params)
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