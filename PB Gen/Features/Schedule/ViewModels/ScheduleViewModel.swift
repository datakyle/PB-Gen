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
    
    // MARK: - Private Properties
    private var scheduler: AmericanoScheduler?
    private let pointsPerWin: Int
    private let updateLeaderboardCallback: (Team, Team, Int, Int) -> Void
    
    // MARK: - Initialization
    init(pointsPerWin: Int, updateLeaderboard: @escaping (Team, Team, Int, Int) -> Void) {
        self.pointsPerWin = pointsPerWin
        self.updateLeaderboardCallback = updateLeaderboard
    }
    
    // MARK: - Public Methods
    func generateSchedule(players: [String], rounds: Int, courts: Int) {
        isGenerating = true
        
        let validPlayers = players.filter { !$0.isEmpty }
        let seed = UInt64.random(in: 0...UInt64.max)
        scheduler = AmericanoScheduler(players: validPlayers, numberOfRounds: rounds, numberOfCourts: courts, seed: seed)
        
        if let (newSchedule, newRestingPlayers) = scheduler?.generateSchedule() {
            withAnimation(.easeInOut(duration: AppConstants.UI.animationDuration)) {
                schedule = newSchedule
                restingPlayersByRound = newRestingPlayers
                numberOfRounds = rounds
            }
        }
        
        isGenerating = false
    }
    
    func addRound() {
        guard var scheduler = scheduler else { return }
        
        withAnimation(.spring(duration: AppConstants.UI.springAnimation)) {
            animateNewRound = true
        }
        
        if let (newRound, newRestingPlayers) = scheduler.generateAdditionalRound(existingSchedule: schedule) {
            schedule.append(contentsOf: newRound)
            restingPlayersByRound[numberOfRounds] = newRestingPlayers
            numberOfRounds += 1
            self.scheduler = scheduler
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.animateNewRound = false
        }
    }
    
    func updateMatch(_ match: Match) {
        if let index = schedule.firstIndex(where: { $0.id == match.id }) {
            schedule[index] = match
        }
    }
    
    func processScoreUpdate(for match: Match, team1Score: Int, team2Score: Int) {
        let differential = abs(team1Score - team2Score)
        
        if team1Score > team2Score {
            updateLeaderboardCallback(match.team1, match.team2, pointsPerWin, differential)
        } else if team2Score > team1Score {
            updateLeaderboardCallback(match.team2, match.team1, pointsPerWin, differential)
        }
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
    }
}