Some swift based extensions for iOS/macOS functionality, built on [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot). 

Everything is provided as-is, I've tried to keep things simple and readable to make up for the (current) lack of documentation.

## Usage

The `build.sh` script will build everything for iOS and macOS in release configuration and copy the libraries to the /Bin/ folder, you can override this with some parameters
- `./build.sh ios/macos/all release/debug`

Then create your .gdextension file, it would look something like:
```
[configuration]
entry_symbol = "swift_entry_point"
compatibility_minimum = 4.2

[libraries]
macos.debug = "res://addons/macos/libGameCenter.dylib"
macos.release = "res://addons/macos/libGameCenter.dylib"
ios.debug = "res://addons/ios/GameCenter.framework"
ios.release = "res://addons/ios/GameCenter.framework"

[dependencies]
macos.debug = {"res://addons/macos/libSwiftGodot.dylib" : ""}
macos.release = {"res://addons/macos/libSwiftGodot.dylib" : ""}
ios.debug = {"res://addons/ios/SwiftGodot.framework" : ""}
ios.release = {"res://addons/ios/SwiftGodot.framework" : ""}
```

In order to use the plugin in your godot project you have to do some workarounds because of how GDScript works. For example: while you can create an instance of the GameCenter class directly you can't limit it to a specific platform. This means that if you publish on iOS and Android you need to build the GameCenter plugin for Android, which doesn't make sense. And if you develop on both macOS and Windows you have to build the plugins for Windows as well.

To get around this you have to use Variants like so:
```gdscript
var _game_center: Variant = null

func _init() -> void:
  if _game_center == null && ClassDB.class_exists("GameCenter"):
    _game_center = ClassDB.instantiate("GameCenter")
```
Which means you will not get any code completion or help at all.

This also means that you can only get Variants back from the plugin, which means you need to know what type is returned for any specific function, which you find in the swift classes themselves.

For example, in order to get GameCenter friends you do something like this
```gdscript
func get_friends(on_complete: Callable) -> void:
  _game_center.loadFriends(func(error: Variant, data: Variant) -> void:
    var friends: Array[Friend] = []
    if error != OK:
      on_complete.call(friends)
      return

    for entry: Variant in data:
      var friend: Friend = Friend.new()
      friend.alias = entry.alias
      friend.display_name = entry.displayName
      friend.game_player_id = entry.gamePlayerID
      friend.team_player_id = entry.teamPlayerID
      friend.is_invitable = entry.isInvitable
      friends.append(friend)

    on_complete.call(friends)
```

Fortunately, this pattern works for most of your interaction with the plugins.

**IMPORTANT NOTE:** Remember that you need to specify the correct number of arguments or Godot will just fail silently, this is why callbacks from swift has to look like this:
```swift
onComplete.callDeferred(Variant(LeaderboardError.failedToLoadEntries.rawValue), Variant(), Variant(), Variant(0))
```

## Currently supports:

**GameCenter**
- Authentication
- Leaderboards
  - Post score
  - Open overlay
  - Get leaderboard data
- Friends
  - Get list of friends
  - Open Friends overlay
  - Friend invites
- Achievements
  - Reward achievements
  - Open overlay
  - Get achievement data
- Matchmaking

**Bonjour**
- LAN discovery
  - Listener
  - Browser (find active listeners)
  - Endpoint resolution

**InAppPurchase**
- Get list of products
- Purchase product

**Device**
- Taptic Engine (Simple taps & extended vibrations)

## TODO: (assuming I can figure it out)

Basic plugin documentation (for now, feel free to create an issue with a question)

**GameCenter**
- Challenges
- macOS Support (should mostly work but opening overlays doesn't)

**Bonjour**
- Bluetooth discovery

**iCloud**
- Cloud saves

**Device**
- Gyroscope
- Taptic Engine (Play vibration from sound or external file)
