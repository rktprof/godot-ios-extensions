import GameKit
import SwiftGodot

extension GameCenter {

	enum FriendsError: Int, Error {
		case friendAccessRestricted = 1
		case failedToLoadFriends = 2
		case failedToLoadRecentPlayers = 3
		case noSuchFriend = 4
	}

	/// Load the friends of the authenticated player.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, friends: Variant) -> (error: Int, friends: [``GameCenterPlayer``])
	func loadFriends(onComplete: Callable) {
		Task {
			do {
				var players = GArray()
				self.friends = try await GKLocalPlayer.local.loadFriends()

				for friend in self.friends ?? [] {
					players.append(Variant(GameCenterPlayer(friend)))
				}

				onComplete.callDeferred(Variant(OK), Variant(players))

			} catch {
				GD.pushError("Error loading friends. \(error)")
				onComplete.callDeferred(Variant(FriendsError.failedToLoadFriends.rawValue), Variant())
			}
		}
	}

	/// Loads players from the friends list or players that recently participated in a game with the local player.
	///
	/// - Parameters
	/// 	- onComplete: Callback with parameters: (error: Variant, players: Variant) -> (error: Int, players: [``GameCenterPlayer``])
	func loadRecentPlayers(onComplete: Callable) {
		Task {
			do {
				var players = GArray()
				let recentPlayers = try await GKLocalPlayer.local.loadRecentPlayers()

				for player in recentPlayers {
					players.append(Variant(GameCenterPlayer(player)))
				}

				onComplete.callDeferred(Variant(OK), Variant(players))

			} catch {
				GD.pushError("Error loading recent players. \(error)")
				onComplete.callDeferred(Variant(FriendsError.failedToLoadRecentPlayers.rawValue), Variant())
			}
		}
	}

	/// Load the profile picture of the given gamePlayerID.
	/// > NOTE: Only works on friends
	///
	/// - Parameters
	/// 	- onComplete: Callback with parameters: (error: Variant, data: Variant) -> (error: Int, data: Image)
	func loadFriendPicture(gamePlayerID: String, onComplete: Callable) {
		if friends == nil {
			loadFriends(onComplete: Callable())
		}

		Task {
			do {
				if self.friends == nil {
					try await updateFriends()
				}

				if let friend = self.friends?.first(where: { $0.gamePlayerID == gamePlayerID }) {
					let image = try await friend.loadImage(size: .small)
					onComplete.callDeferred(Variant(OK), Variant(image))
				} else {
					GD.pushError("Found no friend with id: \(gamePlayerID)")
					onComplete.callDeferred(Variant(FriendsError.noSuchFriend.rawValue), Variant())
				}
			} catch {
				GD.pushError("Failed to load friend picture. \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadPicture.rawValue), Variant())
			}
		}
	}

	/// Check for permission to load friends.
	///
	/// Usage:
	/// ```python
	///	game_center.canAccessFriends(func(error: Variant, data: Variant) -> void:
	///		if error == OK:
	///			var friendPhoto:Image = data as Image
	///	)
	///	```
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, status: Variant) -> (error: Int, status: Int)
	/// 	Possible status types:
	/// 		- notDetermined = 0
	/// 		- restricted = 1
	/// 		- denied = 2
	/// 		- authorized = 3
	func canAccessFriends(onComplete: Callable) {
		Task {
			do {
				let status = try await GKLocalPlayer.local.loadFriendsAuthorizationStatus()
				onComplete.callDeferred(Variant(OK), Variant(status.rawValue))
			} catch {
				GD.pushError("Error accessing friends: \(error).")
				onComplete.callDeferred(Variant(FriendsError.friendAccessRestricted.rawValue), Variant())
			}
		}
	}

	// MARK: UI Overlay

	/// Show GameCenter friends overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	func showFriendsOverlay(onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .localPlayerFriendsList), onClose: onClose)
		#endif
	}

	/// Show friend request creator.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay
	func showFriendRequestCreator() {
		#if canImport(UIKit)
		do {
			if let rootController = viewController.getRootController() {
				try GKLocalPlayer.local.presentFriendRequestCreator(from: rootController)
			}
		} catch {
			GD.pushError("Error showing friend request creator: \(error)")
		}
		#endif
	}

	// MARK: Internal

	func updateFriends() async throws {
		if GKLocalPlayer.local.isAuthenticated {
			self.friends = try await GKLocalPlayer.local.loadFriends()
		} else {
			throw GKError(.notAuthenticated)
		}
	}
}
