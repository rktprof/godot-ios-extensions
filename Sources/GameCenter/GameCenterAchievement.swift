import GameKit
import SwiftGodot

#if canImport(Foundation)
import Foundation
#endif

/// Holds Achievement data in a Godot friendly format
@Godot
class GameCenterAchievement: RefCounted {
	@Export var identifier: String?
	@Export var player: GameCenterPlayer?

	@Export var isCompleted: Bool = false
	@Export var percentComplete: Float?

	@Export var lastReportedDate: Double?

	convenience init(_ achievement: GKAchievement) {
		self.init()

		self.identifier = achievement.identifier
		self.player = GameCenterPlayer(achievement.player)

		self.percentComplete = Float(achievement.percentComplete)
		self.isCompleted = achievement.isCompleted

		#if canImport(Foundation)
		// In order to read Date we need foundation, otherwise we crash
		self.lastReportedDate = achievement.lastReportedDate.timeIntervalSince1970
		#endif
	}
}
