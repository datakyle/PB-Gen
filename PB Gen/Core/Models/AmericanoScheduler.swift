import Foundation

public struct PlayerPair: Codable, Hashable {
    public let player1: String
    public let player2: String
    
    public init(player1: String, player2: String) {
        if player1 < player2 {
            self.player1 = player1
            self.player2 = player2
        } else {
            self.player1 = player2
            self.player2 = player1
        }
    }
}

// Custom key type for dictionary encoding
public struct StringKey: CodingKey {
    public let stringValue: String
    public let intValue: Int?
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

public struct AmericanoScheduler: Codable {
    public let players: [String]
    public var numberOfRounds: Int
    public let numberOfCourts: Int
    public let seed: UInt64
    private var rng: SeededRandomNumberGenerator
    private var playerStats: [String: PlayerStats]
    private var usedPairs: Set<PlayerPair>
    private var pairUsageCount: [PlayerPair: Int]
    private var lastRestRound: [String: Int]
    private var restingPlayersByRound: [Int: [String]]
    private let totalPossiblePairs: Int
    private var allowRepeats: Bool
    
    public init(players: [String], numberOfRounds: Int, numberOfCourts: Int, seed: UInt64) {
        // Filter out empty strings and duplicates
        self.players = Array(Set(players.filter { !$0.isEmpty }))
        self.numberOfRounds = numberOfRounds
        self.numberOfCourts = numberOfCourts
        self.seed = seed
        self.rng = SeededRandomNumberGenerator(seed: seed)
        
        // Initialize with empty dictionaries and arrays
        self.playerStats = [:]
        self.usedPairs = []
        self.pairUsageCount = [:]
        self.lastRestRound = [:]
        self.restingPlayersByRound = [:]
        self.totalPossiblePairs = (self.players.count * (self.players.count - 1)) / 2
        self.allowRepeats = false
        
        // Initialize lastRestRound and playerStats safely
        for player in self.players {
            self.lastRestRound[player] = -1
            self.playerStats[player] = PlayerStats()
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case players, numberOfRounds, numberOfCourts, seed
        case playerStats, usedPairs, pairUsageCount
        case lastRestRound, restingPlayersByRound, totalPossiblePairs
        case allowRepeats
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        players = try container.decode([String].self, forKey: .players)
        numberOfRounds = try container.decode(Int.self, forKey: .numberOfRounds)
        numberOfCourts = try container.decode(Int.self, forKey: .numberOfCourts)
        seed = try container.decode(UInt64.self, forKey: .seed)
        
        // Decode dictionaries with custom key types
        let playerStatsContainer = try container.nestedContainer(keyedBy: StringKey.self, forKey: .playerStats)
        var playerStats: [String: PlayerStats] = [:]
        for key in playerStatsContainer.allKeys {
            playerStats[key.stringValue] = try playerStatsContainer.decode(PlayerStats.self, forKey: key)
        }
        self.playerStats = playerStats
        
        usedPairs = try container.decode(Set<PlayerPair>.self, forKey: .usedPairs)
        
        // Decode pairUsageCount
        let pairUsageContainer = try container.nestedContainer(keyedBy: StringKey.self, forKey: .pairUsageCount)
        var pairUsageCount: [PlayerPair: Int] = [:]
        for key in pairUsageContainer.allKeys {
            let components = key.stringValue.split(separator: "|")
            if components.count == 2 {
                let pair = PlayerPair(player1: String(components[0]), player2: String(components[1]))
                pairUsageCount[pair] = try pairUsageContainer.decode(Int.self, forKey: key)
            }
        }
        self.pairUsageCount = pairUsageCount
        
        // Decode lastRestRound
        let lastRestContainer = try container.nestedContainer(keyedBy: StringKey.self, forKey: .lastRestRound)
        var lastRestRound: [String: Int] = [:]
        for key in lastRestContainer.allKeys {
            lastRestRound[key.stringValue] = try lastRestContainer.decode(Int.self, forKey: key)
        }
        self.lastRestRound = lastRestRound
        
        // Decode restingPlayersByRound
        let restingContainer = try container.nestedContainer(keyedBy: StringKey.self, forKey: .restingPlayersByRound)
        var restingPlayersByRound: [Int: [String]] = [:]
        for key in restingContainer.allKeys {
            if let roundNumber = Int(key.stringValue) {
                restingPlayersByRound[roundNumber] = try restingContainer.decode([String].self, forKey: key)
            }
        }
        self.restingPlayersByRound = restingPlayersByRound
        
        totalPossiblePairs = try container.decode(Int.self, forKey: .totalPossiblePairs)
        
        // Decode allowRepeats
        allowRepeats = try container.decode(Bool.self, forKey: .allowRepeats)
        
        // Initialize RNG with seed
        rng = SeededRandomNumberGenerator(seed: seed)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(players, forKey: .players)
        try container.encode(numberOfRounds, forKey: .numberOfRounds)
        try container.encode(numberOfCourts, forKey: .numberOfCourts)
        try container.encode(seed, forKey: .seed)
        try container.encode(totalPossiblePairs, forKey: .totalPossiblePairs)
        
        // Encode playerStats
        var playerStatsContainer = container.nestedContainer(keyedBy: StringKey.self, forKey: .playerStats)
        for (player, stats) in playerStats {
            try playerStatsContainer.encode(stats, forKey: StringKey(stringValue: player)!)
        }
        
        try container.encode(usedPairs, forKey: .usedPairs)
        
        // Encode pairUsageCount
        var pairUsageContainer = container.nestedContainer(keyedBy: StringKey.self, forKey: .pairUsageCount)
        for (pair, count) in pairUsageCount {
            let key = "\(pair.player1)|\(pair.player2)"
            try pairUsageContainer.encode(count, forKey: StringKey(stringValue: key)!)
        }
        
        // Encode lastRestRound
        var lastRestContainer = container.nestedContainer(keyedBy: StringKey.self, forKey: .lastRestRound)
        for (player, round) in lastRestRound {
            try lastRestContainer.encode(round, forKey: StringKey(stringValue: player)!)
        }
        
        // Encode restingPlayersByRound
        var restingContainer = container.nestedContainer(keyedBy: StringKey.self, forKey: .restingPlayersByRound)
        for (round, players) in restingPlayersByRound {
            try restingContainer.encode(players, forKey: StringKey(stringValue: String(round))!)
        }
        
        // Encode allowRepeats
        try container.encode(allowRepeats, forKey: .allowRepeats)
    }
    
    private func calculatePlayDeficitScore(player: String, currentRound: Int) -> Double {
        guard let stats = playerStats[player] else { return 0.0 }
        let roundCount = max(currentRound + 1, 1)
        
        let gamesPlayedScore = Double(stats.gamesPlayed) / Double(roundCount)
        let uniquePairsScore = Double(stats.uniquePairs.count) / Double(max(players.count - 1, 1))
        let roundsSinceLastPlayed = Double(currentRound - stats.lastPlayedRound)
        
        return (0.4 * (1.0 - gamesPlayedScore)) +
               (0.4 * (1.0 - uniquePairsScore)) +
               (0.2 * roundsSinceLastPlayed)
    }
    
    private func findCompatiblePartner(for player: String, from availablePlayers: [String], currentRound: Int) -> String? {
        let candidates = availablePlayers.filter { candidate in
            candidate != player &&
            !(playerStats[player]?.uniquePairs.contains(candidate) ?? false)
    }
    
        return candidates.max(by: { a, b in
            calculatePlayDeficitScore(player: a, currentRound: currentRound) <
            calculatePlayDeficitScore(player: b, currentRound: currentRound)
        })
    }
    
    private mutating func updatePlayerStats(team1: Team, team2: Team, round: Int) {
        let allPlayers = [team1.player1, team1.player2, team2.player1, team2.player2]
        
        for player in allPlayers {
            var stats = playerStats[player] ?? PlayerStats()
            stats.gamesPlayed += 1
            stats.lastPlayedRound = round
            
            // Update unique pairs
            if player == team1.player1 {
                stats.uniquePairs.insert(team1.player2)
            } else if player == team1.player2 {
                stats.uniquePairs.insert(team1.player1)
            } else if player == team2.player1 {
                stats.uniquePairs.insert(team2.player2)
            } else {
                stats.uniquePairs.insert(team2.player1)
            }
            
            playerStats[player] = stats
        }
    }
    
    private func validateRoundBalance() -> Bool {
        let counts = playerStats.values.map { $0.gamesPlayed }
        guard !counts.isEmpty else { return true }
        let maxDiff = counts.max()! - counts.min()!
        return maxDiff <= 1
    }
    
    public mutating func generateSchedule() -> ([Match], [Int: [String]])? {
        print("Starting schedule generation with \(players.count) players for \(numberOfRounds) rounds")
        
        guard players.count >= 4 else {
            print("Error: Need at least 4 players")
            return nil
        }
        
        guard numberOfCourts >= 1 else {
            print("Error: Need at least 1 court")
            return nil
        }
        
        var schedule: [Match] = []
        restingPlayersByRound = [:]
        usedPairs = []
        pairUsageCount = [:]
        allowRepeats = false
        
        // Reset player stats
        for player in players {
            playerStats[player] = PlayerStats()
        }
        
        for round in 0..<numberOfRounds {
            print("Generating round \(round + 1)")
            
            // Check if we need to allow repeats
            if !allowRepeats && usedPairs.count >= totalPossiblePairs {
                print("All unique pairs exhausted after round \(round). Switching to repeat mode.")
                allowRepeats = true
            }
            
            let (roundMatches, restingPlayers) = generateRound(round: round)
            
            if roundMatches.isEmpty {
                print("Error: Could not generate matches for round \(round + 1)")
                if round == 0 {
                    return nil // Only fail completely if we can't generate the first round
                }
                // For subsequent rounds, return what we have so far
                return (schedule, restingPlayersByRound)
            }
            
            if !validateRoundBalance() {
                print("Warning: Round \(round + 1) has unbalanced play time")
            }
            
            schedule.append(contentsOf: roundMatches)
            restingPlayersByRound[round] = restingPlayers
        }
        
        return (schedule, restingPlayersByRound)
    }
    
    private mutating func generateRound(round: Int) -> ([Match], [String]) {
        // Sort players by play deficit score
        var availablePlayers = players.sorted { p1, p2 in
            calculatePlayDeficitScore(player: p1, currentRound: round) >
            calculatePlayDeficitScore(player: p2, currentRound: round)
        }
        
        // Calculate how many players can play this round
        let maxMatches = min(numberOfCourts, availablePlayers.count / 4)
        let maxPlayersThisRound = maxMatches * 4
        let playersToRest = availablePlayers.count - maxPlayersThisRound
        
        // Select players to rest
        var restingPlayers: [String] = []
        if playersToRest > 0 {
            let restCandidates = availablePlayers.sorted { p1, p2 in
                let p1LastRest = lastRestRound[p1] ?? -1
                let p2LastRest = lastRestRound[p2] ?? -1
                if p1LastRest != p2LastRest {
                    return p1LastRest < p2LastRest
                }
                return (playerStats[p1]?.gamesPlayed ?? 0) > (playerStats[p2]?.gamesPlayed ?? 0)
            }
            restingPlayers = Array(restCandidates.prefix(playersToRest))
            availablePlayers.removeAll { restingPlayers.contains($0) }
            
            for player in restingPlayers {
                lastRestRound[player] = round
            }
        }
        
        // Try to generate matches with backtracking
        if let matches = generateMatchesWithBacktracking(availablePlayers: availablePlayers, round: round, courtNumber: 1, existingSchedule: []) {
            // Update player stats and pair usage for successful matches
            for match in matches {
                updatePlayerStats(team1: match.team1, team2: match.team2, round: round)
                updatePairUsage(team1: match.team1, team2: match.team2, round: round)
            }
            return (matches, restingPlayers)
        }
        
        return ([], restingPlayers)
    }
    
    private mutating func updatePairUsage(team1: Team, team2: Team, round: Int) {
        let pair1 = PlayerPair(player1: team1.player1, player2: team1.player2)
        let pair2 = PlayerPair(player1: team2.player1, player2: team2.player2)
        
        // Track teammate pairs
        usedPairs.insert(pair1)
        usedPairs.insert(pair2)
        
        // Update usage counts
        pairUsageCount[pair1, default: 0] += 1
        pairUsageCount[pair2, default: 0] += 1
        
        // Track opponent pairs for usage stats
        let oppPairs = [
            PlayerPair(player1: team1.player1, player2: team2.player1),
            PlayerPair(player1: team1.player1, player2: team2.player2),
            PlayerPair(player1: team1.player2, player2: team2.player1),
            PlayerPair(player1: team1.player2, player2: team2.player2)
        ]
        
        for pair in oppPairs {
            pairUsageCount[pair, default: 0] += 1
        }
    }
    
    private mutating func generateMatchesWithBacktracking(availablePlayers: [String], round: Int, courtNumber: Int, existingSchedule: [Match]) -> [Match]? {
        var matches: [Match] = []
        var remainingPlayers = availablePlayers
        
        // Base case: all players have been assigned
        if remainingPlayers.isEmpty {
            return matches
        }
        
        // Not enough players for a match
        if remainingPlayers.count < 4 {
            return nil
        }
        
        let player1 = remainingPlayers.removeFirst()
        
        // Get previous round matches to avoid immediate repeats
        let previousRoundMatches = existingSchedule.filter { $0.round == round - 1 }
        let previousPairs = Set(previousRoundMatches.flatMap { match in
            [
                PlayerPair(player1: match.team1.player1, player2: match.team1.player2),
                PlayerPair(player1: match.team2.player1, player2: match.team2.player2)
            ]
        })
        
        // Sort potential partners based on multiple factors
        let potentialPartners = remainingPlayers.sorted { p1, p2 in
            let pair1 = PlayerPair(player1: player1, player2: p1)
            let pair2 = PlayerPair(player1: player1, player2: p2)
            let usage1 = pairUsageCount[pair1] ?? 0
            let usage2 = pairUsageCount[pair2] ?? 0
            
            // If we're allowing repeats, use a weighted random approach
            if allowRepeats {
                // Avoid pairs from the previous round
                if previousPairs.contains(pair1) && !previousPairs.contains(pair2) {
                    return false
                }
                if !previousPairs.contains(pair1) && previousPairs.contains(pair2) {
                    return true
                }
                
                // Add some randomness while still considering usage
                let randomFactor = Double.random(in: 0...0.3, using: &rng)
                return Double(usage1) + randomFactor < Double(usage2)
            }
            
            // For unique pairs, maintain original sorting
            return usage1 < usage2
        }
        
        for partner1 in potentialPartners {
            let team1Pair = PlayerPair(player1: player1, player2: partner1)
            
            // Skip if pair was used and we're not allowing repeats
            if !allowRepeats && usedPairs.contains(team1Pair) {
                continue
            }
            
            let playersForTeam2 = remainingPlayers.filter { $0 != partner1 }
            
            // Sort team 2 candidates with similar logic
            let team2Candidates = playersForTeam2.sorted { p1, p2 in
                if allowRepeats {
                    let avgUsage1 = averagePairUsage(player: p1, against: [player1, partner1])
                    let avgUsage2 = averagePairUsage(player: p2, against: [player1, partner1])
                    let randomFactor = Double.random(in: 0...0.3, using: &rng)
                    return avgUsage1 + randomFactor < avgUsage2
                }
                return averagePairUsage(player: p1, against: [player1, partner1]) <
                       averagePairUsage(player: p2, against: [player1, partner1])
            }
            
            for player2 in team2Candidates {
                let remainingForTeam2 = team2Candidates.filter { $0 != player2 }
                
                // Sort potential partners for team 2 player
                let potentialPartners2 = remainingForTeam2.sorted { p1, p2 in
                    let pair1 = PlayerPair(player1: player2, player2: p1)
                    let pair2 = PlayerPair(player1: player2, player2: p2)
                    
                    if allowRepeats {
                        // Avoid pairs from the previous round
                        if previousPairs.contains(pair1) && !previousPairs.contains(pair2) {
                            return false
                        }
                        if !previousPairs.contains(pair1) && previousPairs.contains(pair2) {
                            return true
                        }
                        
                        // Add randomness while considering usage
                        let randomFactor = Double.random(in: 0...0.3, using: &rng)
                        return Double(pairUsageCount[pair1] ?? 0) + randomFactor <
                               Double(pairUsageCount[pair2] ?? 0)
                    }
                    
                    return (pairUsageCount[pair1] ?? 0) < (pairUsageCount[pair2] ?? 0)
                }
                
                for partner2 in potentialPartners2 {
                    let team2Pair = PlayerPair(player1: player2, player2: partner2)
                    
                    // Skip if pair was used and we're not allowing repeats
                    if !allowRepeats && usedPairs.contains(team2Pair) {
                        continue
                    }
                    
                    // Skip if both pairs were used in the previous round
                    if allowRepeats && previousPairs.contains(team1Pair) && previousPairs.contains(team2Pair) {
                        continue
                    }
                    
                    let team1 = Team(player1: player1, player2: partner1)
                    let team2 = Team(player1: player2, player2: partner2)
                    let match = Match(id: UUID(), round: round, court: courtNumber, team1: team1, team2: team2)
                    
                    var nextPlayers = remainingPlayers
                    nextPlayers.removeAll { [partner1, player2, partner2].contains($0) }
                    
                    if let remainingMatches = generateMatchesWithBacktracking(availablePlayers: nextPlayers, round: round, courtNumber: courtNumber + 1, existingSchedule: existingSchedule) {
                        matches.append(match)
                        matches.append(contentsOf: remainingMatches)
                        return matches
                    }
                }
            }
        }
        
        return nil
    }
    
    private func averagePairUsage(player: String, against opponents: [String]) -> Double {
        let usages = opponents.map { opponent in
            let pair = PlayerPair(player1: player, player2: opponent)
            return pairUsageCount[pair] ?? 0
        }
        return Double(usages.reduce(0, +)) / Double(opponents.count)
    }
    
    public mutating func generateAdditionalRound(existingSchedule: [Match]) -> ([Match], [String])? {
        let newRound = (existingSchedule.last?.round ?? -1) + 1
        numberOfRounds += 1
        
        // Update pair usage and last used round from existing schedule
        for match in existingSchedule {
            updatePairUsage(team1: match.team1, team2: match.team2, round: match.round)
            updatePlayerStats(team1: match.team1, team2: match.team2, round: match.round)
        }
        
        let (newMatches, restingPlayers) = generateRound(round: newRound)
        
        if newMatches.isEmpty {
            print("Error: Could not generate additional round")
            numberOfRounds -= 1  // Revert the round increment
            return nil
        }
        
        restingPlayersByRound[newRound] = restingPlayers
        return (newMatches, restingPlayers)
    }
}
