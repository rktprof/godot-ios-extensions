#!/bin/zsh

# MARK: Help

# Syntax: ./build.sh [-f] <platform?> <config?>"
# Valid platforms are: mac, ios & all (Default: all)
# Valid configurations are: debug & release (Default: release)

# MARK: Settings

BINARY_PATH_IOS="Bin/ios"
BUILD_PATH_IOS=".build/arm64-apple-ios"

BINARY_PATH_MACOS="Bin/macos"
BUILD_PATH_MACOS=".build"

# MARK: Inputs

TARGET=$1
CONFIG=$2

if [[ ! $TARGET ]]; then
	TARGET="all"
fi

if [[ ! $CONFIG ]]; then
	CONFIG="release"
fi

COPY_COMMANDS=()

# MARK: Build iOS

build_ios() {
	xcodebuild \
		-scheme "iOS Plugins-Package"  \
		-destination 'generic/platform=iOS' \
		-derivedDataPath "$BUILD_PATH_IOS" \
		-clonedSourcePackagesDirPath ".build" \
		-configuration "$1" \
		-skipPackagePluginValidation \
		-quiet

	if [[ $? -gt 0 ]]; then
		echo "${BOLD}${RED}Failed to build $target iOS library${RESET_FORMATTING}"
		return 1
	fi

	echo "${BOLD}${GREEN}iOS build succeeded${RESET_FORMATTING}"

	product_path="$BUILD_PATH_IOS/Build/Products/$1-iphoneos/PackageFrameworks"
	source_path="Sources"
	for folder in $source_path/*; do
		COPY_COMMANDS+=("cp -af ""$product_path/$folder:t:r.framework ""$BINARY_PATH_IOS")
	done
	
	COPY_COMMANDS+=("cp -af ""$product_path/SwiftGodot.framework ""$BINARY_PATH_IOS")

	return 0
}

# MARK: Build macOS

build_macos() {
	swift build \
		--configuration "$1" \
		--scratch-path "$BUILD_PATH_MACOS" \
		--quiet

	if [[ $? -gt 0 ]]; then
		echo "${BOLD}${RED}Failed to build macOS library${RESET_FORMATTING}"
		return 1
	fi

	echo "${BOLD}${GREEN}macOS build succeeded${RESET_FORMATTING}"

	product_path="$BUILD_PATH_MACOS/arm64-apple-macosx/$1"
	source_path="Sources"
	for folder in $source_path/*
	do
		COPY_COMMANDS+=("cp -af $product_path/lib$folder:t:r.dylib $BINARY_PATH_MACOS")
	done

	COPY_COMMANDS+=("cp -af $product_path/libSwiftGodot.dylib $BINARY_PATH_MACOS")

	return 0
}

# MARK: Pre & Post process

build_libs() {
	echo "Building libraries..."

	if [[ "$1" == "all" || "$1" == "macos" ]]; then
		echo "${BOLD}${CYAN}Building macOS library ($2)...${RESET_FORMATTING}"
		build_macos "$2"
	fi

	if [[ "$1" == "all" || "$1" == "ios" ]]; then
		echo "${BOLD}${CYAN}Building iOS libraries ($2)...${RESET_FORMATTING}"
		build_ios "$2"
	fi

	if [[ ${#COPY_COMMANDS[@]} -gt 0 ]]; then
		echo "${BOLD}${CYAN}Copying binaries...${RESET_FORMATTING}"
		for instruction in ${COPY_COMMANDS[@]}
		do
			target=${instruction##* }
			if ! [[ -e "$target" ]]; then
				mkdir -p "$target"
			fi
			eval $instruction
		done
	fi

	echo "${BOLD}${GREEN}Finished building $2 libraries for $1 platforms${RESET_FORMATTING}"
}

await() {
	local pid=$1
	local values="-\|/"
	local i=0

	while kill -0 $pid 2>/dev/null
	do
		local i=$(i + 1)
		printf "%s" "$values:$i"
		echo -en "\r"
		sleep .1
	done

	wait $pid
	return $?
}

# MARK: Formatting
BOLD="$(tput bold)"
GREEN="$(tput setaf 2)"
CYAN="$(tput setaf 6)"
RED="$(tput setaf 1)"
RESET_FORMATTING="$(tput sgr0)"

# MARK: Run
#await sleep 1
build_libs "$TARGET" "$CONFIG"
