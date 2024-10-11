import SwiftGodot

/// Holds Achievement data in a Godot friendly format
@Godot
class GameCenterAchievement: RefCounted {
	@Export var identifier: String = ""
	@Export var title: String = ""
	@Export var unachievedDescription: String = ""
	@Export var achievedDescription: String = ""

	@Export var maximumPoints: Int = 0

	@Export var isHidden: Bool = false
	@Export var isReplayable: Bool = false

	@Export var percentComplete: Float = 0.0
	@Export var isCompleted: Bool = false

	@Export var rarityPercent: Float?
	@Export var image: Image?
}
