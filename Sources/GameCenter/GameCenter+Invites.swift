import GameKit
import SwiftGodotRuntime

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
		guard let invite = getInvite(withIndex:index) else {
			onComplete.callDeferred(Variant(GameCenterError.notAvailable.rawValue), nil)
			return
		}

		onComplete.callDeferred(Variant(OK), Variant(GameCenterInvite(invite, index:index)))
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
				GD.print("[GameCenter] Gettings invites...")

				guard invites != nil else {
					onComplete.callDeferred(Variant(OK), nil)
					return
				}

				var invites = VariantArray()				
				for index in 0..<self.invites!.count {
					invites.append(Variant(GameCenterInvite(self.invites![index], index: index)))
				} 

				onComplete.callDeferred(Variant(OK), Variant(invites))

			} catch {
				GD.pushError("Error loading invites. \(error)")
				onComplete.callDeferred(Variant(InviteError.failedToLoadInvites.rawValue), nil)
			}
		}
	}

	/// Remove invite with index
	///
	/// - Parameters:
	/// 	- index: The index in the internal list of invites
	func removeInvite(withIndex index: Int) -> Bool {
		guard let invite = getInvite(withIndex: index) else {
			return false
		}

		self.inviteRemoved.emit(GameCenterInvite(invite, index:index))
		self.invites?.remove(at: index)

		return true
	}

	// MARK: Internal

	func getInvite(withIndex index: Int) -> GKInvite? {
		guard var invites = self.invites else {
			return nil
		}

		guard index >= 0 || index < invites.count else {
			GD.print("[GameCenter] No invites found with index \(index)")
			return nil
		}

		return invites[index]
	}

	func player(_ player: GKPlayer, didAccept invite: GKInvite) {
		if self.invites == nil {
			invites = []
		}
		let index:Int = invites!.count
		self.invites!.append(invite)

		GD.print("[GameCenter] Invite accepted: \(invite), index: \(index)")
		self.inviteAccepted.emit(GameCenterInvite(invite, index: index))
	}

	func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
		GD.print("[GameCenter] Invite sent to \(recipientPlayers)")
		var players = VariantArray()
		for recipient in recipientPlayers {
			players.append(Variant(GameCenterPlayer(recipient)))
		}

		self.inviteSent.emit(players)
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
