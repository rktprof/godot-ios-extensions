import GameKit
import SwiftGodot

#if os(iOS)
import UIKit
#endif

@Godot
class GameCenterAchievements: RefCounted {
	enum AchievementError: Int, Error {
		case failedToLoad = 0
		case failedToReset = 1
		case failedToSetProgress = 2
		case failedToLoadProgress = 3
		case failedToReportPorgress = 4
		case nothingToReport = 5
	}

	#if os(iOS)
	var viewController: GameCenterViewController = GameCenterViewController()
	#endif

	var hasLoadedAchievements: Bool = false
	var hasLoadedAchievementDescriptions: Bool = false
	private(set) var achievements: [GKAchievement] = []
	private(set) var achievementDescriptions: [GKAchievementDescription] = []

	// MARK: Godot functions

	/// Set Achievement progress.
	///
	/// - Parameters:
	/// 	- achievementID: The identifier for the achievement that you enter in App Store Connect.
	/// 	- achievementProgress: A percentage value that states how far the player has progressed on the achievement. (0.0 - 100.0)
	/// 	- onComplete: Callback with parameter: (error: Variant) -> (error: Int)
	@Callable
	func setAchievementProgress(achievementID: String, achievementProgress: Float, onComplete: Callable) {
		Task {
			do {
				if !hasLoadedAchievements {
					try await updateAchievements()
				}

				var achievement: GKAchievement? = nil
				achievement = achievements.first(where: { $0.identifier == achievementID })

				if achievement == nil {
					achievement = GKAchievement(identifier: achievementID)
					achievements.append(achievement!)
				}

				achievement?.percentComplete = Double(achievementProgress)

				onComplete.callDeferred(Variant(OK))
			} catch {
				GD.pushError("Failed to set achievement progress: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToSetProgress.rawValue))
			}
		}
	}

	/// Get Achievement progress.
	///
	/// - Parameters:
	/// 	- achievementID: The identifier for the achievement that you enter in App Store Connect.
	/// 	- onComplete: Callback with parameter: (error: Variant, progress: Variant) -> (error: Int, progress: Float)
	@Callable
	func getAchievementProgress(achievementID: String, onComplete: Callable) {
		Task {
			do {
				if !hasLoadedAchievements {
					try await updateAchievements()
				}

				var achievement: GKAchievement? = nil
				achievement = achievements.first(where: { $0.identifier == achievementID })

				if achievement == nil {
					achievement = GKAchievement(identifier: achievementID)
					achievements.append(achievement!)
				}

				onComplete.callDeferred(Variant(OK), Variant(achievement?.percentComplete ?? 0))
			} catch {
				GD.pushError("Failed to get achievement progress: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToLoadProgress.rawValue), Variant())
			}
		}
	}

	/// Reports the player’s Achievement progress.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant) -> (error: Int)
	@Callable
	func reportAchievementProgress(onComplete: Callable) {
		Task {
			do {
				if !GKLocalPlayer.local.isAuthenticated {
					throw GKError(.notAuthenticated)
				}

				if !hasLoadedAchievements {
					onComplete.callDeferred(Variant(AchievementError.nothingToReport.rawValue))
				} else {
					try await GKAchievement.report(achievements)
					onComplete.callDeferred(Variant(OK))
				}
			} catch {
				GD.pushError("Failed to report achievment progress: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToReportPorgress.rawValue))
			}
		}
	}

	/// Reports the player’s progress of players toward one or more achievements.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, achievements: Variant) -> (error: Int, achievements: [``GameCenterAchievement``])
	@Callable
	func getAchievements(onComplete: Callable) {
		Task {
			do {
				if !hasLoadedAchievements {
					try await updateAchievements()
				}

				if !hasLoadedAchievementDescriptions {
					try await updateAchievementDescriptions()
				}

				var result: GArray = GArray()
				for entry: GKAchievementDescription in achievementDescriptions {
					var achievement: GameCenterAchievement = GameCenterAchievement()
					achievement.identifier = entry.identifier
					achievement.title = entry.title
					achievement.unachievedDescription = entry.unachievedDescription
					achievement.achievedDescription = entry.achievedDescription
					achievement.maximumPoints = entry.maximumPoints
					achievement.isHidden = entry.isHidden
					achievement.isReplayable = entry.isReplayable
					if #available(iOS 17, macOS 14, *) {
						achievement.rarityPercent = Float(entry.rarityPercent ?? 0)
					}

					// Apply completion data if any is available
					if let completion = achievements.first(where: { $0.identifier == entry.identifier }) {
						achievement.percentComplete = Float(completion.percentComplete)
						achievement.isCompleted = completion.isCompleted
					}

					result.append(Variant(achievement))
				}

				onComplete.callDeferred(Variant(OK), Variant(result))
			} catch {
				GD.pushError("Failed to get achievements: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToLoad.rawValue), Variant())
			}
		}
	}

	/// Resets the percentage completed for all of the player’s achievements.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant) -> (error: Int)
	@Callable
	func resetAchievements(onComplete: Callable) {
		Task {
			do {
				try await GKAchievement.resetAchievements()
				onComplete.callDeferred(Variant(OK))
			} catch {
				onComplete.callDeferred(Variant(AchievementError.failedToReset.rawValue))
			}
		}
	}

	/// Show GameCenter achievements overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	@Callable
	func showAchievements(onClose: Callable) {
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(state: .achievements), onClose: onClose)
		#endif
	}

	/// Show GameCenter achievements overlay with a specific achievement.
	///
	/// - Parameters:
	/// 	- achievementID: The identifier for the achievement that you enter in App Store Connect.
	/// 	- onClose: Called when the user closes the overlay.
	@Callable
	func showAchievement(achievementdID: String, onClose: Callable) {
		#if os(iOS)
		viewController.showUIController(GKGameCenterViewController(achievementID: achievementdID), onClose: onClose)
		#endif
	}

	// MARK: Internal

	func updateAchievements() async throws {
		if GKLocalPlayer.local.isAuthenticated {
			self.achievements = try await GKAchievement.loadAchievements()
			hasLoadedAchievements = true
		} else {
			throw GKError(.notAuthenticated)
		}
	}

	func updateAchievementDescriptions() async throws {
		if GKLocalPlayer.local.isAuthenticated {
			self.achievementDescriptions = try await GKAchievementDescription.loadAchievementDescriptions()
			hasLoadedAchievementDescriptions = true
		} else {
			throw GKError(.notAuthenticated)
		}
	}
}
