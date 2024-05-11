Some swift based extensions for iOS functionality, built on [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot).

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

**Bonjour (The Bonjour plugin should work on most platforms)**
- LocalNetworkListener
  - Start a server listening for connections on the local network
- LocalNetworkDiscovery
  - Start a browser to find servers created by LocalNetworkListener
  - Resolve endpoint of discovered server

**InAppPurchase**
- Get list of products
- Purchase product

## Coming: (assuming I can figure it out)

**GameCenter**
- Achievements
  - Reward achievements
  - Open overlay
  - Get achievement data
- Matchmaking