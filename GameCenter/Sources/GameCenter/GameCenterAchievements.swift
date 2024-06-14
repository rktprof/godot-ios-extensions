
import SwiftGodot
import GameKit
#if os(iOS)
import UIKit
#endif

@Godot
class GameCenterAchievements:RefCounted
{
	#if os(iOS)
	var viewController:GameCenterViewController = GameCenterViewController()
	#endif

	var hasLoadedAchievements:Bool = false
	var hasLoadedAchievementDescriptions:Bool = false
	private(set) var achievements:[GKAchievement] = []
	private(set) var achievementDescriptions:[GKAchievementDescription] = []

	@Callable
	func setAchievementProgress(achievementID:String, achievementProgress:Double, onComplete:Callable)
	{
		Task
		{
			do
			{
				if (!hasLoadedAchievements)
				{
					try await updateAchievements()
				}

				var achievement:GKAchievement? = nil
				achievement = achievements.first(where: { $0.identifier == achievementID })

				if (achievement == nil)
				{
					achievement = GKAchievement(identifier: achievementID)
					achievements.append(achievement!)
				}

				achievement?.percentComplete = achievementProgress
				
				onComplete.callDeferred(Variant(OK))
			}
			catch
			{
				GD.pushError("Failed to set achievement progress: \(error)")
				onComplete.callDeferred(Variant(FAILED_TO_SET_PROGRESS))
			}
		}
		
	}

	@Callable
	func getAchievementProgress(achievementID:String, onComplete:Callable)
	{
		Task
		{
			do
			{
				if (!hasLoadedAchievements)
				{
					try await updateAchievements()
				}

				var achievement:GKAchievement? = nil
				achievement = achievements.first(where: { $0.identifier == achievementID })
				
				if (achievement == nil)
				{
					achievement = GKAchievement(identifier: achievementID)
					achievements.append(achievement!)
				}

				onComplete.callDeferred(Variant(OK), Variant(achievement?.percentComplete ?? 0))
			}
			catch
			{
				GD.pushError("Failed to get achievement progress: \(error)")
				onComplete.callDeferred(Variant(FAILED_TO_LOAD_PROGRESS), Variant())
			}
		}	
	}

	@Callable
	func reportAchievementProgress(onComplete:Callable)
	{
		Task
		{
			do
			{
				if (!GKLocalPlayer.local.isAuthenticated)
				{
					throw GKError(.notAuthenticated)
				}

				if (!hasLoadedAchievements)
				{
					onComplete.callDeferred(Variant(NOTHING_TO_REPORT))
				} else {
					try await GKAchievement.report(achievements)
					onComplete.callDeferred(Variant(OK))
				}
			}
			catch
			{
				GD.pushError("Failed to report achievment progress: \(error)")
				onComplete.callDeferred(Variant(FAILED_TO_REPORT_PROGRESS))
			}
		}
	}

	@Callable
	func getAchievements(onComplete:Callable)
	{
		Task
		{
			do
			{
				if (!hasLoadedAchievements)
				{
					try await updateAchievements()
				}

				if (!hasLoadedAchievementDescriptions)
				{
					try await updateAchievementDescriptions()
				}

				var result:GArray = GArray()
				for entry: GKAchievementDescription in achievementDescriptions
				{
					var achievement:GameCenterAchievement = GameCenterAchievement()
					achievement.identifier = entry.identifier
					achievement.title = entry.title
					achievement.unachievedDescription = entry.unachievedDescription
					achievement.achievedDescription = entry.achievedDescription
					achievement.maximumPoints = entry.maximumPoints
					achievement.isHidden = entry.isHidden
					achievement.isReplayable = entry.isReplayable
					if #available(iOS 17, macOS 14, *)
					{
						achievement.rarityPercent = entry.rarityPercent
					}

					// Apply completion data if any is available
					if let completion = achievements.first(where: { $0.identifier == entry.identifier })
					{
						achievement.percentComplete = completion.percentComplete
						achievement.isCompleted = completion.isCompleted
					}

					result.append(Variant(achievement))
				}

				onComplete.callDeferred(Variant(OK), Variant(result))
			}
			catch
			{
				GD.pushError("Failed to get achievements: \(error)")
				onComplete.callDeferred(Variant(FAILED_TO_LOAD_ACHIEVEMENTS), Variant())
			}
		}
	}

	@Callable
	func resetAchievements(onComplete:Callable)
	{
		Task
		{
			do
			{
				try await GKAchievement.resetAchievements()
				onComplete.callDeferred(Variant(OK))
			}
			catch
			{
				onComplete.callDeferred(Variant(FAILED_TO_RESET_ACHIEVEMENTS))
			}
		}
	}

	@Callable
	func showAchievements(onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .achievements), onClose: onClose)
		#endif
	}

	@Callable
	func showAchievement(achievementdID:String, onClose:Callable)
	{
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(achievementID: achievementdID), onClose: onClose)
		#endif
	}

	// Internal

	func updateAchievements() async throws
	{
		if (GKLocalPlayer.local.isAuthenticated)
		{
			self.achievements = try await GKAchievement.loadAchievements()
			hasLoadedAchievements = true
		}
		else
		{
			throw GKError(.notAuthenticated)
		}
	}

	func updateAchievementDescriptions() async throws
	{
		if (GKLocalPlayer.local.isAuthenticated)
		{
			self.achievementDescriptions = try await GKAchievementDescription.loadAchievementDescriptions()
			hasLoadedAchievementDescriptions = true
		}
		else
		{
			throw GKError(.notAuthenticated)
		}
	}
}
