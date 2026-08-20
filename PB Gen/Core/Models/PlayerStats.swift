import Foundation

public struct PlayerStats: Codable, Hashable {
    public var gamesPlayed: Int
    public var uniquePairs: Set<String>
    public var lastPlayedRound: Int
    public var score: Int
    public var wins: Int
    public var losses: Int
    public var rests: Int
    public var pointDifferential: Int
    
    public init(gamesPlayed: Int = 0, uniquePairs: Set<String> = [], lastPlayedRound: Int = -1,
                score: Int = 0, wins: Int = 0, losses: Int = 0, rests: Int = 0, pointDifferential: Int = 0) {
        self.gamesPlayed = gamesPlayed
        self.uniquePairs = uniquePairs
        self.lastPlayedRound = lastPlayedRound
        self.score = score
        self.wins = wins
        self.losses = losses
        self.rests = rests
        self.pointDifferential = pointDifferential
    }
    
    // Required by Codable when using Set
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed = try container.decode(Int.self, forKey: .gamesPlayed)
        uniquePairs = Set(try container.decode([String].self, forKey: .uniquePairs))
        lastPlayedRound = try container.decode(Int.self, forKey: .lastPlayedRound)
        score = try container.decode(Int.self, forKey: .score)
        wins = try container.decode(Int.self, forKey: .wins)
        losses = try container.decode(Int.self, forKey: .losses)
        rests = try container.decode(Int.self, forKey: .rests)
        pointDifferential = try container.decodeIfPresent(Int.self, forKey: .pointDifferential) ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gamesPlayed, forKey: .gamesPlayed)
        try container.encode(Array(uniquePairs), forKey: .uniquePairs)
        try container.encode(lastPlayedRound, forKey: .lastPlayedRound)
        try container.encode(score, forKey: .score)
        try container.encode(wins, forKey: .wins)
        try container.encode(losses, forKey: .losses)
        try container.encode(rests, forKey: .rests)
        try container.encode(pointDifferential, forKey: .pointDifferential)
    }
    
    private enum CodingKeys: String, CodingKey {
        case gamesPlayed
        case uniquePairs
        case lastPlayedRound
        case score
        case wins
        case losses
        case rests
        case pointDifferential
    }
} 