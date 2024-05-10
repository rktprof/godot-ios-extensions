#!/bin/zsh

# Very basic build script to help with buliding for iOS
# TODO:
# - Make it build for more platforms
# - Copy results to a folder  

# You probably need to put your iOS device ID here
# To get a list of available id's run:
# xcodebuild -scheme GameCenter -showdestinations
DEVICE_ID=""
#DEVICE_ID="dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder" # Use for "Any iOS Device" usually gives errors though

PROJECT=$1
CONFIG=$2
DESTINATION=$3

if [[ ! $DEVICE_ID && ! $DESTINATION ]];
then
	echo "No DEVICE_ID and no destination override specified"
	echo "Open build.sh and add your device id to DEVICE_ID"
	echo "Or run script with ./build.sh <project> <config> <destination>"
	echo "where <destination> is defined as: \"platform=iOS,arch=arm64,id=<your device id>\""
	exit 0
fi

# The project folder to build, like "GameCenter", "InAppPurchase", "Networking" etc
if [[ ! $PROJECT ]];
then
	echo "Please specify a folder to build"
	exit 0
fi

# Available configs: debug or release
if [[ ! $CONFIG ]];
then
	CONFIG="debug"
fi

# If you prefer to override the destination manually
if [[ ! $DESTINATION ]];
then
	DESTINATION="platform=iOS,arch=arm64,id=$DEVICE_ID"
fi

# Target output folder, similar to how "swift build" does it
TARGET="arm64-apple-ios/$CONFIG"

# If you want to target a different sdk you can see which are available using
# xcodebuild -scheme <project> -showsdks

echo "Building $PROJECT iOS library..."
xcodebuild \
	-workspace "$PROJECT/" \
	-scheme $PROJECT \
	-sdk iphoneos17.4 \
	-derivedDataPath "$PROJECT/.build/$TARGET" \
	-configuration $CONFIG \
	-destination $DESTINATION \
	-skipPackagePluginValidation -skipMacroValidation -quiet

echo "Finished building to target: .build/$TARGET"