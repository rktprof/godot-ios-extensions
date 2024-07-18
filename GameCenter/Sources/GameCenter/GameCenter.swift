// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftGodot
import GameKit
#if canImport(UIKit)
import UIKit
#endif

#initSwiftExtension(cdecl: "swift_entry_point", types: [
	GameCenter.self,
	GameCenterPlayer.self,
	GameCenterPlayerLocal.self,
	GameCenterLeaderboards.self,
	GameCenterLeaderboardEntry.self,
	GameCenterAchievements.self,
	GameCenterAchievement.self,
	GameCenterMultiplayerPeer.self,
])

let OK:Int = 0
enum GameCenterError:Int, Error {
	case unknownError = 1
	case notAuthenticated = 2
	case notAvailable = 3
	case failedToAuthenticate = 4
	case failedToLoadFriends = 6
	case friendAccessRestricted = 7
	case failedToLoadPicture = 8
}

@Godot
class GameCenter:RefCounted, GKInviteEventListener {
	#signal("invite_received", arguments: ["from": String.self, "index": Int.self])

	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif
	
	static var instance:GameCenter?
	var inviteDelegate:InviteDelegate?
	var invites:[GKInvite] = []

	var player:GameCenterPlayer?
	var friends:[GKPlayer]?

	required init() {
		super.init()
		GameCenter.instance = self
		inviteDelegate = InviteDelegate(withDelegate: self)
	}

	required init(nativeHandle:UnsafeRawPointer) {
		super.init(nativeHandle: nativeHandle)
		GameCenter.instance = self
		inviteDelegate = InviteDelegate(withDelegate: self)
	}

	// MARK: Authentication

	@Callable
	func authenticate(onComplete:Callable = Callable()) {
		if GKLocalPlayer.local.isAuthenticated && self.player != nil {
			onComplete.call(Variant(OK), Variant(self.player!))
			return
		}

		#if os(iOS)

		GKLocalPlayer.local.authenticateHandler = { loginController, error in
			guard loginController == nil else {
				self.viewController.getRootController()?.present(loginController!, animated:true)
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
		guard GKLocalPlayer.local.isAuthenticated && self.player != nil else {
			onComplete.call(Variant(GameCenterError.notAuthenticated.rawValue))
			return
		}

		onComplete.call(Variant(OK), Variant(self.player!))
	}

	@Callable
	func loadProfilePicture(onComplete:Callable) {
		Task {
			do {
				GD.print("Loading profile picture")
				let image = try await GKLocalPlayer.local.loadImage(size: .small)
				onComplete.callDeferred(Variant(OK), Variant(image))
			} catch {
				GD.pushError("Failed to load profile picture. \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadPicture.rawValue), Variant())
			}
		}
	}

	// MARK: Friends

	@Callable
	func loadFriends(onComplete:Callable) {
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
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadFriends.rawValue))
			}
		}
	}

	@Callable
	func loadFriendPicture(gamePlayerID:String, onComplete:Callable) {
		if friends == nil {
			loadFriends(onComplete: Callable())
		}

		Task {
			do {
				let friend = self.friends!.first(where: { $0.gamePlayerID == gamePlayerID })!
				let image = try await friend.loadImage(size:.small)
				onComplete.callDeferred(Variant(OK), Variant(image))
			} catch {
				GD.pushError("Failed to load friend picture. \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadPicture.rawValue), Variant())
			}
		}
	}

	@Callable
	func canAccessFriends(onComplete:Callable) {
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

	// MARK: UI Overlays

	@Callable
	func showOverlay(onClose:Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .dashboard), onClose: onClose)
		#endif
	}

	@Callable
	func showFriendsOverlay(onClose:Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .localPlayerFriendsList), onClose: onClose)
		#endif
	}

	@Callable
	func showAccessPoint(showHighlights:Bool) {
		GKAccessPoint.shared.location = .topTrailing
		GKAccessPoint.shared.showHighlights = showHighlights
		GKAccessPoint.shared.isActive = true
	}

	@Callable
	func hideAccessPoint() {
		GKAccessPoint.shared.isActive = false
	}

	// Internal

	func getInvite(withIndex index:Int) -> GKInvite {
		return invites[index]
	}

	func removeInvite(withIndex index:Int) {
		invites.remove(at: index)
	}

	// Invite protocol implementation

	func player(_ player:GKPlayer, didAccept invite: GKInvite) {
		GD.print("[GameCenter] Invite accepted: \(invite)")
		
		invites.append(invite)
		emit(signal:GameCenter.inviteReceived, invite.sender.displayName, Int(invites.count - 1))
	}

	func player(_ player:GKPlayer, didRequestMatchWithRecipients recipientPlayers:[GKPlayer]) {
		GD.print("[GameCenter] Invite sent to \(recipientPlayers)")
	}

	class InviteDelegate:NSObject, GKLocalPlayerListener {
		var delegate:GKInviteEventListener

		required init(withDelegate delegate:GKInviteEventListener) {	
			self.delegate = delegate
			super.init()
		}

		func player(_ player:GKPlayer, didAccept invite: GKInvite) {
			delegate.player?(player, didAccept: invite)
		}

		func player(_ player:GKPlayer, didRequestMatchWithRecipients recipientPlayers:[GKPlayer]) {
			delegate.player?(player, didRequestMatchWithRecipients: recipientPlayers)
		}
	}
}