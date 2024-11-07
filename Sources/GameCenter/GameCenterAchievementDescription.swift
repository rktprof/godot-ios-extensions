import GameKit
import SwiftGodot

/// Holds AchievementDescription data in a Godot friendly format
@Godot
class GameCenterAchievementDescription: RefCounted {
	@Export var identifier: String?
	@Export var title: String?

	@Export var unachievedDescription: String?
	@Export var achievedDescription: String?

	@Export var maximumPoints: Int?

	@Export var isHidden: Bool = false
	@Export var isReplayable: Bool = false

	@Export var rarityPercent: Float?

	convenience init(_ description: GKAchievementDescription) {
		self.init()

		self.identifier = description.identifier
		self.title = description.title

		self.unachievedDescription = description.unachievedDescription
		self.achievedDescription = description.achievedDescription

		self.maximumPoints = description.maximumPoints

		self.isHidden = description.isHidden
		self.isReplayable = description.isReplayable

		if #available(iOS 17, macOS 14, *), let rarityPercent = description.rarityPercent {
			self.rarityPercent = Float(rarityPercent)
		}
	}
}
