import Foundation
import GameKit

extension GKChallenge {

	/// Get an integer ID of the challenge
	///
	/// > NOTE: This is used in order to let Godot identify a challenge when declining
	///
	/// - Returns: An integer generated from the issueDate
	func getChallengeID() -> Int {
		// Not an ideal solution, but we need an ID to identify challenges
		// might want to look into playerID + issue date
		return Int(self.issueDate.timeIntervalSince1970)
	}

}
