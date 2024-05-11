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
CACHE_PATH=".build"

build_ios() {
	echo "Building iOS library..."

	build_path="$1/.build/arm64-apple-ios"
	cache_path="$1/.build"

	# If you encounter build issues, try adding -skipMacroValidation
	if (( $+commands[xcbeautify] )); then
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=iOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration $2 \
			-skipPackagePluginValidation -quiet | xcbeautify
	else
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=iOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration $2 \
			-skipPackagePluginValidation -quiet
	fi

	echo "Copying iOS binaries"
	product_path="$build_path/Build/Products/$2-iphoneos/PackageFrameworks"
	binary_path="bin/ios"
	
	if ! [[ -e "$binary_path" ]]; then
		mkdir -p "$binary_path"
	fi

	cp -af "$product_path/$1.framework" "$binary_path"
	if ! [[ -e "$binary_path/SwiftGodot.framework" ]]; then
		cp -af "$product_path/SwiftGodot.framework" "$binary_path"
	fi
	
	echo "Finished building iOS library"
}

build_macos() {
	echo "Building macOS library..."

	build_path="$1/.build"
	cache_path="$1/.build"

	if (( $+commands[xcbeautify] )); then
		swift build \
			--package-path $1 \
			--configuration $2 \
			--triple arm64-apple-macosx \
			--scratch-path "$build_path" \
			--cache-path "$cache_path" | xcbeautify
	else
		swift build \
			--package-path $1 \
			--configuration $2 \
			--triple arm64-apple-macosx \
			--scratch-path "$build_path" \
			--cache-path "$cache_path"
	fi

	echo "Copying macos binaries"
	product_path="$build_path/arm64-apple-macosx/$2"
	binary_path="bin/macos"

	if ! [[ -e "$binary_path" ]]; then
		mkdir -p "$binary_path"
	fi

	cp "$product_path/lib$1.dylib" "$binary_path"
	if ! [[ -e "$binary_path/libSwiftGodot.dylib" ]]; then
		cp -af "$product_path/libSwiftGodot.dylib" "$binary_path"
	fi

	echo "Finished building macOS library"
}

# Not sure if this works, create a .framework file but godot seems to complain
build_macos_xcode() {
	echo "Building macOS library..."

	build_path="$1/.build/arm64-apple-macosx"
	cache_path="$1/.build"
	
	if (( $+commands[xcbeautify] )); then
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=macOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration $2 \
			-skipPackagePluginValidation | xcbeautify
	else
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=macOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration $2 \
			-skipPackagePluginValidation -quiet
	fi

	echo "Copying binaries"
	product_path="$build_path/Build/Products/Release/PackageFrameworks"
	binary_path="bin/macos"
	
	if ! [[ -e "$binary_path" ]]; then
		mkdir -p "$binary_path"
	fi

	cp -af "$product_path/$1.framework/Versions/Current/$1" "$binary_path"
	if ! [[ -e "$binary_path/SwiftGodot.framework" ]]; then
		cp -af "$product_path/SwiftGodot.framework" "$binary_path"
	fi

	echo "Finished building macOS library"
}

build_libs() {
	echo "$(tput bold)Building $1 $3 libraries for $2 platforms$(tput sgr0)"
	if [[ $2 == "all" || $2 == "macos" ]]; then
		build_macos "$1" "$3"
	fi

	if [[ $2 == "all" || $2 == "ios" ]]; then
		build_ios "$1" "$3"
	fi
	echo "$(tput bold)Finished building $1 $3 libraries for $2 platforms$(tput sgr0)"
}

build_libs "$PROJECT" "$TARGET" "$CONFIG"
