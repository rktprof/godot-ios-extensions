import GameKit
import SwiftGodot

#if canImport(Foundation)
import Foundation
#endif

/// Holds Challenge data in a Godot friendly format
@Godot
class GameCenterChallenge: RefCounted {

	enum ChallengeState: Int, CaseIterable {
		case invalid = 0
		case pending = 1
		case completed = 2
		case declined = 3
	}

	@Export var challengeID: Int?

	@Export var issuingPlayer: GameCenterPlayer?
	@Export var receivingPlayer: GameCenterPlayer?

	@Export var message: String?

	@Export(.enum) var state: ChallengeState = .pending

	@Export var issueDate: Double?
	@Export var completionDate: Double?

	convenience init(challenge: GKChallenge) {
		self.init()

		self.challengeID = challenge.getChallengeID()
		GD.print("[GameCenter] Found challenge with ID: \(self.challengeID)")

		if let issuingPlayer = challenge.issuingPlayer {
			self.issuingPlayer = GameCenterPlayer(issuingPlayer)
		}

		if let receivingPlayer = challenge.receivingPlayer {
			self.receivingPlayer = GameCenterPlayer(receivingPlayer)
		}

		self.message = challenge.message
		self.state = ChallengeState(rawValue: challenge.state.rawValue) ?? ChallengeState.pending

		#if canImport(Foundation)
		// In order to read Date we need foundation, otherwise we crash

		self.issueDate = challenge.issueDate.timeIntervalSince1970
		if let completionDate = challenge.completionDate {
			self.completionDate = completionDate.timeIntervalSince1970
		}
		#endif
	}
}

extension GameCenterChallenge {
	static func parseChallenge(_ challenge: GKChallenge) -> GameCenterChallenge {
		if let scoreChallenge = challenge as? GKScoreChallenge {
			return GameCenterScoreChallenge(scoreChallenge: scoreChallenge)
		} else if let achievementChallenge = challenge as? GKAchievementChallenge {
			return GameCenterAchievementChallenge(achievementChallenge: achievementChallenge)
		} else {
			return GameCenterChallenge(challenge: challenge)
		}
	}
}
