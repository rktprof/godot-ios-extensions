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

	#signal("engine_stopped", arguments: ["reason": Int.self])

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

	@Callable
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

	@Callable
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


	@Callable
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
			emit(signal: Haptics.engineStopped, Int(HAPTIC_STOP_REASON_AUDIO_INTERRUPTED))
		case .applicationSuspended:
			GD.print("Haptic engine stopped because the application was suspended")
			emit(signal: Haptics.engineStopped, Int(HAPTIC_STOP_REASON_APPLICATION_SUSPENDED))
		case .idleTimeout:
			GD.print("Haptic engine stopped because idle timeout")
			emit(signal: Haptics.engineStopped, Int(HAPTIC_STOP_REASON_IDLE_TIMEOUT))
		case .systemError:
			GD.print("Haptic engine stopped because of system error")
			emit(signal: Haptics.engineStopped, Int(HAPTIC_STOP_REASON_SYSTEM_ERROR))
		case .engineDestroyed:
			GD.print("Haptic engine stopped because the engine was destroyed")
			emit(signal: Haptics.engineStopped, Int(HAPTIC_STOP_REASON_ENGINE_DESTROYED))
		case .gameControllerDisconnect:
			GD.print("Haptic engine stopped because the game controller was disconnected")
			emit(
				signal: Haptics.engineStopped,
				Int(HAPTIC_STOP_REASON_GAME_CONTROLLER_DISCONNECTED)
			)
		default:
			GD.print("Haptic engine stopped because of unknown error: \(reason)")
			emit(signal: Haptics.engineStopped, Int(HAPTIC_STOP_REASON_UNKNOWN_ERROR))
		}
	}

	func resetHandler() {
		GD.print("Restarting haptic engine")
		do {
			try self.engine.start()
		} catch {
			GD.pushError("Failed to restart haptic engine: \(error)")
		}
	}
}
#endif // CoreHaptics