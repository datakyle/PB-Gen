//
//  AppCoordinator.swift
//  PB Gen - Americano Tournament Generator
//
//  Created by Francis-Kyle Bautista on 10/4/24.
//

import SwiftUI

struct AppCoordinator: View {
    // MARK: - App Storage
    @AppStorage(AppConstants.StorageKeys.currentTournament) private var currentTournament: String = ""
    @AppStorage(AppConstants.StorageKeys.showMainView) private var showMainView: Bool = false
    @AppStorage(AppConstants.StorageKeys.savedTournaments) private var savedTournamentsData: Data = Data()
    
    // MARK: - State
    @State private var selectedTab = 0
    @State private var isShowingSavedTournaments = false
    @State private var showTournamentSelection = false
    
    // MARK: - ViewModels
    @StateObject private var tournamentViewModel = TournamentViewModel()
    @StateObject private var leaderboardViewModel = LeaderboardViewModel()
    @StateObject private var scheduleViewModel: ScheduleViewModel
    
    // MARK: - Initialization
    init() {
        let leaderboard = LeaderboardViewModel()
        self._leaderboardViewModel = StateObject(wrappedValue: leaderboard)
        
        let schedule = ScheduleViewModel(
            pointsPerWin: AppConstants.Tournament.defaultPointsPerWin,
            updateLeaderboard: { winningTeam, losingTeam, points, differential in
                leaderboard.updateLeaderboard(winningTeam: winningTeam, losingTeam: losingTeam, points: points, differential: differential)
            },
            saveData: {} // We'll handle saving in the main view
        )
        self._scheduleViewModel = StateObject(wrappedValue: schedule)
    }

    var body: some View {
        ZStack {
            // Gradient Background
            Theme.Gradients.mainBackground
                .ignoresSafeArea()
            
            Group {
                if !showMainView || isShowingSavedTournaments {
                    CreateTournamentView(
                        viewModel: tournamentViewModel,
                        isShowingSavedTournaments: $isShowingSavedTournaments,
                        onTournamentCreated: handleTournamentCreated,
                        onTournamentLoaded: handleTournamentLoaded,
                        onTournamentDeleted: handleTournamentDeleted,
                        onAppReset: handleAppReset
                    )
                } else {
                    mainView
                }
            }
        }
        .sheet(isPresented: $showTournamentSelection) {
            TournamentSelectionSheet(
                savedTournaments: tournamentViewModel.savedTournaments,
                currentTournament: currentTournament,
                onTournamentSelected: handleTournamentLoaded,
                isPresented: $showTournamentSelection
            )
        }
        .onAppear(perform: loadSavedData)
    }
    
    // MARK: - Main View
    var mainView: some View {
        ZStack {
            // Content Area - extends behind tab bar
            switch selectedTab {
            case 0:
                TournamentDetailsView(
                    viewModel: tournamentViewModel,
                    tournamentName: currentTournament,
                    onScheduleGenerated: handleScheduleGeneration,
                    onNewTournament: handleNewTournament,
                    onViewSavedTournaments: handleViewSavedTournaments,
                    onAppReset: handleAppReset,
                    onTournamentSelection: { showTournamentSelection = true },
                    onCleanupLeaderboard: { leaderboardViewModel.cleanupInvalidEntries() }
                )
            case 1:
                ScheduleView(
                    viewModel: scheduleViewModel,
                    tournamentName: currentTournament,
                    onTournamentSelection: { showTournamentSelection = true }
                )
                .onReceive(scheduleViewModel.$numberOfRounds) { newRoundCount in
                    // Update tournament view model when rounds are added
                    if newRoundCount > tournamentViewModel.numberOfRounds {
                        tournamentViewModel.numberOfRounds = newRoundCount
                        
                        // Update rests for any new rounds
                        for round in tournamentViewModel.numberOfRounds..<newRoundCount {
                            let restingPlayers = scheduleViewModel.restingPlayersForRound(round)
                            leaderboardViewModel.updateRests(for: restingPlayers)
                        }
                        
                        saveData()
                    }
                }
            case 2:
                LeaderboardView(
                    viewModel: leaderboardViewModel,
                    tournamentName: currentTournament,
                    onTournamentSelection: { showTournamentSelection = true }
                )
            default:
                EmptyView()
            }
            
            // Floating Custom Tab Bar
            VStack {
                Spacer()
                CustomTabBar(selectedIndex: $selectedTab, items: ["Details", "Schedule", "Leaderboard"])
            }
        }
        .animation(.easeInOut, value: selectedTab)
        .navigationBarHidden(true)
    }
    
    // MARK: - Event Handlers
    private func handleTournamentCreated(_ name: String) {
        currentTournament = name
        tournamentViewModel.tournamentName = name
        
        if !tournamentViewModel.savedTournaments.contains(name) {
            tournamentViewModel.savedTournaments.append(name)
            tournamentViewModel.saveTournamentList()
        }
        
        showMainView = true
        isShowingSavedTournaments = false
    }
    
    private func handleTournamentLoaded(_ name: String) {
        currentTournament = name
        loadTournamentData(name)
        
        // Clean up any invalid leaderboard entries after loading
        leaderboardViewModel.cleanupInvalidEntries()
        
        showMainView = true
        isShowingSavedTournaments = false
    }
    
    private func handleTournamentDeleted(_ name: String) {
        tournamentViewModel.deleteTournament(name)
    }
    
    private func handleScheduleGeneration() {
        let validPlayers = tournamentViewModel.playerNames.filter { !$0.isEmpty }
        
        // Clean up any invalid leaderboard entries first
        leaderboardViewModel.cleanupInvalidEntries()
        
        // Generate schedule
        scheduleViewModel.generateSchedule(
            players: validPlayers,
            rounds: tournamentViewModel.numberOfRounds,
            courts: tournamentViewModel.numberOfCourts
        )
        
        // Initialize leaderboard with clean data
        leaderboardViewModel.initializeLeaderboard(for: validPlayers)
        
        // Update rests
        for round in 0..<scheduleViewModel.numberOfRounds {
            let restingPlayers = scheduleViewModel.restingPlayersForRound(round)
            leaderboardViewModel.updateRests(for: restingPlayers)
        }
        
        selectedTab = 1 // Switch to Schedule tab
        saveData()
    }
    
    private func handleNewTournament() {
        saveData() // Save current tournament before creating new one
        resetToNewTournament()
    }
    
    private func handleViewSavedTournaments() {
        isShowingSavedTournaments = true
        showMainView = false
    }
    
    private func handleAppReset() {
        currentTournament = ""
        showMainView = false
        selectedTab = 0
        savedTournamentsData = Data()
        
        // Reset all ViewModels
        tournamentViewModel.resetTournament()
        scheduleViewModel.clearSchedule()
        leaderboardViewModel.clearLeaderboard()
        tournamentViewModel.savedTournaments = []
        
        saveData()
    }
    
    // MARK: - Data Management
    private func loadSavedData() {
        // Load saved tournaments list
        tournamentViewModel.loadSavedTournaments()
        
        // Load current tournament if exists
        if !currentTournament.isEmpty {
            loadTournamentData(currentTournament)
        }
    }
    
    private func loadTournamentData(_ tournamentName: String) {
        guard let savedData = UserDefaults.standard.data(forKey: AppConstants.StorageKeys.tournamentKey(tournamentName)),
              let decodedData = try? JSONDecoder().decode(TournamentData.self, from: savedData) else {
            return
        }
        
        // Update tournament view model
        tournamentViewModel.tournamentName = tournamentName
        tournamentViewModel.playerNames = decodedData.players
        tournamentViewModel.numberOfRounds = decodedData.scheduler.numberOfRounds
        tournamentViewModel.numberOfCourts = decodedData.scheduler.numberOfCourts
        
        // Update schedule view model
        scheduleViewModel.schedule = decodedData.matches
        scheduleViewModel.numberOfRounds = decodedData.scheduler.numberOfRounds
        regenerateRestingPlayers()
        
        // Clean and update leaderboard view model
        leaderboardViewModel.leaderboard = decodedData.playerStats
        leaderboardViewModel.cleanupInvalidEntries()
        
        print("📂 Loaded tournament: \(tournamentName)")
        print("👥 Players: \(decodedData.players.filter { !$0.isEmpty }.joined(separator: ", "))")
        leaderboardViewModel.debugLeaderboard()
    }
    
    private func regenerateRestingPlayers() {
        var restingByRound: [Int: [String]] = [:]
        
        for round in 0..<scheduleViewModel.numberOfRounds {
            let matchesInRound = scheduleViewModel.matchesForRound(round)
            let playersInRound = Set(matchesInRound.flatMap { 
                [$0.team1.player1, $0.team1.player2, $0.team2.player1, $0.team2.player2] 
            })
            let allPlayers = Set(tournamentViewModel.playerNames.filter { !$0.isEmpty })
            let restingPlayers = allPlayers.subtracting(playersInRound)
            restingByRound[round] = Array(restingPlayers)
        }
        
        scheduleViewModel.restingPlayersByRound = restingByRound
    }
    
    private func saveData() {
        // Save tournament list
        tournamentViewModel.saveTournamentList()
        
        // Save current tournament data
        guard !currentTournament.isEmpty else { return }
        
        var tournamentData = TournamentData(
            name: currentTournament,
            players: tournamentViewModel.playerNames.filter { !$0.isEmpty },
            numberOfRounds: tournamentViewModel.numberOfRounds,
            numberOfCourts: tournamentViewModel.numberOfCourts
        )
        
        // Update with current state
        tournamentData.matches = scheduleViewModel.schedule
        tournamentData.playerStats = leaderboardViewModel.leaderboard
        
        if let encodedData = try? JSONEncoder().encode(tournamentData) {
            UserDefaults.standard.set(encodedData, forKey: AppConstants.StorageKeys.tournamentKey(currentTournament))
        }
    }
    
    private func resetToNewTournament() {
        currentTournament = ""
        showMainView = false
        selectedTab = 0
        
        // Reset ViewModels
        tournamentViewModel.resetTournament()
        scheduleViewModel.clearSchedule()
        leaderboardViewModel.clearLeaderboard()
    }
}

#Preview {
    AppCoordinator()
}