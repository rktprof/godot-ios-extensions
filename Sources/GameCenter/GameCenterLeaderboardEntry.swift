import GameKit
import SwiftGodot

#if canImport(Foundation)
import Foundation
#endif

/// Holds Leaderboard data in a Godot friendly format
@Godot
class GameCenterLeaderboardEntry: RefCounted {
	@Export var context: Int?
	@Export var formattedScore: String = ""

	@Export var rank: Int = 0
	@Export var score: Int = 0

	@Export var player: GameCenterPlayer?

	@Export var date: Double?
	@Export var image: Image?

	convenience init(entry: GKLeaderboard.Entry, image: Image? = nil, excludeDate: Bool = false) {
		self.init()

		self.context = entry.context
		self.formattedScore = entry.formattedScore

		self.rank = entry.rank
		self.score = entry.score

		self.player = GameCenterPlayer(entry.player)
		self.image = image

		#if canImport(Foundation)
		// In order to read Date we need foundation, otherwise we crash
		// We also crash when reading date from entries within challenges for some reason
		if !excludeDate {
			//self.date = entry.date.timeIntervalSince1970
		}
		#endif
	}
}
