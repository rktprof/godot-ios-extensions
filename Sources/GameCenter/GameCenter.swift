import GameKit
import SwiftGodot

#if canImport(UIKit)
import UIKit
#endif

#initSwiftExtension(
	cdecl: "swift_entry_point",
	types: [
		GameCenter.self,
		GameCenterMultiplayerPeer.self,
		GameCenterPlayer.self,
		GameCenterPlayerLocal.self,
		GameCenterLeaderboardEntry.self,
		GameCenterAchievement.self,
		GameCenterChallenge.self,
		GameCenterScoreChallenge.self,
		GameCenterAchievementChallenge.self,
	]
)

let OK: Int = 0

@Godot
class GameCenter: RefCounted, GKInviteEventListener {
	enum GameCenterError: Int, Error {
		case unknownError = 1
		case notAuthenticated = 2
		case notAvailable = 3
		case failedToAuthenticate = 4
		case failedToLoadPicture = 8
	}

	/// Signal called when a challenge was received
	@Signal var challengeReceived: SignalWithArguments<GameCenterChallenge, GameCenterPlayer>

	/// Signal called when you completed a challenge
	@Signal var challengeCompleted: SignalWithArguments<GameCenterChallenge, GameCenterPlayer>

	/// Signal called when a challenge was completed
	@Signal var issuedChallengeCompleted: SignalWithArguments<GameCenterChallenge, GameCenterPlayer>

	/// Signal called when an invite is accepted
	@Signal var inviteAccepted: SignalWithArguments<String, Int>

	/// Signal called when an invite is removed
	@Signal var inviteRemoved: SignalWithArguments<Int>

	/// Signal called when an invite is send
	@Signal var inviteSent: SignalWithArguments<VariantArray>

	#if canImport(UIKit)
	var viewController: GameCenterViewController = GameCenterViewController()
	#endif

	static var instance: GameCenter?
	var player: GameCenterPlayer?

	var inviteDelegate: InviteDelegate?
	var challengeDelegate: ChallengeDelegate?

	internal(set) var friends: [GKPlayer]?
	internal(set) var invites: [GKInvite]?
	internal(set) var achievements: [GKAchievement]?
	internal(set) var achievementDescriptions: [GKAchievementDescription]?

	required init() {
		super.init()
		GameCenter.instance = self
		inviteDelegate = InviteDelegate(withDelegate: self)
		challengeDelegate = ChallengeDelegate(withDelegate: self)
	}

	required init(nativeHandle: UnsafeRawPointer) {
		super.init(nativeHandle: nativeHandle)
		GameCenter.instance = self
		inviteDelegate = InviteDelegate(withDelegate: self)
		challengeDelegate = ChallengeDelegate(withDelegate: self)
	}

	// MARK: Authentication

	/// Authenticate with gameCenter.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: ``GameCenterPlayerLocal``)
	@Callable(autoSnakeCase: true)
	public func authenticate(onComplete: Callable = Callable()) {
		if GKLocalPlayer.local.isAuthenticated && self.player != nil {
			onComplete.call(Variant(OK), Variant(self.player!))
			return
		}

		#if os(iOS)

		GKLocalPlayer.local.authenticateHandler = { loginController, error in
			guard loginController == nil else {
				self.viewController.getRootController()?.present(loginController!, animated: true)
				return
			}

			guard error == nil else {
				GD.pushError("Failed to authenticate \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToAuthenticate.rawValue), nil)
				return
			}

			if self.inviteDelegate != nil {
				GKLocalPlayer.local.register(self.inviteDelegate!)
			}

			if self.challengeDelegate != nil {
				GKLocalPlayer.local.register(self.challengeDelegate!)
			}

			var player = GameCenterPlayerLocal(GKLocalPlayer.local)
			onComplete.callDeferred(Variant(OK), Variant(player))
		}

		#elseif os(watchOS)

		GKLocalPlayer.local.authenticateHandler = { error in
			guard error == nil else {
				GD.pushError("Failed to authenticate \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToAuthenticate.rawValue), nil)
				return
			}

			if self.inviteDelegate != nil {
				GKLocalPlayer.local.register(self.inviteDelegate!)
			}

			if self.challengeDelegate != nil {
				GKLocalPlayer.local.register(self.challengeDelegate!)
			}

			var player = GameCenterPlayerLocal(GKLocalPlayer.local)
			onComplete.callDeferred(Variant(OK), Variant(player))
		}

		#elseif os(macOS)

		GKLocalPlayer.local.authenticateHandler = { loginController, error in
			guard loginController == nil else {
				// TODO: Figure out how to show login window on macOS
				return
			}

			guard error == nil else {
				GD.pushError("Failed to authenticate \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToAuthenticate.rawValue), nil)
				return
			}

			if self.inviteDelegate != nil {
				GKLocalPlayer.local.register(self.inviteDelegate!)
			}

			if self.challengeDelegate != nil {
				GKLocalPlayer.local.register(self.challengeDelegate!)
			}

			var player = GameCenterPlayerLocal(GKLocalPlayer.local)
			onComplete.callDeferred(Variant(OK), Variant(player))
		}

		#else
		GD.pushWarning("GameCenter not available on this platform")
		onComplete.call(Variant(GameCenterError.notAvailable.rawValue))
		#endif
	}

	/// A Boolean value that indicates whether a local player has signed in to Game Center.
	func isAuthenticated() -> Bool {
		#if os(iOS)
		return GKLocalPlayer.local.isAuthenticated
		#else
		return false
		#endif
	}

	/// Get the local player
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: ``GameCenterPlayerLocal``)
	func getLocalPlayer(onComplete: Callable) {
		guard GKLocalPlayer.local.isAuthenticated && self.player != nil else {
			onComplete.call(Variant(GameCenterError.notAuthenticated.rawValue), nil)
			return
		}

		onComplete.call(Variant(OK), Variant(self.player!))
	}

	/// Load the profile picture of the authenticated player.
	///
	/// - Parameters:
	/// 	- onComplete: Callback with parameter: (error: Variant, data: Variant) -> (error: Int, data: Image)
	func loadProfilePicture(onComplete: Callable) {
		Task {
			do {
				let image = try await GKLocalPlayer.local.loadImage(size: .small)
				onComplete.callDeferred(Variant(OK), Variant(image))
			} catch {
				GD.pushError("Failed to load profile picture. \(error)")
				onComplete.callDeferred(Variant(GameCenterError.failedToLoadPicture.rawValue), nil)
			}
		}
	}

	// MARK: UI Overlays

	/// Show GameCenter dashboard overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	func showOverlay(onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .dashboard), onClose: onClose)
		#endif
	}

	/// Show GameCenter player profile overlay.
	///
	/// - Parameters:
	/// 	- onClose: Called when the user closes the overlay.
	func showProfileOverlay(onClose: Callable) {
		#if canImport(UIKit)
		viewController.showUIController(GKGameCenterViewController(state: .localPlayerProfile), onClose: onClose)
		#endif
	}

	/// Show GameCenter access point.
	///
	/// - Parameters:
	/// 	- showHighlights: A Boolean value that indicates whether to display highlights for achievements and current ranks for leaderboards.
	func showAccessPoint(showHighlights: Bool) {
		GKAccessPoint.shared.location = .topTrailing
		GKAccessPoint.shared.showHighlights = showHighlights
		GKAccessPoint.shared.isActive = true
	}

	/// Hide GameCenter access point.
	func hideAccessPoint() {
		GKAccessPoint.shared.isActive = false
	}

	// MARK: > Godot callables
	// Because @Callable doesn't work in extensions

	// General

	@Callable
	func is_authenticated() -> Bool {
		return isAuthenticated()
	}

	@Callable
	func get_local_player(onComplete: Callable) {
		getLocalPlayer(onComplete: onComplete)
	}

	@Callable
	func load_profile_picture(onComplete: Callable) {
		loadProfilePicture(onComplete: onComplete)
	}

	@Callable
	func show_profile_overlay(onClose: Callable) {
		showProfileOverlay(onClose: onClose)
	}

	@Callable
	func show_access_point(showHighlights: Bool) {
		showAccessPoint(showHighlights: showHighlights)
	}

	@Callable
	func hide_access_point() {
		hideAccessPoint()
	}

	// MARK: Achievements

	@Callable
	func set_achievement_progress(achievementID: String, percentComplete: Float, onComplete: Callable) {
		setAchievementProgress(achievementID: achievementID, percentComplete: percentComplete, onComplete: onComplete)
	}

	@Callable
	func report_achievement_progress(onComplete: Callable) {
		reportAchievementProgress(onComplete: onComplete)
	}

	@Callable
	func get_achievement(achievementID: String, onComplete: Callable) {
		getAchievement(achievementID: achievementID, onComplete: onComplete)
	}

	@Callable
	func get_achievement_description(achievementID: String, onComplete: Callable) {
		getAchievementDescription(achievementID: achievementID, onComplete: onComplete)
	}

	@Callable
	func get_achievements(onComplete: Callable) {
		getAchievements(onComplete: onComplete)
	}

	@Callable
	func get_achievement_descriptions(onComplete: Callable) {
		getAchievementDescriptions(onComplete: onComplete)
	}

	@Callable
	func reset_achievements(onComplete: Callable) {
		resetAchievements(onComplete: onComplete)
	}

	@Callable
	func show_achievements_overlay(onClose: Callable) {
		showAchievementsOverlay(onClose: onClose)
	}

	@Callable
	func show_achievement_overlay(achievementdID: String, onClose: Callable) {
		showAchievementOverlay(achievementdID: achievementdID, onClose: onClose)
	}

	// MARK: Challenges

	@Callable
	func load_received_challenges(onComplete: Callable) {
		loadReceivedChallenges(onComplete: onComplete)
	}

	@Callable
	func load_challengable_players(onComplete: Callable) {
		loadChallengablePlayers(onComplete: onComplete)
	}

	@Callable
	func issue_score_challenge(leaderboardID: String, receivers: [String], message: String, onComplete: Callable) {
		issueScoreChallenge(
			leaderboardID: leaderboardID,
			receivers: receivers,
			message: message,
			onComplete: onComplete
		)
	}

	@Callable
	func decline_challenge(challengeID: Int, onComplete: Callable) {
		declineChallenge(challengeID: challengeID, onComplete: onComplete)
	}

	@Callable
	func show_challenges_overlay(onClose: Callable) {
		showChallengesOverlay(onClose: onClose)
	}

	// MARK: Friends

	@Callable
	func load_friends(includeImages: Bool, onComplete: Callable) {
		loadFriends(onComplete: onComplete, includeImages: includeImages)
	}

	@Callable
	func load_recent_players(includeImages: Bool, onComplete: Callable) {
		loadRecentPlayers(onComplete: onComplete, includeImages: includeImages)
	}

	@Callable
	func load_friend_picture(gamePlayerID: String, onComplete: Callable) {
		loadFriendPicture(gamePlayerID: gamePlayerID, onComplete: onComplete)
	}

	@Callable
	func can_access_friends(onComplete: Callable) {
		canAccessFriends(onComplete: onComplete)
	}

	@Callable
	func show_friends_overlay(onClose: Callable) {
		showFriendsOverlay(onClose: onClose)
	}

	@Callable
	func show_friend_request_creator() {
		showFriendRequestCreator()
	}

	// MARK: Leaderboards

	@Callable
	func submit_score(score: Int, leaderboardIDs: [String], onComplete: Callable) {
		submitScore(score, leaderboardIDs: leaderboardIDs, context: 0, onComplete: onComplete)
	}

	@Callable
	func submit_score_with_context(score: Int, leaderboardIDs: [String], context: Int, onComplete: Callable) {
		submitScore(score, leaderboardIDs: leaderboardIDs, context: context, onComplete: onComplete)
	}

	@Callable
	func get_global_scores(leaderboardID: String, start: Int, length: Int, onComplete: Callable) {
		getGlobalScores(leaderboardID: leaderboardID, start: start, length: length, onComplete: onComplete)
	}

	@Callable
	func get_friends_scores(leaderboardID: String, start: Int, length: Int, onComplete: Callable) {
		getFriendsScores(leaderboardID: leaderboardID, start: start, length: length, onComplete: onComplete)
	}

	@Callable
	func get_previous_occurance(leaderboardID: String, start: Int, length: Int, onComplete: Callable) {
		getPreviousOccurance(leaderboardID: leaderboardID, start: start, length: length, onComplete: onComplete)
	}

	@Callable
	func get_previous_friends_occurance(leaderboardID: String, start: Int, length: Int, onComplete: Callable) {
		getPreviousFriendsOccurance(leaderboardID: leaderboardID, start: start, length: length, onComplete: onComplete)
	}

	@Callable
	func get_local_player_entry(leaderboardID: String, onComplete: Callable) {
		getLocalPlayerEntry(loaderboardID: leaderboardID, onComplete: onComplete)
	}

	@Callable
	func get_previous_local_player_entry(leaderboardID: String, onComplete: Callable) {
		getPreviousLocalPlayerEntry(loaderboardID: leaderboardID, onComplete: onComplete)
	}

	@Callable
	func show_leaderboards_overlay(onClose: Callable) {
		showLeaderboardsOverlay(onClose: onClose)
	}

	@Callable
	func show_leaderboard_overlay(leaderboardID: String, onClose: Callable) {
		showLeaderboardOverlay(leaderboardID: leaderboardID, onClose: onClose)
	}

	// MARK: Invites

	@Callable
	func get_invite(withIndex index: Int, onComplete: Callable) {
		getInvite(withIndex: index, onComplete: onComplete)
	}

	@Callable
	func get_invites(onComplete: Callable) {
		getInvites(onComplete: onComplete)
	}

	@Callable
	func remove_invite(withIndex index: Int) -> Bool {
		removeInvite(withIndex: index)
	}
}
