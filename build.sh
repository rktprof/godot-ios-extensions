#!/bin/zsh

# Basic build script to help with building extensions

PROJECT=$1
if [[ ! $PROJECT ]]; then
	echo 
	echo "Syntax: build <project> <platform?> <config?>"
	echo 
	echo "<project> is the project folder to build. eg GameCenter"
	echo "<platform> is the platform to build for"
	echo "	Options: ios, macos & all. (Default: all)"
	echo "<config> is the configuration to use"
	echo "	Options: debug & release. (Default: release)"
	exit 0
fi

TARGET=$2
if [[ ! $TARGET ]]; then
	TARGET="all"
fi

CONFIG=$3
if [[ ! $CONFIG ]]; then
	CONFIG="release"
fi

BUILD_PATH=".build"
CACHE_PATH=".cache"

build_ios() {
	echo "Building $1 iOS library..."

	if (( $+commands[xcbeautify] )); then
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=iOS' \
			-derivedDataPath "$BUILD_PATH" \
			-clonedSourcePackagesDirPath "$CACHE_PATH" \
			-configuration Release \
			-skipPackagePluginValidation | xcbeautify
	else
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=iOS' \
			-derivedDataPath "$BUILD_PATH" \
			-clonedSourcePackagesDirPath "$CACHE_PATH" \
			-configuration Release \
			-skipPackagePluginValidation -quiet
	fi

	echo "Copying iOS binaries"
	productpath="$BUILD_PATH/Build/Products/$2-iphoneos/PackageFrameworks"
	binarypath="bin/ios"
	
	if ! [[ -e "$binarypath" ]]; then
		mkdir -p "$binarypath"
	fi

	cp -af "$productpath/$1.framework" "$binarypath"
	if ! [[ -e "$binarypath/SwiftGodot.framework" ]]; then
		cp -af "$productpath/SwiftGodot.framework" "$binarypath"
	fi
	
	echo "Finished building $1"
}

build_macos() {
	echo "Building $1 macOS library..."

	if (( $+commands[xcbeautify] )); then
		swift build \
			--package-path $1 \
			--configuration $2 \
			--triple arm64-apple-macos \
			--scratch-path $BUILD_PATH \
			--cache-path $CACHE_PATH | xcbeautify
	else
		swift build \
			--package-path $1 \
			--configuration $2 \
			--triple arm64-apple-macos \
			--scratch-path $BUILD_PATH \
			--cache-path $CACHE_PATH
	fi

	echo "Copying macos binaries"
	productpath="$BUILD_PATH/arm64-apple-macos/$2"
	binarypath="bin/macos"

	if ! [[ -e "$binarypath" ]]; then
		mkdir -p "$binarypath"
	fi

	cp "$productpath/lib$1.dylib" "$binarypath"
	if ! [[ -e "$binarypath/libSwiftGodot.dylib" ]]; then
		cp -af "$productpath/libSwiftGodot.dylib" "$binarypath"
	fi

	echo "Finished building $1"
}

build_macos_xcode() {
	echo "Building $1 macOS library..."

	if (( $+commands[xcbeautify] )); then
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=macOS' \
			-derivedDataPath "$BUILD_PATH" \
			-clonedSourcePackagesDirPath "$CACHE_PATH" \
			-configuration Release \
			-skipPackagePluginValidation | xcbeautify
	else
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=macOS' \
			-derivedDataPath "$BUILD_PATH" \
			-clonedSourcePackagesDirPath "$CACHE_PATH" \
			-configuration Release \
			-skipPackagePluginValidation -quiet
	fi

	echo "Copying binaries"
	productpath="$BUILD_PATH/Build/Products/Release/PackageFrameworks"
	binarypath="bin/macos"
	
	if ! [[ -e "$binarypath" ]]; then
		mkdir -p "$binarypath"
	fi

	cp -af "$productpath/$1.framework/Versions/Current/$1" "$binarypath"
	if ! [[ -e "$binarypath/SwiftGodot.framework" ]]; then
		cp -af "$productpath/SwiftGodot.framework" "$binarypath"
	fi

	echo "Finished building $1"
}

build_libs() {
	echo "$(tput bold)Building $1 $3 libraries for $2 platforms$(tput sgr0)"
	if [[ $2 == "all" || $2 == "macos" ]]; then
		build_macos "$1" "$3"
	fi

	if [[ $2 == "all" || $2 == "ios" ]]; then
		build_ios "$1" "$3"
	fi
}

build_libs "$PROJECT" $TARGET $CONFIG
