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

**Networking/Bonjour**
- LocalNetworkListener
  - Start a server listening for connections on the local network
- LocalNetworkDiscovery
  - Start a browser to find servers created by LocalNetworkListener
  - Resolve endpoint of discovered server

## Coming: (assuming I can figure it out)

**GameCenter**
- Matchmaking
- Friend Challenges

**InAppPurchases**
- Handle puprchases
- Handle refunds
