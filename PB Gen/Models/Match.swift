import Foundation

public struct Team: Codable, Hashable {
    public let player1: String
    public let player2: String
    
    public init(player1: String, player2: String) {
        self.player1 = player1
        self.player2 = player2
    }
}

public struct Match: Codable, Identifiable, Hashable {
    public let id: UUID
    public let round: Int
    public var court: Int
    public let team1: Team
    public let team2: Team
    public var team1Score: Int
    public var team2Score: Int
    public var winningTeam: Int? // 1 for team1, 2 for team2, nil for no winner
    
    public init(id: UUID = UUID(), round: Int, court: Int, team1: Team, team2: Team) {
        self.id = id
        self.round = round
        self.court = court
        self.team1 = team1
        self.team2 = team2
        self.team1Score = 0
        self.team2Score = 0
        self.winningTeam = nil
    }
}