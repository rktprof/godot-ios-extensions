Some swift based extensions for iOS/macOS functionality, built on [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot). 

Everything is provided as-is, I'm building new plugins as I need them

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