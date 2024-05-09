import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

@Godot
class GameCenterFriends:Object
{
	enum AuthorizationStatus : Int
	{
		case NOT_DETERMINED = 0
		case AUTHORIZED = 1
		case DENIED = 2
		case RESTRICTED = 3
	}

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

				params.append(value: Variant(true))
				params.append(value: Variant(players))
				onComplete.callv(arguments: params)

			} catch {
				var error:String = error.localizedDescription
				GD.pushError("Error getting friends: \(error).")
				params.append(value:Variant(false))
				params.append(value:Variant(error))
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
				params.append(value:Variant(true))
				switch status
				{
					case .notDetermined:
						params.append(value:Variant(true))
					case .authorized:
						params.append(value:Variant(true))
					case .denied:
						params.append(value:Variant(false))
					case .restricted:
						params.append(value:Variant(false))
					@unknown default:
						params.append(value:Variant(false))
				}

				onComplete.callv(arguments: params)
			}
		}
		catch
		{
			var error:String = error.localizedDescription
			GD.pushError("Error accessing friends: \(error).")

			params.append(value:Variant(false))
			params.append(value:Variant(error))
			onComplete.callv(arguments: params)
		}
	}

	@Callable
	func showFriendsOverlay(onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .localPlayerFriendsList), onClose: onClose)
		//viewController.showFriends(onClose: onClose)
		#endif
	}
}