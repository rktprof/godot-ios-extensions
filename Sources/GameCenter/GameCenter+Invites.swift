import GameKit
import SwiftGodot

extension GameCenter {

	enum InviteError: Int, Error {
		case failedToLoadInvites = 1
	}

	/// Get the invite with index.
	///
	/// NOTE: There is no official functionality to load invites, so a list is kept which might hold expired invites
	///
	/// - Parameters:
	/// 	- index: The index in the internal list of invites
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: GameCenterInvite)
	func getInvite(withIndex index: Int, onComplete: Callable) {
		guard let invites = self.invites else {
			onComplete.callDeferred(Variant(GameCenterError.notAvailable.rawValue), Variant())
			return
		}
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
	func getInvites(onComplete: Callable) {
		Task {
			do {
				var invites = GArray()
				for invite in self.invites ?? [] {
					invites.append(Variant(GameCenterInvite(invite)))
				}

				onComplete.callDeferred(Variant(OK), Variant(invites))

			} catch {
				GD.pushError("Error loading invites. \(error)")
				onComplete.callDeferred(Variant(InviteError.failedToLoadInvites.rawValue), Variant())
			}
		}
	}

	/// Remove invite with index
	///
	/// - Parameters:
	/// 	- index: The index in the internal list of invites
	func removeInvite(withIndex index: Int) -> Bool {
		guard var invites = self.invites else {
			return false
		}

		guard index >= 0 || index < invites.count else {
			return false
		}

		invites.remove(at: index)
		emit(signal: GameCenter.inviteRemoved, index)

		return true
	}

	// MARK: Internal

	func getInvite(withIndex index: Int) -> GKInvite? {
		guard var invites = self.invites else {
			return nil
		}

		guard index >= 0 || index < invites.count else {
			return nil
		}

		return invites[index]
	}

	func player(_ player: GKPlayer, didAccept invite: GKInvite) {
		GD.print("[GameCenter] Invite accepted: \(invite)")

		if self.invites == nil {
			invites = []
		}

		self.invites!.append(invite)
		emit(signal: GameCenter.inviteAccepted, invite.sender.displayName, Int(invites!.count - 1))
	}

	func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
		GD.print("[GameCenter] Invite sent to \(recipientPlayers)")
		var players: GArray = GArray()
		for recipient in recipientPlayers {
			players.append(Variant(GameCenterPlayer(recipient)))
		}

		emit(signal: GameCenter.inviteSent, players)
	}

	// MARK: InviteDelegate

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
}
