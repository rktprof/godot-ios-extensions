#!/bin/zsh

# Basic build script to help with building extensions

SWIFT_PATH="swift"
#SWIFT_PATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"

TRIPLE_IOS="arm64-apple-ios"
TRIPLE_MACOS="arm64-apple-macosx"

BOLD="$(tput bold)"
GREEN="$(tput setaf 2)"
CYAN="$(tput setaf 6)"
RED="$(tput setaf 1)"
RESET_FORMATTING="$(tput sgr0)"
FORCE_COPY_LIB=false

# Very ugly solution, should look into handling flags properly
if [[ $1 == "-f" ]]; then
	FORCE_COPY_LIB=true
	PROJECT=$2
	TARGET=$3
	CONFIG=$4
else
	PROJECT=$1
	TARGET=$2
	CONFIG=$3
fi


if [[ ! $PROJECT ]]; then
	echo
	echo "Syntax: build [-f] <project> <platform?> <config?>"
	echo
	echo "-f force copy SwiftGodot library even if it exists"
	echo "	Useful if you have updated the SwiftGodot version"
	echo "<project> is the project folder to build. eg GameCenter"
	echo "<platform> is the platform to build for"
	echo "	Options: ios, macos & all. (Default: all)"
	echo "<config> is the configuration to use"
	echo "	Options: debug & release. (Default: release)"
	exit 0
fi

if [[ ! $TARGET ]]; then
	TARGET="all"
fi

if [[ ! $CONFIG ]]; then
	CONFIG="release"
fi

COPY_COMMANDS=()

build_ios() {
	echo "${BOLD}${CYAN}Building $1 iOS library...${RESET_FORMATTING}"

	build_path="$1/.build/$TRIPLE_IOS"
	cache_path="$1/.build"

	# If you encounter build issues, try adding -skipMacroValidation
	if (( $+commands[xcbeautify] )); then
		set -o pipefail && xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=iOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration "$2" \
			-skipPackagePluginValidation | xcbeautify
	else
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=iOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration "$2" \
			-skipPackagePluginValidation -quiet

		if [[ $? -eq 0 ]]; then
			echo "${BOLD}${GREEN}Build Succeeded${RESET_FORMATTING}"
		fi
	fi

	if [[ $? -gt 0 ]]; then
		echo "${BOLD}${RED}Building $1 for iOS failed${RESET_FORMATTING}"
		return 1
	fi

	product_path="$build_path/Build/Products/$2-iphoneos/PackageFrameworks"
	binary_path="bin/ios"

	COPY_COMMANDS+=("cp -af ""$product_path/$1.framework ""$binary_path")
	if [[ ! -e "$binary_path/SwiftGodot.framework" || $FORCE_COPY_LIB == true ]]; then
		COPY_COMMANDS+=("cp -af ""$product_path/SwiftGodot.framework ""$binary_path")
	fi

	return 0
}

# Not sure if this works, creates a .framework file but godot seems to complain
build_macos_xcode() {
	echo "${BOLD}${CYAN}Building $1 macOS library...${RESET_FORMATTING}"

	build_path="$1/.build/$TRIPLE_MACOS"
	cache_path="$1/.build"

	if (( $+commands[xcbeautify] )); then
		set -o pipefail && xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=macOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration "$2" \
			-skipPackagePluginValidation | xcbeautify
	else
		xcodebuild \
			-workspace "$1/" \
			-scheme "$1" \
			-destination 'generic/platform=macOS' \
			-derivedDataPath "$build_path" \
			-clonedSourcePackagesDirPath "$cache_path" \
			-configuration "$2" \
			-skipPackagePluginValidation -quiet

		if [[ $? -eq 0 ]]; then
			echo "${BOLD}${GREEN}Build Succeeded${RESET_FORMATTING}"
		fi
	fi

	if [[ $? -gt 0 ]]; then
		echo "${BOLD}${RED}Building $1 for macOS failed${RESET_FORMATTING}"
		return 1
	fi

	product_path="$build_path/Build/Products/$2/PackageFrameworks"
	binary_path="bin/macos"

	COPY_COMMANDS+=("cp -af $product_path/$1.framework $binary_path")
	if [[ ! -e "$binary_path/SwiftGodot.framework" || $FORCE_COPY_LIB == true ]]; then
		COPY_COMMANDS+=("cp -af $product_path/SwiftGodot.framework $binary_path")
	fi

	return 0
}

build_macos() {
	echo "${BOLD}${CYAN}Building $1 macOS library...${RESET_FORMATTING}"

	build_path="$1/.build"
	cache_path="$1/.build"

	if (( $+commands[xcbeautify] )); then
		set -o pipefail && ${SWIFT_PATH} build \
			--package-path "$1" \
			--configuration "$2" \
			--triple "$TRIPLE_MACOS" \
			--scratch-path "$build_path" \
			--cache-path "$cache_path" #| xcbeautify
	else
		${SWIFT_PATH} build \
			--package-path "$1" \
			--configuration "$2" \
			--triple "$TRIPLE_MACOS" \
			--scratch-path "$build_path" \
			--cache-path "$cache_path"
	fi

	if [[ $? -gt 0 ]]; then
		echo "${BOLD}${RED}Building $1 for macOS failed${RESET_FORMATTING}"
		return 1
	fi

	echo "${BOLD}${GREEN}Build Succeeded${RESET_FORMATTING}"

	product_path="$build_path/$TRIPLE_MACOS/$2"
	binary_path="bin/macos"

	COPY_COMMANDS+=("cp -af $product_path/lib$1.dylib $binary_path")
	if [[ ! -e "$binary_path/libSwiftGodot.dylib" || $FORCE_COPY_LIB == true ]]; then
		COPY_COMMANDS+=("cp -af $product_path/libSwiftGodot.dylib $binary_path")
	fi

	return 0
}

build_libs() {
	echo "Building $1 $3 libraries for $2 platforms"

	if [[ "$2" == "all" || "$2" == "macos" ]]; then
		build_macos "$1" "$3"
	fi

	if [[ "$2" == "all" || "$2" == "ios" ]]; then
		build_ios "$1" "$3"
	fi

	if [[ ${#COPY_COMMANDS[@]} -gt 0 ]]; then
		echo "${BOLD}${CYAN}Copying binaries...${RESET_FORMATTING}"
		for instruction in ${COPY_COMMANDS[@]}
		do
			# This is not ideal as it won't handle spaces in paths
			# However, there shouldn't be any since the path is relative
			target=${instruction##* }
			if ! [[ -e "$target" ]]; then
				mkdir -p "$target"
			fi
			eval $instruction
		done
	fi

	echo "${BOLD}${GREEN}Finished building $1 $3 libraries for $2 platforms${RESET_FORMATTING}"
}

build_libs "$PROJECT" "$TARGET" "$CONFIG"
