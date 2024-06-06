import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

@Godot
class GameCenterLeaderboards:RefCounted
{
	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif

	@Callable
	func submitScore(score:Int, leaderboardIDs:[String], onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: leaderboardIDs)
				params.append(Variant(OK))
				onComplete.callv(arguments: params)
			}
			catch
			{
				GD.pushError("Error submitting score: \(error).")
				params.append(Variant(ERROR_FAILED_TO_SUBMIT_SCORE))
				onComplete.callv(arguments: params)
			}
		}
	}

	@Callable
	func getGlobalScores(leaderboardID:String, start:Int, length:Int, onComplete:Callable)
	{
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadLeaderboard(leaderboardID: leaderboardID, scope: .global, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getFriendsScores(leaderboardID:String, start:Int, length:Int, onComplete:Callable)
	{
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadLeaderboard(leaderboardID: leaderboardID, scope: .friendsOnly, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getPreviousOccurance(leaderboardID:String, start:Int, length:Int, onComplete:Callable)
	{
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadPreviousLeaderboard(leaderboardID: leaderboardID, scope: .global, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getPreviousFriendsOccurance(leaderboardID:String, start:Int, length:Int, onComplete:Callable)
	{
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadPreviousLeaderboard(leaderboardID: leaderboardID, scope: .friendsOnly, time: .allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getLocalPlayerEntry(leaderboardID:String, onComplete:Callable)
	{
		loadLocalPlayerEntry(leaderboardID:leaderboardID, time: .allTime, onComplete:onComplete)
	}

	@Callable
	func getPreviousLocalPlayerEntry(leaderboardID:String, onComplete:Callable)
	{
		loadPreviousLocalPlayerEntry(leaderboardID:leaderboardID, time:.allTime, onComplete:onComplete)
	}

	@Callable
	func showLeaderboards(onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .leaderboards), onClose: onClose)
		#endif
	}

	@Callable
	func showLeaderboard(leaderboardID:String, onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: GKLeaderboard.PlayerScope.global, timeScope: .allTime), onClose: onClose)
		#endif
	}

	func loadLeaderboard(leaderboardID:String, scope:GKLeaderboard.PlayerScope, time:GKLeaderboard.TimeScope, range:NSRange, onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
				if let leaderboard: GKLeaderboard = leaderboards.first
				{
					let (local, entries, count) = try await leaderboard.loadEntries(for: scope, timeScope:time, range:range)
					params.append(Variant(OK))

					// Add the local player
					if let local: GKLeaderboard.Entry {	
						params.append(Variant(GameCenterLeaderboardEntry(local)))
					} else {
						// Need to keep the signature consistent for godot to accept the function call
						params.append(Variant())
					}

					// Get all the players in range
					var players:GArray = GArray()
					for entry:GKLeaderboard.Entry in entries {
						players.append(Variant(GameCenterLeaderboardEntry(entry)))
					}
					params.append(Variant(players))

					// How many players, in total, are in the leaderboard
					params.append(Variant(count))
					onComplete.callv(arguments: params)
				}
			}
			catch
			{
				GD.pushError("Failed to get leaderboard: \(error)")
				params.append(Variant(ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES))
				onComplete.callv(arguments: params)
			}
		}
	}

	func loadPreviousLeaderboard(leaderboardID:String, scope:GKLeaderboard.PlayerScope, time:GKLeaderboard.TimeScope, range:NSRange, onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
				if let leaderboard: GKLeaderboard = try await leaderboards.first?.loadPreviousOccurrence()
				{	
					let (local, entries, count) = try await leaderboard.loadEntries(for: scope, timeScope:time, range:range)
					params.append(Variant(OK))

					// Add the local player
					if let local: GKLeaderboard.Entry {
						params.append(Variant(GameCenterLeaderboardEntry(local)))
					} else {
						// Need to keep the signature consistent for godot to accept the function call
						params.append(Variant())
					}

					// Get all the players in range
					var players:GArray = GArray()
					for entry:GKLeaderboard.Entry in entries {
						players.append(Variant(GameCenterLeaderboardEntry(entry)))
					}
					params.append(Variant(players))

					// How many players, in total, are in the leaderboard
					params.append(Variant(count))
					onComplete.callv(arguments: params)
				}
			}
			catch
			{
				GD.pushError("Failed to get leaderboard: \(error)")
				params.append(Variant(ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES))
				onComplete.callv(arguments: params)
			}
		}
	}

	func loadLocalPlayerEntry(leaderboardID:String, time:GKLeaderboard.TimeScope, onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
				if let leaderboard: GKLeaderboard = leaderboards.first
				{
					let (local, entries) = try await leaderboard.loadEntries(for: [GKLocalPlayer.local], timeScope:time)
					params.append(Variant(OK))

					if let local: GKLeaderboard.Entry {
						params.append(Variant(GameCenterLeaderboardEntry(local)))
					} else {
						// Need to keep the signature consistent for godot to accept the function call
						params.append(Variant())
					}

					// Get all the players in range
					var players:GArray = GArray()
					for entry:GKLeaderboard.Entry in entries {
						players.append(Variant(GameCenterLeaderboardEntry(entry)))
					}
					params.append(Variant(players))

					onComplete.callv(arguments: params)
				}
			}
			catch
			{
				GD.pushError("Failed to get leaderboard score for player: \(error)")
				params.append(Variant(ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES))
				onComplete.callv(arguments: params)
			}
		}
	}

	func loadPreviousLocalPlayerEntry(leaderboardID:String, time:GKLeaderboard.TimeScope, onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
				if let leaderboard: GKLeaderboard = try await leaderboards.first?.loadPreviousOccurrence()
				{
					let (local, entries) = try await leaderboard.loadEntries(for: [GKLocalPlayer.local], timeScope:time)
					params.append(Variant(OK))

					if let local: GKLeaderboard.Entry {
						params.append(Variant(GameCenterLeaderboardEntry(local)))
					} else {
						// Need to keep the signature consistent for godot to accept the function call
						params.append(Variant())
					}

					// Get all the players in range
					var players:GArray = GArray()
					for entry:GKLeaderboard.Entry in entries {
						players.append(Variant(GameCenterLeaderboardEntry(entry)))
					}
					params.append(Variant(players))
					
					onComplete.callv(arguments: params)
				}
			}
			catch
			{
				GD.pushError("Failed to get leaderboard score for player: \(error)")
				params.append(Variant(ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES))
				onComplete.callv(arguments: params)
			}
		}
	}
}