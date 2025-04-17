// swift-tools-version: 6.0

import PackageDescription

var swiftSettings: [SwiftSetting] = [
	.unsafeFlags(["-suppress-warnings"]),
	.swiftLanguageMode(.v5),
]

let package = Package(
	name: "iOS Plugins",
	platforms: [
		.iOS(.v17),
		.macOS(.v14),
	],

	// MARK: Products
	products: [
		.library(
			name: "Bonjour",
			type: .dynamic,
			targets: ["Bonjour"]
		),
		.library(
			name: "GameCenter",
			type: .dynamic,
			targets: ["GameCenter"]
		),
		.library(
			name: "Haptics",
			type: .dynamic,
			targets: ["Haptics"]
		),
		.library(
			name: "InAppPurchase",
			type: .dynamic,
			targets: ["InAppPurchase"]
		),
		.library(
			name: "Settings",
			type: .dynamic,
			targets: ["Settings"]
		),
	],

	// MARK: Dependencies
	dependencies: [
		.package(name: "SwiftGodot", path: "SwiftGodot")
	],

	// MARK: Targets
	targets: [
		.target(
			name: "Bonjour",
			dependencies: ["SwiftGodot"],
			swiftSettings: swiftSettings
		),
		.target(
			name: "GameCenter",
			dependencies: ["SwiftGodot"],
			swiftSettings: swiftSettings
		),
		.target(
			name: "Haptics",
			dependencies: ["SwiftGodot"],
			swiftSettings: swiftSettings
		),
		.target(
			name: "InAppPurchase",
			dependencies: ["SwiftGodot"],
			swiftSettings: swiftSettings
		),
		.target(
			name: "Settings",
			dependencies: ["SwiftGodot"],
			swiftSettings: swiftSettings
		),
	]
)
