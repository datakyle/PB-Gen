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
        // Filter out invalid entries (empty names or placeholder names)
        let validEntries = leaderboard.filter { key, value in
            !key.isEmpty && key != " " && key.trimmingCharacters(in: .whitespaces) != ""
        }
        
        return validEntries.sorted { lhs, rhs in
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
        sortedLeaderboard.isEmpty
    }
    
    // MARK: - Public Methods
    func initializeLeaderboard(for players: [String]) {
        // Clear existing leaderboard first to prevent accumulation
        leaderboard.removeAll()
        
        let validPlayers = players.filter { !$0.isEmpty && $0.trimmingCharacters(in: .whitespaces) != "" }
        leaderboard = Dictionary(uniqueKeysWithValues: validPlayers.map { 
            ($0, PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)) 
        })
        
        print("🏆 Initialized leaderboard for \(validPlayers.count) players: \(validPlayers.joined(separator: ", "))")
    }
    
    func updateLeaderboard(winningTeam: Team, losingTeam: Team, points: Int, differential: Int = 0) {
        // Validate team names before processing
        let allPlayers = [winningTeam.player1, winningTeam.player2, losingTeam.player1, losingTeam.player2]
        let validPlayers = allPlayers.filter { !$0.isEmpty && $0.trimmingCharacters(in: .whitespaces) != "" }
        
        // Skip if any invalid players
        guard validPlayers.count == 4 else {
            print("⚠️ Skipping leaderboard update - invalid team data")
            return
        }
        
        // Only update players that exist in the leaderboard
        guard leaderboard[winningTeam.player1] != nil,
              leaderboard[winningTeam.player2] != nil,
              leaderboard[losingTeam.player1] != nil,
              leaderboard[losingTeam.player2] != nil else {
            print("⚠️ Skipping leaderboard update - players not found in leaderboard")
            return
        }
        
        if points > 0 {
            // Add wins and losses
            leaderboard[winningTeam.player1]!.wins += 1
            leaderboard[winningTeam.player2]!.wins += 1
            leaderboard[losingTeam.player1]!.losses += 1
            leaderboard[losingTeam.player2]!.losses += 1
            
            // Update point differentials
            leaderboard[winningTeam.player1]!.pointDifferential += differential
            leaderboard[winningTeam.player2]!.pointDifferential += differential
            leaderboard[losingTeam.player1]!.pointDifferential -= differential
            leaderboard[losingTeam.player2]!.pointDifferential -= differential
            
            // Update scores
            leaderboard[winningTeam.player1]!.score += points
            leaderboard[winningTeam.player2]!.score += points
            
            print("📊 Updated stats: \(winningTeam.player1) & \(winningTeam.player2) beat \(losingTeam.player1) & \(losingTeam.player2)")
        } else if points < 0 {
            // Undo previous stats (for score corrections) - prevent negative values
            leaderboard[winningTeam.player1]!.wins = max(0, leaderboard[winningTeam.player1]!.wins - 1)
            leaderboard[winningTeam.player2]!.wins = max(0, leaderboard[winningTeam.player2]!.wins - 1)
            leaderboard[losingTeam.player1]!.losses = max(0, leaderboard[losingTeam.player1]!.losses - 1)
            leaderboard[losingTeam.player2]!.losses = max(0, leaderboard[losingTeam.player2]!.losses - 1)
            
            // Undo point differentials
            leaderboard[winningTeam.player1]!.pointDifferential -= differential
            leaderboard[winningTeam.player2]!.pointDifferential -= differential
            leaderboard[losingTeam.player1]!.pointDifferential += differential
            leaderboard[losingTeam.player2]!.pointDifferential += differential
            
            // Update scores
            leaderboard[winningTeam.player1]!.score += points
            leaderboard[winningTeam.player2]!.score += points
            
            print("↩️ Undid stats for: \(winningTeam.player1) & \(winningTeam.player2)")
        }
    }
    
    func updateRests(for restingPlayers: [String]) {
        let validRestingPlayers = restingPlayers.filter { 
            !$0.isEmpty && 
            $0.trimmingCharacters(in: .whitespaces) != "" && 
            leaderboard[$0] != nil 
        }
        
        for player in validRestingPlayers {
            leaderboard[player]!.rests += 1
        }
        
        if !validRestingPlayers.isEmpty {
            print("😴 Updated rests for: \(validRestingPlayers.joined(separator: ", "))")
        }
    }
    
    func clearLeaderboard() {
        leaderboard.removeAll()
        print("🧹 Cleared leaderboard")
    }
    
    func setSortOrder(_ order: SortOrder) {
        withAnimation(.easeInOut(duration: AppConstants.UI.animationDuration)) {
            sortOrder = order
        }
    }
    
    // MARK: - Debug Methods
    func debugLeaderboard() {
        print("🔍 Leaderboard Debug:")
        print("Total entries: \(leaderboard.count)")
        for (player, stats) in leaderboard {
            print("  \(player): W:\(stats.wins) L:\(stats.losses) Pts:\(stats.pointDifferential) R:\(stats.rests)")
        }
    }
    
    func cleanupInvalidEntries() {
        let invalidKeys = leaderboard.keys.filter { 
            $0.isEmpty || $0.trimmingCharacters(in: .whitespaces) == ""
        }
        
        for key in invalidKeys {
            leaderboard.removeValue(forKey: key)
            print("🧹 Removed invalid leaderboard entry: '\(key)'")
        }
    }
}

enum SortOrder: String, CaseIterable {
    case name, score, wins, losses, rests
}