#if canImport(CoreHaptics)

import CoreHaptics
import SwiftGodot

#initSwiftExtension(
	cdecl: "swift_entry_point",
	types: [
		Haptics.self
	]
)

let HAPTIC_STOP_REASON_SYSTEM_ERROR: Int = 1
let HAPTIC_STOP_REASON_IDLE_TIMEOUT: Int = 2
let HAPTIC_STOP_REASON_AUDIO_INTERRUPTED: Int = 3
let HAPTIC_STOP_REASON_APPLICATION_SUSPENDED: Int = 4
let HAPTIC_STOP_REASON_ENGINE_DESTROYED: Int = 5
let HAPTIC_STOP_REASON_GAME_CONTROLLER_DISCONNECTED: Int = 6
let HAPTIC_STOP_REASON_UNKNOWN_ERROR: Int = 7

@Godot
class Haptics: RefCounted {

	/// Called when the Haptic engine stops
	@Signal var engineStopped: SignalWithArguments<Int>

	var isHapticsSupported: Bool = false
	var engine: CHHapticEngine!

	required init() {
		super.init()
		initializeEngine()
	}

	required init(nativeHandle: UnsafeRawPointer) {
		super.init(nativeHandle: nativeHandle)
		initializeEngine()
	}

	func initializeEngine() {
		guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
			GD.pushError("Device does not support haptics")
			isHapticsSupported = false
			return
		}

		isHapticsSupported = true
		do {
			engine = try CHHapticEngine()
			engine.resetHandler = resetHandler
			engine.stoppedHandler = stoppedHandler
			try engine?.start()
		} catch {
			GD.pushError("Failed to initialize haptics: \(error)")
		}
	}

	// MARK: Godot functions

	@Callable(autoSnakeCase: true)
	func restartEngine() {
		do {
			try engine?.start()
		} catch {
			GD.pushError("Failed to restart haptics engine: \(error)")
		}
	}

	/// Play a single tap.
	///
	/// - Parameters:
	/// 	- sharpness: The feel of the haptic event.
	/// 	- intensity: The strength of the haptic event.
	@Callable(autoSnakeCase: true)
	func playTap(sharpness: Float, intensity: Float) {
		if !isHapticsSupported {
			return
		}

		do {
			let pattern = try CHHapticPattern(
				events: [
					CHHapticEvent(
						eventType: .hapticTransient,
						parameters: [
							CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
							CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
						],
						relativeTime: 0
					)
				],
				parameters: []
			)
			try playPattern(pattern: pattern)
		} catch {
			GD.pushError("Failed to play haptic: \(error)")
		}
	}

	/// Play a longer haptic event.
	///
	/// - Parameters:
	/// 	- sharpness: The feel of the haptic event.
	/// 	- intensity: The strength of the haptic event.
	/// 	- duration: The duration of the haptic event.
	@Callable(autoSnakeCase: true)
	func playEvent(sharpness: Float, intensity: Float, duration: Float) {
		if !isHapticsSupported {
			return
		}

		do {
			let pattern = try CHHapticPattern(
				events: [
					CHHapticEvent(
						eventType: .hapticContinuous,
						parameters: [
							CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
							CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
						],
						relativeTime: 0,
						duration: TimeInterval(duration)
					)
				],
				parameters: []
			)
			try playPattern(pattern: pattern)
		} catch {
			GD.pushError("Failed to play haptic: \(error)")
		}
	}

	/// - Returns: True if the device supports Haptics
	@Callable(autoSnakeCase: true)
	func supportsHaptics() -> Bool {
		CHHapticEngine.capabilitiesForHardware().supportsHaptics
	}

	// MARK: Internal

	func playPattern(pattern: CHHapticPattern) throws {
		try engine.makePlayer(with: pattern).start(atTime: 0)
	}

	func stoppedHandler(reason: CHHapticEngine.StoppedReason) {
		switch reason {
		case .audioSessionInterrupt:
			GD.print("Haptic engine stopped because the audio session was interrupted")
			self.engineStopped.emit(HAPTIC_STOP_REASON_AUDIO_INTERRUPTED)
		case .applicationSuspended:
			GD.print("Haptic engine stopped because the application was suspended")
			self.engineStopped.emit(HAPTIC_STOP_REASON_APPLICATION_SUSPENDED)
		case .idleTimeout:
			GD.print("Haptic engine stopped because idle timeout")
			self.engineStopped.emit(HAPTIC_STOP_REASON_IDLE_TIMEOUT)
		case .systemError:
			GD.print("Haptic engine stopped because of system error")
			self.engineStopped.emit(HAPTIC_STOP_REASON_SYSTEM_ERROR)
		case .engineDestroyed:
			GD.print("Haptic engine stopped because the engine was destroyed")
			self.engineStopped.emit(HAPTIC_STOP_REASON_ENGINE_DESTROYED)
		case .gameControllerDisconnect:
			GD.print("Haptic engine stopped because the game controller was disconnected")
			self.engineStopped.emit(HAPTIC_STOP_REASON_GAME_CONTROLLER_DISCONNECTED)
		default:
			GD.print("Haptic engine stopped because of unknown error: \(reason)")
			self.engineStopped.emit(HAPTIC_STOP_REASON_UNKNOWN_ERROR)
		}
	}

	func resetHandler() {
		GD.print("Restarting haptic engine")
		do {
			try engine.start()
		} catch {
			GD.pushError("Failed to restart haptic engine: \(error)")
		}
	}
}
#endif  // CoreHaptics
