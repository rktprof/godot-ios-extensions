import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

@Godot
class GameCenterLeaderboards:RefCounted {
	enum LeaderboardError:Int, Error {
		case failedToLoadEntries = 1
		case failedToSubmitScore = 2
	}

	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif

	// MARK: Godot functions

	@Callable
	func submitScore(score:Int, leaderboardIDs:[String], onComplete:Callable) {
		Task {
			do {
				try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: leaderboardIDs)
				onComplete.callDeferred(Variant(OK))
			} catch {
				GD.pushError("Error submitting score: \(error).")
				onComplete.callDeferred(Variant(LeaderboardError.failedToSubmitScore.rawValue))
			}
		}
	}

	@Callable
	func getGlobalScores(leaderboardID:String, start:Int, length:Int, onComplete:Callable) {
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadLeaderboard(leaderboardID: leaderboardID, scope: .global, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getFriendsScores(leaderboardID:String, start:Int, length:Int, onComplete:Callable) {
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadLeaderboard(leaderboardID: leaderboardID, scope: .friendsOnly, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getPreviousOccurance(leaderboardID:String, start:Int, length:Int, onComplete:Callable) {
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadPreviousLeaderboard(leaderboardID: leaderboardID, scope: .global, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getPreviousFriendsOccurance(leaderboardID:String, start:Int, length:Int, onComplete:Callable) {
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadPreviousLeaderboard(leaderboardID: leaderboardID, scope: .friendsOnly, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func showLeaderboards(onClose:Callable) {
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .leaderboards), onClose: onClose)
		#endif
	}

	@Callable
	func showLeaderboard(leaderboardID:String, onClose:Callable) {
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: GKLeaderboard.PlayerScope.global, timeScope: .allTime), onClose: onClose)
		#endif
	}

	// MARK: Internal

	func loadLeaderboard(leaderboardID:String, scope:GKLeaderboard.PlayerScope, time:GKLeaderboard.TimeScope, range:NSRange, onComplete:Callable) {
		Task {
			do {
				let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
				if let leaderboard: GKLeaderboard = leaderboards.first {
					let (local, entries, count) = try await leaderboard.loadEntries(for: scope, timeScope:time, range:range)

					// Add the local player
					var localPlayer:Variant = Variant()
					if let local: GKLeaderboard.Entry {
						localPlayer = Variant(GameCenterLeaderboardEntry(local))
					}

					// Get all the players in range
					var players:GArray = GArray()
					for entry:GKLeaderboard.Entry in entries {
						players.append(Variant(GameCenterLeaderboardEntry(entry)))
					}

					onComplete.callDeferred(Variant(OK), localPlayer, Variant(players), Variant(count))
				} else {
					onComplete.callDeferred(Variant(LeaderboardError.failedToLoadEntries.rawValue), Variant(), Variant(), Variant(0))
				}
			} catch {
				GD.pushError("Failed to get leaderboard: \(error)")
				onComplete.callDeferred(Variant(LeaderboardError.failedToLoadEntries.rawValue), Variant(), Variant(), Variant(0))
			}
		}
	}

	func loadPreviousLeaderboard(leaderboardID:String, scope:GKLeaderboard.PlayerScope, time:GKLeaderboard.TimeScope, range:NSRange, onComplete:Callable) {
		Task {
			do {
				let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
				if let leaderboard: GKLeaderboard = try await leaderboards.first?.loadPreviousOccurrence() {	
					let (local, entries, count) = try await leaderboard.loadEntries(for: scope, timeScope:time, range:range)

					// Add the local player
					var localPlayer:Variant = Variant()
					if let local: GKLeaderboard.Entry {
						localPlayer = Variant(GameCenterLeaderboardEntry(local))
					}

					// Get all the players in range
					var players:GArray = GArray()
					for entry:GKLeaderboard.Entry in entries {
						players.append(Variant(GameCenterLeaderboardEntry(entry)))
					}

					onComplete.callDeferred(Variant(OK), localPlayer, Variant(players), Variant(count))
				} else {
					onComplete.callDeferred(Variant(LeaderboardError.failedToLoadEntries.rawValue), Variant(), Variant(), Variant(0))
				}
			} catch {
				GD.pushError("Failed to get leaderboard: \(error)")
				onComplete.callDeferred(Variant(LeaderboardError.failedToLoadEntries.rawValue), Variant(), Variant(), Variant(0))
			}
		}
	}
}