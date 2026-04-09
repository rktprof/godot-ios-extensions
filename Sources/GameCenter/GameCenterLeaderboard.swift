import GameKit
import SwiftGodotRuntime

#if canImport(Foundation)
import Foundation
#endif

/// Holds leaderboard data in a Godot friendly format
@Godot
class GameCenterLeaderboard: RefCounted {
	@Export var leaderboardID: String?
	@Export var leaderboardGroupID: String?

	@Export var title: String?
	@Export var type: Int = GameCenter.LeaderboardType.classic.rawValue

	@Export var startDate: Double?
	@Export var nextStartDate: Double?
	@Export var duration: Double?

	convenience init(leaderboard: GKLeaderboard) {
		self.init()

		self.leaderboardID = leaderboard.baseLeaderboardID
		self.leaderboardGroupID = leaderboard.groupIdentifier

		self.title = leaderboard.title
		switch leaderboard.type {
		case .recurring: self.type = GameCenter.LeaderboardType.recurring.rawValue
		case .classic: self.type = GameCenter.LeaderboardType.classic.rawValue
		}

		#if canImport(Foundation)
		self.startDate = leaderboard.startDate?.timeIntervalSince1970
		self.nextStartDate = leaderboard.nextStartDate?.timeIntervalSince1970
		self.duration = leaderboard.duration
		#endif
	}
}
