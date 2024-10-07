// swift-tools-version: 5.10

import PackageDescription

var swiftSettings: [SwiftSetting] = [
	.unsafeFlags(["-suppress-warnings"])
]

let package = Package(
	name: "iOS Plugins",
	platforms: [
		.iOS(.v15),
		.macOS(.v13),
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
			name: "Utils",
			type: .dynamic,
			targets: ["Utils"]
		),
	],

	// MARK: Dependencies
	dependencies: [
		//.package(url: "https://github.com/migueldeicaza/SwiftGodot.git", from: "0.45.0")
		//.package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
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
			name: "Utils",
			dependencies: ["SwiftGodot"],
			swiftSettings: swiftSettings
		),
	]
)
