import Foundation

public struct TournamentData: Codable {
    public var name: String
    public var players: [String]
    public var matches: [Match]
    public var scheduler: AmericanoScheduler
    public var playerStats: [String: PlayerStats]
    public var currentRound: Int
    
    public init(name: String, players: [String], numberOfRounds: Int, numberOfCourts: Int) {
        self.name = name
        self.players = players
        self.matches = []
        self.currentRound = 0
        self.playerStats = [:]
        
        // Initialize scheduler with a random seed
        let seed = UInt64.random(in: 0..<UInt64.max)
        self.scheduler = AmericanoScheduler(players: players, 
                                          numberOfRounds: numberOfRounds,
                                          numberOfCourts: numberOfCourts,
                                          seed: seed)
        
        // Initialize player stats
        for player in players {
            self.playerStats[player] = PlayerStats()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        players = try container.decode([String].self, forKey: .players)
        matches = try container.decode([Match].self, forKey: .matches)
        scheduler = try container.decode(AmericanoScheduler.self, forKey: .scheduler)
        playerStats = try container.decode([String: PlayerStats].self, forKey: .playerStats)
        currentRound = try container.decode(Int.self, forKey: .currentRound)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(players, forKey: .players)
        try container.encode(matches, forKey: .matches)
        try container.encode(scheduler, forKey: .scheduler)
        try container.encode(playerStats, forKey: .playerStats)
        try container.encode(currentRound, forKey: .currentRound)
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, players, matches, scheduler, playerStats, currentRound
    }
    
    public mutating func updateStats(with match: Match) {
        // Update player stats based on match results
        let allPlayers = [match.team1.player1, match.team1.player2,
                         match.team2.player1, match.team2.player2]
        
        for player in allPlayers {
            var stats = playerStats[player] ?? PlayerStats()
            stats.gamesPlayed += 1
            stats.lastPlayedRound = match.round
            
            // Update unique pairs
            if player == match.team1.player1 {
                stats.uniquePairs.insert(match.team1.player2)
            } else if player == match.team1.player2 {
                stats.uniquePairs.insert(match.team1.player1)
            } else if player == match.team2.player1 {
                stats.uniquePairs.insert(match.team2.player2)
            } else {
                stats.uniquePairs.insert(match.team2.player1)
            }
            
            playerStats[player] = stats
        }
    }
} 