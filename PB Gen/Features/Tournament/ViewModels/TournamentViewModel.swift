//
//  TournamentViewModel.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import Foundation
import SwiftUI

@MainActor
class TournamentViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var tournamentName: String = ""
    @Published var playerNames: [String] = ["", "", "", ""]
    @Published var numberOfRounds = AppConstants.Tournament.defaultRounds
    @Published var numberOfCourts = AppConstants.Tournament.defaultCourts
    @Published var duplicateNames: Set<String> = []
    @Published var savedTournaments: [String] = []
    
    // MARK: - Computed Properties
    var canGenerateSchedule: Bool {
        let validPlayers = playerNames.filter { !$0.isEmpty }
        return validPlayers.count >= AppConstants.Tournament.minimumPlayers && duplicateNames.isEmpty
    }
    
    var validPlayerCount: Int {
        playerNames.filter { !$0.isEmpty }.count
    }
    
    // MARK: - Public Methods
    func addPlayer() {
        withAnimation(.spring(duration: Theme.Layout.shadowRadius)) {
            playerNames.append("")
        }
    }
    
    func removePlayer(at offsets: IndexSet) {
        // Ensure we don't delete if it would leave us with less than minimum slots
        let remainingCount = playerNames.count - offsets.count
        if remainingCount < AppConstants.Tournament.minimumPlayers {
            let slotsToAdd = AppConstants.Tournament.minimumPlayers - remainingCount
            playerNames.append(contentsOf: Array(repeating: "", count: slotsToAdd))
        }
        
        playerNames.remove(atOffsets: offsets)
        checkForDuplicates()
    }
    
    func validatePlayerName(at index: Int) {
        checkForDuplicates()
    }
    
    func resetTournament() {
        tournamentName = ""
        playerNames = ["", "", "", ""]
        numberOfRounds = AppConstants.Tournament.defaultRounds
        numberOfCourts = AppConstants.Tournament.defaultCourts
        duplicateNames = []
    }
    
    func loadSavedTournaments() {
        if let data = UserDefaults.standard.data(forKey: AppConstants.StorageKeys.savedTournaments),
           let tournaments = try? JSONDecoder().decode([String].self, from: data) {
            savedTournaments = tournaments
        }
    }
    
    func saveTournamentList() {
        if let data = try? JSONEncoder().encode(savedTournaments) {
            UserDefaults.standard.set(data, forKey: AppConstants.StorageKeys.savedTournaments)
        }
    }
    
    func deleteTournament(_ name: String) {
        if let index = savedTournaments.firstIndex(of: name) {
            savedTournaments.remove(at: index)
        }
        UserDefaults.standard.removeObject(forKey: AppConstants.StorageKeys.tournamentKey(name))
        saveTournamentList()
    }
    
    // MARK: - Private Methods
    private func checkForDuplicates() {
        let nonEmptyNames = playerNames.filter { !$0.isEmpty }
        let nameCounts = Dictionary(nonEmptyNames.map { ($0, 1) }, uniquingKeysWith: +)
        duplicateNames = Set(nameCounts.filter { $0.value > 1 }.keys)
    }
}