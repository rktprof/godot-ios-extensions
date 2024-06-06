
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

	let OK:Int = 0
	let NOT_AUTHENTICATED:Int = 1
	let FAILED_TO_LOAD_ACHIEVEMENTS:Int = 2
	let FAILED_TO_RESET_ACHIEVEMENTS:Int = 3
	let FAILED_TO_SET_PROGRESS:Int = 4
	let FAILED_TO_LOAD_PROGRESS:Int = 5
	let FAILED_TO_REPORT_PROGRESS:Int = 6
	let NOTHING_TO_REPORT:Int = 7

	var hasLoadedAchievements:Bool = false
	var hasLoadedAchievementDescriptions:Bool = false
	private(set) var achievements:[GKAchievement] = []
	private(set) var achievementDescriptions:[GKAchievementDescription] = []

	@Callable
	func setAchievementProgress(achievementID:String, achievementProgress:Double, onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
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
				
				params.append(Variant(OK))
				onComplete.callv(arguments: params)
			}
			catch
			{
				GD.pushError("Failed to set achievement progress: \(error)")
				params.append(Variant(FAILED_TO_SET_PROGRESS))
				onComplete.callv(arguments: params)
			}
		}
		
	}

	@Callable
	func getAchievementProgress(achievementID:String, onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
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

				params.append(Variant(OK))
				params.append(Variant(achievement?.percentComplete ?? 0))
				onComplete.callv(arguments: params)
			}
			catch
			{
				GD.pushError("Failed to get achievement progress: \(error)")
				params.append(Variant(FAILED_TO_LOAD_PROGRESS))
				onComplete.callv(arguments: params)
			}
		}	
	}

	@Callable
	func reportAchievementProgress(onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				if (!GKLocalPlayer.local.isAuthenticated)
				{
					throw GKError(.notAuthenticated)
				}

				if (!hasLoadedAchievements)
				{
					params.append(Variant(NOTHING_TO_REPORT))
					onComplete.callv(arguments: params)
					return
				}

				try await GKAchievement.report(achievements)
			}
			catch
			{
				GD.pushError("Failed to report achievment progress: \(error)")
				params.append(Variant(FAILED_TO_REPORT_PROGRESS))
				onComplete.callv(arguments: params)
			}
		}
	}

	@Callable
	func getAchievements(onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
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

				params.append(Variant(OK))
				params.append(Variant(result))
				onComplete.callv(arguments: params)
			}
			catch
			{
				GD.pushError("Failed to get achievements: \(error)")
				params.append(Variant(FAILED_TO_LOAD_ACHIEVEMENTS))
				onComplete.callv(arguments: params)
			}
		}
	}

	@Callable
	func resetAchievements(onComplete:Callable)
	{
		Task
		{
			var params:GArray = GArray()
			do
			{
				try await GKAchievement.resetAchievements()
				params.append(Variant(OK))
				onComplete.callv(arguments: params)
			}
			catch
			{
				params.append(Variant(FAILED_TO_RESET_ACHIEVEMENTS))
				onComplete.callv(arguments: params)
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
