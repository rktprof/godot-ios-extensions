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
				params.append(value: Variant(OK))
				onComplete.callv(arguments: params)
			}
			catch
			{
				GD.pushError("Error submitting score: \(error).")
				params.append(value:Variant(ERROR_FAILED_TO_SUBMIT_SCORE))
				onComplete.callv(arguments: params)
			}
		}
	}

	@Callable
	func getGlobalScores(leaderboardID:String, start:Int, length:Int, onComplete:Callable)
	{
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadLeaderboard(leaderboardID: leaderboardID, scope: GKLeaderboard.PlayerScope.global, time: GKLeaderboard.TimeScope.allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
	}

	@Callable
	func getFriendsScores(leaderboardID:String, start:Int, length:Int, onComplete:Callable)
	{
		let rangeStart: Int = max(start, 1)
		let rangeLength: Int = min(length, 100)
		loadLeaderboard(leaderboardID: leaderboardID, scope: GKLeaderboard.PlayerScope.friendsOnly, time: GKLeaderboard.TimeScope.allTime, range: NSMakeRange(rangeStart, rangeLength), onComplete: onComplete)
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
					params.append(value: Variant(OK))

					// Add the local player
					if let local: GKLeaderboard.Entry
					{
						var localPlayer:GameCenterLeaderboardPlayer = GameCenterLeaderboardPlayer()
						localPlayer.rank = local.rank
						localPlayer.displayName = local.player.displayName
						localPlayer.score = local.score
						localPlayer.formattedScore = local.formattedScore
						localPlayer.date = local.date.timeIntervalSince1970
						
						params.append(value: Variant(localPlayer))
					}
					else
					{
						// Need to keep the signature consistent for godot to accept the function call
						params.append(value: Variant())
					}

					// Get all the players in range
					var players:GArray = GArray()
					for entry:GKLeaderboard.Entry in entries
					{
						var player:GameCenterLeaderboardPlayer = GameCenterLeaderboardPlayer()
						player.rank = entry.rank
						player.displayName = entry.player.displayName
						player.score = entry.score
						player.formattedScore = entry.formattedScore
						player.date = entry.date.timeIntervalSince1970

						players.append(value: Variant(player))
					}
					params.append(value: Variant(players))

					// How many players, in total, are in the leaderboard
					params.append(value: Variant(count))
	
					onComplete.callv(arguments: params)
				}
			}
			catch
			{
				GD.pushError("Failed to get leaderboard: \(error)")
				params.append(value: Variant(ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES))
				onComplete.callv(arguments: params)
			}
		}
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
}