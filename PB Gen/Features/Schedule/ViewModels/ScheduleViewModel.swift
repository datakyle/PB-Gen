//
//  ScheduleViewModel.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import Foundation
import SwiftUI

@MainActor 
class ScheduleViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var schedule: [Match] = []
    @Published var numberOfRounds: Int = AppConstants.Tournament.defaultRounds
    @Published var restingPlayersByRound: [Int: [String]] = [:]
    @Published var isGenerating = false
    @Published var animateNewRound = false
    @Published var isAddingRound = false
    @Published var addRoundError: String?
    
    // MARK: - Private Properties
    private var scheduler: AmericanoScheduler?
    private let pointsPerWin: Int
    private let updateLeaderboardCallback: (Team, Team, Int, Int) -> Void
    private let saveDataCallback: () -> Void
    
    // MARK: - Initialization
    init(pointsPerWin: Int, updateLeaderboard: @escaping (Team, Team, Int, Int) -> Void, saveData: @escaping () -> Void = {}) {
        self.pointsPerWin = pointsPerWin
        self.updateLeaderboardCallback = updateLeaderboard
        self.saveDataCallback = saveData
    }
    
    // MARK: - Public Methods
    func generateSchedule(players: [String], rounds: Int, courts: Int) {
        isGenerating = true
        addRoundError = nil
        
        let validPlayers = players.filter { !$0.isEmpty }
        let seed = UInt64.random(in: 0...UInt64.max)
        scheduler = AmericanoScheduler(players: validPlayers, numberOfRounds: rounds, numberOfCourts: courts, seed: seed)
        
        if let (newSchedule, newRestingPlayers) = scheduler?.generateSchedule() {
            withAnimation(.easeInOut(duration: AppConstants.UI.animationDuration)) {
                schedule = newSchedule
                restingPlayersByRound = newRestingPlayers
                numberOfRounds = rounds
            }
            
            // Auto-save after generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.saveDataCallback()
            }
        }
        
        isGenerating = false
    }
    
    func addRound() {
        guard var scheduler = scheduler else { 
            addRoundError = "No scheduler available. Please generate a schedule first."
            return 
        }
        
        guard !isAddingRound else { return } // Prevent multiple simultaneous additions
        
        isAddingRound = true
        addRoundError = nil
        
        withAnimation(.spring(duration: AppConstants.UI.springAnimation)) {
            animateNewRound = true
        }
        
        // Add a small delay to show the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let (newRound, newRestingPlayers) = scheduler.generateAdditionalRound(existingSchedule: self.schedule) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.schedule.append(contentsOf: newRound)
                    self.restingPlayersByRound[self.numberOfRounds] = newRestingPlayers
                    self.numberOfRounds += 1
                    self.scheduler = scheduler
                }
                
                // Auto-save after adding round
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.saveDataCallback()
                }
                
                print("✅ Successfully added Round \(self.numberOfRounds)")
                print("📊 New matches: \(newRound.count)")
                print("😴 Resting players: \(newRestingPlayers.joined(separator: ", "))")
            } else {
                self.addRoundError = "Unable to generate additional round. This may happen when all fair pairing combinations are exhausted."
                print("❌ Failed to generate additional round")
            }
            
            self.isAddingRound = false
            
            // Reset animation after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.animateNewRound = false
            }
        }
    }
    
    func canAddRound() -> Bool {
        return scheduler != nil && !isAddingRound && !isGenerating
    }
    
    func updateMatch(_ match: Match) {
        if let index = schedule.firstIndex(where: { $0.id == match.id }) {
            schedule[index] = match
            
            // Auto-save after match update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.saveDataCallback()
            }
        }
    }
    
    func processScoreUpdate(for match: Match, team1Score: Int, team2Score: Int) {
        let differential = abs(team1Score - team2Score)
        
        if team1Score > team2Score {
            updateLeaderboardCallback(match.team1, match.team2, pointsPerWin, differential)
        } else if team2Score > team1Score {
            updateLeaderboardCallback(match.team2, match.team1, pointsPerWin, differential)
        }
        
        // Auto-save after score update
        saveDataCallback()
    }
    
    func matchesForRound(_ round: Int) -> [Match] {
        return schedule.filter { $0.round == round }
    }
    
    func restingPlayersForRound(_ round: Int) -> [String] {
        return restingPlayersByRound[round] ?? []
    }
    
    func clearSchedule() {
        schedule = []
        restingPlayersByRound = [:]
        numberOfRounds = AppConstants.Tournament.defaultRounds
        scheduler = nil
        addRoundError = nil
        isAddingRound = false
        isGenerating = false
    }
    
    // MARK: - Helper Methods
    func getTotalMatches() -> Int {
        return schedule.count
    }
    
    func getCompletedMatches() -> Int {
        return schedule.filter { $0.winningTeam != nil }.count
    }
    
    func getRoundProgress() -> Double {
        guard getTotalMatches() > 0 else { return 0.0 }
        return Double(getCompletedMatches()) / Double(getTotalMatches())
    }
}