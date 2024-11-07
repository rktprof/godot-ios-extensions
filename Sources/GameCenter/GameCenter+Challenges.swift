import GameKit
import SwiftGodot

extension GameCenter {

	enum ChallengeError: Int, Error {
		case failedToLoadChallenges = 1
		case failedToLoadChallengableFriend = 2
		case noSuchChallenge = 3
	}

	/// Loads the list of outstanding challenges.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, friends: Variant) -> (error: Int, friends: [``GameCenterPlayer``])
	func loadReceivedChallenges(onComplete: Callable) {
		Task {
			do {
				var result = GArray()
				let challenges = try await GKChallenge.loadReceivedChallenges()

				for challenge in challenges {
					result.append(Variant(GameCenterChallenge.parseChallenge(challenge)))
				}

				onComplete.callDeferred(Variant(OK), Variant(result))
			} catch {
				GD.pushError("Error loading challenges: \(error)")
				onComplete.callDeferred(Variant(ChallengeError.failedToLoadChallenges.rawValue), Variant())
			}
		}
	}

	/// Loads players to whom the local player can issue a challenge.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, friends: Variant) -> (error: Int, friends: [``GameCenterPlayer``])
	func loadChallengablePlayers(onComplete: Callable) {
		Task {
			do {
				var players = GArray()
				let friends = try await GKLocalPlayer.local.loadChallengableFriends()

				for friend in friends {
					players.append(Variant(GameCenterPlayer(friend)))
				}

				onComplete.callDeferred(Variant(OK), Variant(players))

			} catch {
				GD.pushError("Error loading challengable friends: \(error)")
				onComplete.callDeferred(Variant(ChallengeError.failedToLoadChallengableFriend.rawValue), Variant())
			}
		}
	}

	/// Provides a challenge compose view controller with preselected player identifiers and a message.
	///
	/// > NOTE: This function will load a leaderboard filtered on the local player with a timeScope of ``GKLeaderboard.TimeScope.today``
	///
	/// - Parameters:
	/// 	- leaderboardID: The ID of the leaderboard to load scores for
	/// 	- receiverID: The ID of the player to receive the challenge
	/// 	- message: The preformatted, player-editable message that GameKit sends to the players in the challenge.
	/// 	- onComplete: Callback with parameters: (error: Variant, receivers: Variant) -> (error: Int, receivers: [``String``])
	func issueScoreChallenge(leaderboardID: String, receiverID: String, message: String, onComplete: Callable) {
		Task {
			do {
				GD.print("Inviting user with id: \(receiverID) to a challenge")
				let friends = try await GKLocalPlayer.local.loadChallengableFriends()
				guard let receiver = friends.first(where: { $0.gamePlayerID == receiverID }) else {
					onComplete.callDeferred(
						Variant(ChallengeError.failedToLoadChallengableFriend.rawValue),
						Variant(false)
					)
					return
				}

				let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
				if let leaderboard: GKLeaderboard = try await leaderboards.first {
					let (local, entries) = try await leaderboard.loadEntries(
						for: [GKLocalPlayer.local],
						timeScope: .today
					)

					if let local: GKLeaderboard.Entry {
						#if canImport(UIKit)
						DispatchQueue.main.async {
							// NOTE: We're actually using the old deprecated version that returns sentPlayers
							// as [String]? instead of the iOS 17+ [GKPlayer]? version for simplicity
							let challengeComposer = local.challengeComposeController(
								withMessage: message,
								players: [receiver]
							) {
								composeController,
								didIssueChallenge,
								sentPlayers in

								var players = GArray()
								GD.print("[GameCenter] Challenge sent to:")
								for player: String in sentPlayers ?? [] {
									GD.print("- ID: \(player)")
									players.append(Variant(player))
								}

								composeController.dismiss(animated: true)
								onComplete.callDeferred(Variant(OK), Variant(players))
							}

							self.viewController.getRootController()?.present(challengeComposer, animated: true)
						}
						#else
						onComplete.callDeferred(Variant(OK), Variant())
						#endif
					}
				}
			} catch {
				GD.pushError("Error issuing challenge: \(error)")
				onComplete.callDeferred(
					Variant(ChallengeError.failedToLoadChallengableFriend.rawValue),
					Variant()
				)
			}
		}
	}

	// TODO: Implement AchievementChallenge

	/// Decline a challenge.
	///
	/// - Parameters:
	/// 	- challengeID: The ID of the challenge to decline
	func declineChallenge(challengeID: Int, onComplete: Callable) {
		Task {
			do {
				GD.print("[GameCenter] Cancelling challenge with ID: \(challengeID)")
				let challenges = try await GKChallenge.loadReceivedChallenges()

				guard let challenge = challenges.first(where: { $0.getChallengeID() == challengeID }) else {
					GD.pushError("[GameCenter] Failed to find challenge with ID: \(challengeID)")
					onComplete.callDeferred(Variant(ChallengeError.noSuchChallenge.rawValue))
					return
				}

				challenge.decline()
				onComplete.callDeferred(Variant(OK))
			} catch {
				GD.pushError("Error loading challenges: \(error)")
				onComplete.callDeferred(Variant(ChallengeError.failedToLoadChallenges.rawValue), Variant())
			}
		}
	}

	// MARK: UI Overlay

	/// Show GameCenter challenges overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	func showChallengesOverlay(onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .challenges), onClose: onClose)
		#endif
	}

	// MARK: Internal

	func player(_ player: GKPlayer, didComplete challenge: GKChallenge, issuedByFriend friendPlayer: GKPlayer) {
		GD.print("[GameCenter] You completed the challenge from \(friendPlayer.displayName)")
		// emit(
		// 	signal: GameCenter.challengeCompleted,
		// 	GameCenterChallenge(challenge),
		// 	GameCenterPlayer(friendPlayer)
		// )
	}

	func player(
		_ player: GKPlayer,
		issuedChallengeWasCompleted challenge: GKChallenge,
		byFriend friendPlayer: GKPlayer
	) {
		GD.print("[GameCenter] Your issued challenge was completed by \(friendPlayer.displayName)")

		emit(
			signal: GameCenter.issuedChallengeCompleted,
			GameCenterChallenge.parseChallenge(challenge),
			GameCenterPlayer(friendPlayer)
		)
	}

	func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {
		GD.print("[GameCenter] Your issued challenge was accepted \(player.displayName)")
		// emit(
		// 	signal: GameCenter.issuedChallengeAccepted,
		// 	GameCenterChallenge(challenge),
		// 	GameCenterPlayer(player)
		// )
	}

	func player(_ player: GKPlayer, didReceive challenge: GKChallenge) {
		GD.print("[GameCenter] Your challenge was received by \(player.displayName)")
		// emit(
		// 	signal: GameCenter.issuedChallengeReceived,
		// 	GameCenterChallenge(challenge),
		// 	GameCenterPlayer(player)
		// )
	}

	// MARK: ChallengeDelegate

	class ChallengeDelegate: NSObject, GKLocalPlayerListener {
		var delegate: GameCenter

		required init(withDelegate delegate: GameCenter) {
			self.delegate = delegate
			super.init()
		}

		func player(_ player: GKPlayer, didComplete challenge: GKChallenge, issuedByFriend friendPlayer: GKPlayer) {
			delegate.player(player, didComplete: challenge, issuedByFriend: friendPlayer)
		}

		func player(
			_ player: GKPlayer,
			issuedChallengeWasCompleted challenge: GKChallenge,
			byFriend friendPlayer: GKPlayer
		) {
			delegate.player(player, issuedChallengeWasCompleted: challenge, byFriend: friendPlayer)
		}

		func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {
			delegate.player(player, wantsToPlay: challenge)
		}

		func player(_ player: GKPlayer, didReceive challenge: GKChallenge) {
			delegate.player(player, didReceive: challenge)
		}
	}
}
