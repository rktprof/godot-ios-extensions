import GameKit
import SwiftGodot

#if canImport(UIKit)
import UIKit
#endif

#initSwiftExtension(
	cdecl: "swift_entry_point",
	types: [
		GameCenter.self,
		GameCenterPlayer.self,
		GameCenterPlayerLocal.self,
		GameCenterLeaderboards.self,
		GameCenterLeaderboardEntry.self,
		GameCenterAchievements.self,
		GameCenterAchievement.self,
		GameCenterMultiplayerPeer.self,
	]
)

let OK: Int = 0
enum GameCenterError: Int, Error {
	case unknownError = 1
	case notAuthenticated = 2
	case notAvailable = 3
	case failedToAuthenticate = 4
	case failedToLoadFriends = 6
	case friendAccessRestricted = 7
	case failedToLoadPicture = 8
	case failedToLoadInvites = 9
}

@Godot
class GameCenter: RefCounted, GKInviteEventListener {
	/// Signal called when an invite is accepted
	#signal("invite_accepted", arguments: ["from": String.self, "index": Int.self])
	/// Signal called when an invite is removed
	#signal("invite_removed", arguments: ["index": Int.self])
	/// Signal called when an invite is send
	#signal("invite_sent", arguments: ["to": GArray.self])

	#if os(iOS)
	var viewController: GameCenterViewController = GameCenterViewController()
	#endif

	static var instance: GameCenter?
	var inviteDelegate: InviteDelegate?
	var invites: [GKInvite] = []

	var player: GameCenterPlayer?
	var friends: [GKPlayer]?

	required init() {
		super.init()
		GameCenter.instance = self
		inviteDelegate = InviteDelegate(withDelegate: self)
	}

	required init(nativeHandle: UnsafeRawPointer) {
		super.init(nativeHandle: nativeHandle)
		GameCenter.instance = self
		inviteDelegate = InviteDelegate(withDelegate: self)
	}

	// MARK: Authentication

	/// Authenticate with gameCenter.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: ``GameCenterPlayerLocal``)
	@Callable
	public func authenticate(onComplete: Callable = Callable()) {
		if GKLocalPlayer.local.isAuthenticated && self.player != nil {
			onComplete.call(Variant(OK), Variant(self.player!))
			return
		}

		#if os(iOS)

		GKLocalPlayer.local.authenticateHandler = { loginController, error in
			guard loginController == nil else {
				self.viewController.getRootController()?.present(loginController!, animated: true)
				return
			}

			guard error == nil else {
				GD.pushError("Failed to authenticate \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToAuthenticate.rawValue), Variant())
				return
			}

			if self.inviteDelegate != nil {
				GKLocalPlayer.local.register(self.inviteDelegate!)
			}

			var player = GameCenterPlayerLocal(GKLocalPlayer.local)
			onComplete.callDeferred(Variant(OK), Variant(player))
		}

		#elseif os(watchOS)

		GKLocalPlayer.local.authenticateHandler = { error in
			guard error == nil else {
				GD.pushError("Failed to authenticate \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToAuthenticate.rawValue), Variant())
				return
			}

			if self.inviteDelegate != nil {
				GKLocalPlayer.local.register(self.inviteDelegate!)
			}

			var player = GameCenterPlayerLocal(GKLocalPlayer.local)
			onComplete.callDeferred(Variant(OK), Variant(player))
		}

		#elseif os(macOS)

		GKLocalPlayer.local.authenticateHandler = { loginController, error in
			guard loginController == nil else {
				// TODO: Figure out how to show login window on macOS
				return
			}

			guard error == nil else {
				GD.pushError("Failed to authenticate \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToAuthenticate.rawValue), Variant())
				return
			}

			if self.inviteDelegate != nil {
				GKLocalPlayer.local.register(self.inviteDelegate!)
			}

			var player = GameCenterPlayerLocal(GKLocalPlayer.local)
			onComplete.callDeferred(Variant(OK), Variant(player))
		}

		#else
		GD.pushWarning("GameCenter not available on this platform")
		onComplete.call(Variant(GameCenterError.notAvailable.rawValue))
		#endif
	}

	@Callable
	func isAuthenticated() -> Bool {
		#if os(iOS)
		return GKLocalPlayer.local.isAuthenticated
		#else
		return false
		#endif
	}

	@Callable
	func getLocalPlayer(onComplete: Callable) {
		guard GKLocalPlayer.local.isAuthenticated && self.player != nil else {
			onComplete.call(Variant(GameCenterError.notAuthenticated.rawValue))
			return
		}

		onComplete.call(Variant(OK), Variant(self.player!))
	}

	/// Load the profile picture of the authenticated player.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: Image)
	@Callable
	func loadProfilePicture(onComplete: Callable) {
		Task {
			do {
				let image = try await GKLocalPlayer.local.loadImage(size: .small)
				onComplete.callDeferred(Variant(OK), Variant(image))
			} catch {
				GD.pushError("Failed to load profile picture. \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadPicture.rawValue), Variant())
			}
		}
	}

	// MARK: Friends

	/// Load the friends of the authenticated player.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, friends: Variant) -> (error: Int, friends: [``GameCenterPlayer``])
	@Callable
	func loadFriends(onComplete: Callable) {
		Task {
			do {
				var players = GArray()
				let friends = try await GKLocalPlayer.local.loadFriends()

				for friend in friends {
					players.append(Variant(GameCenterPlayer(friend)))
				}

				self.friends = friends
				onComplete.callDeferred(Variant(OK), Variant(players))

			} catch {
				GD.pushError("Error loading friends. \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadFriends.rawValue), Variant())
			}
		}
	}

	/// Load the profile picture of the given gamePlayerID.
	/// > NOTE: Only works on friends
	///
	/// - Parameters
	/// 	- onComplete: Callback with parameters: (error: Variant, data: Variant) -> (error: Int, data: Image)
	@Callable
	func loadFriendPicture(gamePlayerID: String, onComplete: Callable) {
		if friends == nil {
			loadFriends(onComplete: Callable())
		}

		Task {
			do {
				let friend = self.friends!.first(where: { $0.gamePlayerID == gamePlayerID })!
				let image = try await friend.loadImage(size: .small)
				onComplete.callDeferred(Variant(OK), Variant(image))
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
	@Callable
	func canAccessFriends(onComplete: Callable) {
		Task {
			do {
				let status = try await GKLocalPlayer.local.loadFriendsAuthorizationStatus()
				onComplete.callDeferred(Variant(OK), Variant(status.rawValue))
			} catch {
				GD.pushError("Error accessing friends: \(error).")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadFriends.rawValue), Variant())
			}
		}
	}

	// MARK: Invites

	/// Get the invite with index.
	///
	/// NOTE: There is no official functionality to load invites, so a list is kept which might hold expired invites
	///
	/// - Parameters:
	/// 	- index: The index in the internal list of invites
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: GameCenterInvite)
	@Callable
	func getInvite(withIndex index: Int, onComplete: Callable) {
		guard index >= 0 || index < invites.count else {
			onComplete.callDeferred(Variant(GameCenterError.notAvailable.rawValue), Variant())
			return
		}

		onComplete.callDeferred(Variant(OK), Variant(GameCenterInvite(invites[index])))
	}

	/// Get all the currently active invites.
	///
	/// NOTE: There is no official functionality to load invites, so a list is kept which might hold expired invites
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: [GameCenterInvite])
	@Callable
	func getInvites(onComplete: Callable) {
		Task {
			do {
				var result = GArray()
				let friends = try await GKLocalPlayer.local.loadFriends()

				for invite in invites {
					result.append(Variant(GameCenterInvite(invite)))
				}

				onComplete.callDeferred(Variant(OK), Variant(result))

			} catch {
				GD.pushError("Error loading invites. \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadInvites.rawValue), Variant())
			}
		}
	}

	/// Remove invite with index
	///
	/// - Parameters:
	/// 	- index: The index in the internal list of invites
	@Callable
	func removeInvite(withIndex index: Int) -> Bool {
		guard index >= 0 || index < invites.count else {
			return false
		}

		invites.remove(at: index)
		emit(signal: GameCenter.inviteRemoved, index)

		return true
	}

	// Internal

	func getInvite(withIndex index: Int) -> GKInvite? {
		guard index >= 0 || index < invites.count else {
			return nil
		}

		return invites[index]
	}

	// Invite protocol implementation

	func player(_ player: GKPlayer, didAccept invite: GKInvite) {
		GD.print("[GameCenter] Invite accepted: \(invite)")

		invites.append(invite)
		emit(signal: GameCenter.inviteAccepted, invite.sender.displayName, Int(invites.count - 1))
	}

	func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
		GD.print("[GameCenter] Invite sent to \(recipientPlayers)")
		var players: GArray = GArray()
		for recipient in recipientPlayers {
			players.append(Variant(GameCenterPlayer(recipient)))
		}

		emit(signal: GameCenter.inviteSent, players)
	}

	class InviteDelegate: NSObject, GKLocalPlayerListener {
		var delegate: GKInviteEventListener

		required init(withDelegate delegate: GKInviteEventListener) {
			self.delegate = delegate
			super.init()
		}

		func player(_ player: GKPlayer, didAccept invite: GKInvite) {
			delegate.player?(player, didAccept: invite)
		}

		func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
			delegate.player?(player, didRequestMatchWithRecipients: recipientPlayers)
		}
	}

	// MARK: UI Overlays

	/// Show GameCenter dashboard overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	@Callable
	func showOverlay(onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .dashboard), onClose: onClose)
		#endif
	}

	/// Show GameCenter friends overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	@Callable
	func showFriendsOverlay(onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .localPlayerFriendsList), onClose: onClose)
		#endif
	}

	/// Show GameCenter access point.
	///
	/// - Parameters:
	/// 	- showHighlights: A Boolean value that indicates whether to display highlights for achievements and current ranks for leaderboards.
	@Callable
	func showAccessPoint(showHighlights: Bool) {
		GKAccessPoint.shared.location = .topTrailing
		GKAccessPoint.shared.showHighlights = showHighlights
		GKAccessPoint.shared.isActive = true
	}

	/// Hide GameCenter access point.
	@Callable
	func hideAccessPoint() {
		GKAccessPoint.shared.isActive = false
	}
}
