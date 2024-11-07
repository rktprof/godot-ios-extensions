import GameKit
import SwiftGodot

extension GameCenter {

	enum AchievementError: Int, Error {
		case failedToLoadAchievement = 1
		case failedToLoadAchievementDescription = 2
		case failedToReset = 3

		case achievementNotFound = 4

		case failedToSetProgress = 5
		case failedToReportProgress = 6
	}

	/// Set Achievement progress.
	///
	/// > NOTE: This updates the progress locally, you need to report the progress with reportAchievementProgress
	/// 	in order to update on the server
	///
	/// - Parameters:
	/// 	- achievementID: The identifier for the achievement that you enter in App Store Connect.
	/// 	- percentComplete: A percentage value that states how far the player has progressed on the achievement. (0.0 - 100.0)
	/// 	- onComplete: Callback with parameter: (error: Variant) -> (error: Int)
	func setAchievementProgress(achievementID: String, percentComplete: Float, onComplete: Callable) {
		Task {
			do {
				if self.achievements == nil {
					try await updateAchievements()
				}

				if var achievement = self.achievements?.first(where: { $0.identifier == achievementID }) {
					achievement.percentComplete = Double(percentComplete)
				} else {
					var achievement = GKAchievement(identifier: achievementID)
					achievement.percentComplete = Double(percentComplete)

					if self.achievements == nil {
						self.achievements = []
					}

					self.achievements?.append(achievement)
				}

				onComplete.callDeferred(Variant(OK))
			} catch {
				GD.pushError("Failed to set achievement progress: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToSetProgress.rawValue))
			}
		}
	}

	/// Reports the player’s progress toward one or more achievements.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant) -> (error: Int)
	func reportAchievementProgress(onComplete: Callable) {
		Task {
			do {
				if !GKLocalPlayer.local.isAuthenticated {
					throw GKError(.notAuthenticated)
				}

				if let achievements = self.achievements {
					try await GKAchievement.report(achievements)
				}
				onComplete.callDeferred(Variant(OK))
			} catch {
				GD.pushError("Failed to report achievement progress: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToReportProgress.rawValue))
			}
		}
	}

	/// Get achievement.
	///
	/// - Parameters:
	/// 	- achievementID: The identifier for the achievement that you enter in App Store Connect.
	/// 	- onComplete: Callback with parameter: (error: Variant, achievement: Variant) -> (error: Int, achievement: ``GameCenterAchievement``)
	func getAchievement(achievementID: String, onComplete: Callable) {
		Task {
			do {
				if self.achievements == nil {
					try await updateAchievements()
				}

				if let achievement = self.achievements?.first(where: { $0.identifier == achievementID }) {
					onComplete.callDeferred(Variant(OK), Variant(GameCenterAchievement(achievement)))
				} else {
					throw AchievementError.achievementNotFound
				}

			} catch {
				GD.pushError("Failed to get achievement: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToLoadAchievement.rawValue), Variant())
			}
		}
	}

	/// Get achievement description.
	///
	/// - Parameters:
	/// 	- achievementID: The identifier for the achievement that you enter in App Store Connect.
	/// 	- onComplete: Callback with parameter: (error: Variant, achievementDescription: Variant) -> (error: Int, achievementDescription: ``GameCenterAchievementDescription``)
	func getAchievementDescription(achievementID: String, onComplete: Callable) {
		Task {
			do {
				if self.achievementDescriptions == nil {
					try await updateAchievementDescriptions()
				}

				if let description = self.achievementDescriptions?.first(where: { $0.identifier == achievementID }) {
					onComplete.callDeferred(Variant(OK), Variant(GameCenterAchievementDescription(description)))
				} else {
					throw AchievementError.achievementNotFound
				}

			} catch {
				GD.pushError("Failed to get achievement description: \(error)")
				onComplete.callDeferred(Variant(AchievementError.failedToLoadAchievement.rawValue), Variant())
			}
		}
	}

	/// Loads the achievements that you previously reported the player making progress toward.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, achievements: Variant) -> (error: Int, achievements: [``GameCenterAchievement``])
	func getAchievements(onComplete: Callable) {
		Task {
			do {
				if achievements == nil {
					try await updateAchievements()
				}

				var result: GArray = GArray()
				for entry: GKAchievement in self.achievements ?? [] {
					var achievement: GameCenterAchievement = GameCenterAchievement(entry)
					result.append(Variant(achievement))
				}

				onComplete.callDeferred(Variant(OK), Variant(result))
			}
		}
	}

	/// Downloads the localized descriptions of achievements from Game Center
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant, achievements: Variant) -> (error: Int, achievements: [``GameCenterAchievementDescription``])
	func getAchievementDescriptions(onComplete: Callable) {
		Task {
			do {
				if self.achievementDescriptions == nil {
					try await updateAchievementDescriptions()
				}

				var result: GArray = GArray()
				for entry: GKAchievementDescription in self.achievementDescriptions ?? [] {
					var achievement: GameCenterAchievementDescription = GameCenterAchievementDescription(entry)
					result.append(Variant(achievement))
				}

				onComplete.callDeferred(Variant(OK), Variant(result))
			} catch {
				GD.pushError("Failed to get achievements: \(error)")
				onComplete.callDeferred(
					Variant(AchievementError.failedToLoadAchievementDescription.rawValue),
					Variant()
				)
			}
		}
	}

	/// Resets the percentage completed for all of the player’s achievements.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameters: (error: Variant) -> (error: Int)
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

	// MARK: UI Overlay

	/// Show GameCenter achievements overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	func showAchievementsOverlay(onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .achievements), onClose: onClose)
		#endif
	}

	/// Show GameCenter achievements overlay with a specific achievement.
	///
	/// - Parameters:
	/// 	- achievementID: The identifier for the achievement that you enter in App Store Connect.
	/// 	- onClose: Called when the user closes the overlay.
	func showAchievementOverlay(achievementdID: String, onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(achievementID: achievementdID), onClose: onClose)
		#endif
	}

	// MARK: Internal

	func updateAchievements() async throws {
		if GKLocalPlayer.local.isAuthenticated {
			self.achievements = try await GKAchievement.loadAchievements()
		} else {
			throw GKError(.notAuthenticated)
		}
	}

	func updateAchievementDescriptions() async throws {
		if GKLocalPlayer.local.isAuthenticated {
			self.achievementDescriptions = try await GKAchievementDescription.loadAchievementDescriptions()
		} else {
			throw GKError(.notAuthenticated)
		}
	}
}
