//
//  LeaderboardViewModel.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import Foundation
import SwiftUI

@MainActor
class LeaderboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var leaderboard: [String: PlayerStats] = [:]
    @Published var sortOrder: SortOrder = .score
    
    // MARK: - Computed Properties
    var sortedLeaderboard: [(key: String, value: PlayerStats)] {
        leaderboard.sorted { lhs, rhs in
            switch sortOrder {
            case .name:
                return lhs.key.lowercased() < rhs.key.lowercased()
            case .score:
                if lhs.value.wins == rhs.value.wins {
                    return lhs.value.pointDifferential > rhs.value.pointDifferential
                }
                return lhs.value.wins > rhs.value.wins
            case .wins:
                return lhs.value.wins > rhs.value.wins
            case .losses:
                return lhs.value.losses < rhs.value.losses
            case .rests:
                return lhs.value.rests < rhs.value.rests
            }
        }
    }
    
    var isEmpty: Bool {
        leaderboard.isEmpty
    }
    
    // MARK: - Public Methods
    func initializeLeaderboard(for players: [String]) {
        let validPlayers = players.filter { !$0.isEmpty }
        leaderboard = Dictionary(uniqueKeysWithValues: validPlayers.map { 
            ($0, PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)) 
        })
    }
    
    func updateLeaderboard(winningTeam: Team, losingTeam: Team, points: Int, differential: Int = 0) {
        // Update winning team
        leaderboard[winningTeam.player1, default: PlayerStats()].score += points
        leaderboard[winningTeam.player2, default: PlayerStats()].score += points
        
        if points > 0 {
            // Add wins and losses
            leaderboard[winningTeam.player1, default: PlayerStats()].wins += 1
            leaderboard[winningTeam.player2, default: PlayerStats()].wins += 1
            leaderboard[losingTeam.player1, default: PlayerStats()].losses += 1
            leaderboard[losingTeam.player2, default: PlayerStats()].losses += 1
            
            // Update point differentials
            leaderboard[winningTeam.player1, default: PlayerStats()].pointDifferential += differential
            leaderboard[winningTeam.player2, default: PlayerStats()].pointDifferential += differential
            leaderboard[losingTeam.player1, default: PlayerStats()].pointDifferential -= differential
            leaderboard[losingTeam.player2, default: PlayerStats()].pointDifferential -= differential
        } else {
            // Undo previous stats (for score corrections)
            leaderboard[winningTeam.player1, default: PlayerStats()].wins -= 1
            leaderboard[winningTeam.player2, default: PlayerStats()].wins -= 1
            leaderboard[losingTeam.player1, default: PlayerStats()].losses -= 1
            leaderboard[losingTeam.player2, default: PlayerStats()].losses -= 1
            
            // Undo point differentials
            leaderboard[winningTeam.player1, default: PlayerStats()].pointDifferential -= differential
            leaderboard[winningTeam.player2, default: PlayerStats()].pointDifferential -= differential
            leaderboard[losingTeam.player1, default: PlayerStats()].pointDifferential += differential
            leaderboard[losingTeam.player2, default: PlayerStats()].pointDifferential += differential
        }
    }
    
    func updateRests(for restingPlayers: [String]) {
        for player in restingPlayers {
            leaderboard[player, default: PlayerStats()].rests += 1
        }
    }
    
    func clearLeaderboard() {
        leaderboard = [:]
    }
    
    func setSortOrder(_ order: SortOrder) {
        withAnimation(.easeInOut(duration: AppConstants.UI.animationDuration)) {
            sortOrder = order
        }
    }
}

enum SortOrder: String, CaseIterable {
    case name, score, wins, losses, rests
}