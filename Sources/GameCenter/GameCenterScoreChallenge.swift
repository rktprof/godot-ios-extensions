import GameKit
import SwiftGodot

/// Holds ScoreChallenge data in a Godot friendly format
@Godot
class GameCenterScoreChallenge: GameCenterChallenge {
	@Export var score: Int = 0
	@Export var leaderboardEntry: GameCenterLeaderboardEntry?

	convenience init(scoreChallenge challenge: GKScoreChallenge) {
		self.init(challenge: challenge)

		if #available(iOS 17.4, macOS 14.4, *), let entry = challenge.leaderboardEntry {
			self.leaderboardEntry = GameCenterLeaderboardEntry(entry: entry)
			self.score = entry.score
		} else if let score = challenge.score {
			self.score = Int(score.value)
		}
	}
}
