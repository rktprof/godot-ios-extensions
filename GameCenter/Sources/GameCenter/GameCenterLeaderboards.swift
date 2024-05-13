import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

@Godot
class GameCenterLeaderboards:RefCounted
{
	#if os(iOS)
	var viewController:UIGameCenterViewController = UIGameCenterViewController()
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
		Task{
			var players:GArray = GArray()
			var result:GDictionary = GDictionary()
			
			let leaderboards: [GKLeaderboard] = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
			if let leaderboard: GKLeaderboard = leaderboards.first
			{
				leaderboard.loadEntries(for: scope, timeScope: time, range: range)
				{ (local:GKLeaderboard.Entry?, entries:[GKLeaderboard.Entry]?, count:Int, error: (any Error)?) in
					DispatchQueue.main.async {
						var params:GArray = GArray()

						if error != nil
						{
							GD.pushWarning(error)

							params.append(value: Variant(ERROR_FAILED_TO_LOAD_LEADERBOARD_ENTRIES))
							onComplete.callv(arguments: params)
							return
						}

						if let entries: [GKLeaderboard.Entry] = entries
						{
							for entry:GKLeaderboard.Entry in entries
							{
								var player:GameCenterLeaderboardPlayer = GameCenterLeaderboardPlayer()
								player.displayName = entry.player.displayName
								player.score = entry.score 
								players.append(value: Variant(player))
							}
						}

						params.append(value: Variant(OK))
						params.append(value: Variant(players))
						onComplete.callv(arguments: params)
					}
				}
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