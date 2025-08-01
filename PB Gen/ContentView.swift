   //
//  ContentView.swift
//  Fun Note Tester
//
//  Created by Francis-Kyle Bautista on 10/4/24.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("currentTournament") private var currentTournament: String = ""
    @AppStorage("showMainView") private var showMainView: Bool = false
    @AppStorage("savedTournaments") private var savedTournamentsData: Data = Data()
    
    @State private var savedTournaments: [String] = []
    @State private var selectedTab = 0
    @State private var playerNames: [String] = []
    @State private var numberOfRounds = 3
    @State private var pointsPerWin = 1
    @State private var numberOfCourts = 1
    @State private var schedule: [Match] = []
    @State private var leaderboard: [String: PlayerStats] = [:]
    @State private var scheduler: AmericanoScheduler?
    @State private var restingPlayersByRound: [Int: [String]] = [:]
    @State private var isShowingSavedTournaments = false

    var body: some View {
        Group {
            if !showMainView || isShowingSavedTournaments {
                CreateTournamentView(tournamentName: $currentTournament, 
                                     showMainView: $showMainView, 
                                     savedTournaments: $savedTournaments,
                                     isShowingSavedTournaments: $isShowingSavedTournaments,
                                     loadTournament: loadTournament,
                                     deleteTournament: deleteTournament,
                                     resetApp: resetApp)
            } else {
                mainView
            }
        }
        .onAppear(perform: loadSavedData)
    }
    
    var mainView: some View {
        VStack {
            switch selectedTab {
            case 0:
                DetailsView(tournamentName: $currentTournament,
                            playerNames: $playerNames, 
                            numberOfRounds: $numberOfRounds, 
                            pointsPerWin: $pointsPerWin, 
                            numberOfCourts: $numberOfCourts, 
                            generateSchedule: generateSchedule,
                            resetApp: resetApp,
                            saveData: saveData,
                            createNewTournament: createNewTournament,
                            viewSavedTournaments: { 
                                isShowingSavedTournaments = true 
                                showMainView = false 
                            })
            case 1:
                ScheduleView(schedule: $schedule,  
                             playerNames: playerNames, 
                             numberOfRounds: $numberOfRounds, 
                             pointsPerWin: pointsPerWin, 
                             updateLeaderboard: updateLeaderboard, 
                             addRound: addRound,
                             restingPlayersByRound: restingPlayersByRound)
            case 2:
                LeaderboardView(leaderboard: leaderboard)
            default:
                EmptyView()
            }
            
            CustomTabBar(selectedIndex: $selectedTab, items: ["Details", "Schedule", "Leaderboard"])
                .padding()
        }
        .accentColor(.blue)
        .animation(.easeInOut, value: selectedTab)
        .navigationTitle(currentTournament)
    }
    
    private func loadSavedData() {
        if let decodedTournaments = try? JSONDecoder().decode([String].self, from: savedTournamentsData) {
            savedTournaments = decodedTournaments
        }
        
        if !currentTournament.isEmpty {
            loadTournamentData(currentTournament)
        }
    }
    
    private func saveData() {
        if let encodedTournaments = try? JSONEncoder().encode(savedTournaments) {
            savedTournamentsData = encodedTournaments
        }
        
        var tournamentData = TournamentData(
            name: currentTournament,
            players: playerNames,
            numberOfRounds: numberOfRounds,
            numberOfCourts: numberOfCourts
        )
        
        // Update tournament data with current state
        tournamentData.matches = schedule
        for match in schedule {
            tournamentData.updateStats(with: match)
        }
        
        if let encodedData = try? JSONEncoder().encode(tournamentData) {
            UserDefaults.standard.set(encodedData, forKey: "tournament_\(currentTournament)")
        }
    }
    
    private func loadTournament(_ tournamentName: String) {
        currentTournament = tournamentName
        loadTournamentData(tournamentName)
        showMainView = true
        isShowingSavedTournaments = false
    }
    
    private func loadTournamentData(_ tournamentName: String) {
        if let savedData = UserDefaults.standard.data(forKey: "tournament_\(tournamentName)"),
           let decodedData = try? JSONDecoder().decode(TournamentData.self, from: savedData) {
            playerNames = decodedData.players
            numberOfRounds = decodedData.scheduler.numberOfRounds
            numberOfCourts = decodedData.scheduler.numberOfCourts
            schedule = decodedData.matches
            leaderboard = decodedData.playerStats
            scheduler = decodedData.scheduler
            
            regenerateRestingPlayers()
        }
    }
    
    private func regenerateRestingPlayers() {
        restingPlayersByRound = [:]
        for round in 0..<numberOfRounds {
            let matchesInRound = schedule.filter { $0.round == round }
            let playersInRound = Set(matchesInRound.flatMap { [$0.team1.player1, $0.team1.player2, $0.team2.player1, $0.team2.player2] })
            let restingPlayers = Set(playerNames).subtracting(playersInRound)
            restingPlayersByRound[round] = Array(restingPlayers)
        }
    }
    
    private func generateSchedule() {
        let seed = UInt64.random(in: 0...UInt64.max)
        scheduler = AmericanoScheduler(players: playerNames.filter { !$0.isEmpty }, numberOfRounds: numberOfRounds, numberOfCourts: numberOfCourts, seed: seed)
        
        if let (newSchedule, newRestingPlayers) = scheduler?.generateSchedule() {
            schedule = newSchedule
            restingPlayersByRound = newRestingPlayers
        leaderboard = Dictionary(uniqueKeysWithValues: playerNames.filter { !$0.isEmpty }.map { ($0, PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)) })
        for (_, restingPlayers) in restingPlayersByRound {
            updateRests(restingPlayers: restingPlayers)
        }
        selectedTab = 1 // Switch to the Schedule tab
        saveData()
        }
    }
    
    private func addRound() {
        guard var scheduler = scheduler else { return }
        if let (newRound, newRestingPlayers) = scheduler.generateAdditionalRound(existingSchedule: schedule) {
        schedule.append(contentsOf: newRound)
        restingPlayersByRound[numberOfRounds] = newRestingPlayers
        updateRests(restingPlayers: newRestingPlayers)
        numberOfRounds += 1
        self.scheduler = scheduler
        saveData()
        }
    }
    
    private func updateLeaderboard(winningTeam: Team, losingTeam: Team, points: Int, differential: Int = 0) {
        leaderboard[winningTeam.player1, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].score += points
        leaderboard[winningTeam.player2, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].score += points
        
        if points > 0 {
            // Update wins and losses
            leaderboard[winningTeam.player1, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].wins += 1
            leaderboard[winningTeam.player2, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].wins += 1
            leaderboard[losingTeam.player1, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].losses += 1
            leaderboard[losingTeam.player2, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].losses += 1
            
            // Update point differentials
            leaderboard[winningTeam.player1, default: PlayerStats()].pointDifferential += differential
            leaderboard[winningTeam.player2, default: PlayerStats()].pointDifferential += differential
            leaderboard[losingTeam.player1, default: PlayerStats()].pointDifferential -= differential
            leaderboard[losingTeam.player2, default: PlayerStats()].pointDifferential -= differential
        } else {
            // Undo previous stats
            leaderboard[winningTeam.player1, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].wins -= 1
            leaderboard[winningTeam.player2, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].wins -= 1
            leaderboard[losingTeam.player1, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].losses -= 1
            leaderboard[losingTeam.player2, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].losses -= 1
            
            // Undo point differentials
            leaderboard[winningTeam.player1, default: PlayerStats()].pointDifferential -= differential
            leaderboard[winningTeam.player2, default: PlayerStats()].pointDifferential -= differential
            leaderboard[losingTeam.player1, default: PlayerStats()].pointDifferential += differential
            leaderboard[losingTeam.player2, default: PlayerStats()].pointDifferential += differential
        }
        
        saveData()
    }
    
    private func updateRests(restingPlayers: [String]) {
        for player in restingPlayers {
            leaderboard[player, default: PlayerStats(score: 0, wins: 0, losses: 0, rests: 0)].rests += 1
        }
        saveData()
    }
    
    private func resetApp() {
        currentTournament = ""
        showMainView = false
        playerNames = ["", "", "", ""]
        numberOfRounds = 3
        pointsPerWin = 1
        numberOfCourts = 1
        schedule = []
        leaderboard = [:]
        scheduler = nil
        selectedTab = 0
        
        // Clear saved data
        savedTournaments = []
        savedTournamentsData = Data()
        
        // Save the cleared data
        saveData()
    }
    
    private func createNewTournament() {
        saveData()  // Save current tournament data before creating a new one
        currentTournament = ""
        showMainView = false
        playerNames = ["", "", "", ""]
        numberOfRounds = 3
        pointsPerWin = 1
        numberOfCourts = 1
        schedule = []
        leaderboard = [:]
        scheduler = nil
        selectedTab = 0
    }
    
    private func deleteTournament(_ tournamentName: String) {
        if let index = savedTournaments.firstIndex(of: tournamentName) {
            savedTournaments.remove(at: index)
        }
        UserDefaults.standard.removeObject(forKey: "tournament_\(tournamentName)")
        saveData()
    }
}

// Add this new view
struct SavedTournamentsView: View {
    let savedTournaments: [String]
    let loadTournament: (String) -> Void
    @Binding var showSavedTournaments: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(savedTournaments, id: \.self) { tournament in
                    Button(action: {
                        loadTournament(tournament)
                    }) {
                        Text(tournament)
                    }
                }
            }
            .navigationTitle("Saved Tournaments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showSavedTournaments = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}