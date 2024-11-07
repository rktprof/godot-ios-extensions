import GameKit
import SwiftGodot

/// Holds AchievementChallenge data in a Godot friendly format
@Godot
class GameCenterAchievementChallenge: GameCenterChallenge {
	@Export var achievement: GameCenterAchievement?

	convenience init(achievementChallenge challenge: GKAchievementChallenge) {
		self.init(challenge: challenge)

		if let achievement = challenge.achievement {
			self.achievement = GameCenterAchievement(achievement)
		}
	}
}
