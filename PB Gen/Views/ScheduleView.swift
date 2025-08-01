import SwiftUI

struct ScheduleView: View {
    @Binding var schedule: [Match]
    let playerNames: [String]
    @Binding var numberOfRounds: Int
    let pointsPerWin: Int
    let updateLeaderboard: (Team, Team, Int, Int) -> Void
    let addRound: () -> Void
    let restingPlayersByRound: [Int: [String]]
    
    @State private var selectedRound = 0
    @State private var animateNewRound = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !schedule.isEmpty {
                    RoundSelectorView(selectedRound: $selectedRound, numberOfRounds: numberOfRounds)
                        .background(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                }
                
                List {
                    if schedule.isEmpty {
                        EmptyScheduleView()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        // Show only selected round
                        Section {
                            ForEach(schedule.filter { $0.round == selectedRound }, id: \.id) { match in
                                MatchView(match: binding(for: match), 
                                    pointsPerWin: pointsPerWin,
                                        updateLeaderboard: updateLeaderboard)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                            
                            if let restingPlayers = restingPlayersByRound[selectedRound], !restingPlayers.isEmpty {
                                RestingPlayersView(players: restingPlayers)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                            }
                        } header: {
                            Text("Round \(selectedRound + 1) Matches")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.primary)
                                .textCase(nil)
                                .padding(.bottom, 8)
                        }
                        
                        Section {
                            Button(action: {
                                withAnimation(.spring()) {
                                    addRound()
                                    animateNewRound = true
                                    // Auto-select the new round
                                    selectedRound = numberOfRounds - 1
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .imageScale(.medium)
                                    Text("Add Round")
                                        .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .scaleEffect(animateNewRound ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: animateNewRound)
                            .onChange(of: animateNewRound) { _, newValue in
                                if newValue {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        animateNewRound = false
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Schedule")
            .onChange(of: numberOfRounds) { _, newValue in
                // Ensure selectedRound is valid when rounds change
                if selectedRound >= newValue {
                    selectedRound = max(0, newValue - 1)
                }
            }
        }
        .onAppear {
            print("ScheduleView appeared")
            print("Total matches: \(schedule.count)")
            print("Number of rounds: \(numberOfRounds)")
            for round in 0..<numberOfRounds {
                let matchesInRound = schedule.filter { $0.round == round }
                print("Matches in Round \(round + 1): \(matchesInRound.count)")
            }
        }
    }
    
    private func binding(for match: Match) -> Binding<Match> {
        Binding(
            get: { match },
            set: { newValue in
                if let index = schedule.firstIndex(where: { $0.id == match.id }) {
                    schedule[index] = newValue
                }
            }
        )
    }
}

struct MatchView: View {
    @Binding var match: Match
    let pointsPerWin: Int
    let updateLeaderboard: (Team, Team, Int, Int) -> Void
    
    @State private var team1Score = 0
    @State private var team2Score = 0
    @State private var isEditing = false
    @State private var showScorePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
        HStack {
                Text("Court \(match.court)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !isEditing && match.team1Score == 0 && match.team2Score == 0 {
                    Text("No Scores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
            }
            
            VStack(spacing: 12) {
                TeamScoreRow(
                    team: match.team1,
                    score: match.team1Score,
                    isWinner: match.winningTeam == 1,
                    isEditing: isEditing
                )
                
                Divider()
                    .opacity(0.5)
                
                TeamScoreRow(
                    team: match.team2,
                    score: match.team2Score,
                    isWinner: match.winningTeam == 2,
                    isEditing: isEditing
                )
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if isEditing {
                HStack {
                    Button("Cancel") {
                        isEditing = false
                        team1Score = match.team1Score
                        team2Score = match.team2Score
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    
            Spacer()
                    
                    Button("Enter Scores") {
                        showScorePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            } else {
                Button {
                    team1Score = match.team1Score
                    team2Score = match.team2Score
                    isEditing = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text(match.team1Score == 0 && match.team2Score == 0 ? "Enter Scores" : "Edit Scores")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showScorePicker) {
            ScorePickerView(
                team1: match.team1,
                team2: match.team2,
                team1Score: $team1Score,
                team2Score: $team2Score,
                onSave: {
                    submitScores()
                    showScorePicker = false
                    isEditing = false
                },
                onCancel: {
                    showScorePicker = false
                    team1Score = match.team1Score
                    team2Score = match.team2Score
                }
            )
        }
    }
    
    private func submitScores() {
        let differential = abs(team1Score - team2Score)
        
        var updatedMatch = match
        updatedMatch.team1Score = team1Score
        updatedMatch.team2Score = team2Score
        
        if team1Score > team2Score {
            updatedMatch.winningTeam = 1
            updateLeaderboard(match.team1, match.team2, pointsPerWin, differential)
        } else if team2Score > team1Score {
            updatedMatch.winningTeam = 2
            updateLeaderboard(match.team2, match.team1, pointsPerWin, differential)
        }
        
        match = updatedMatch
    }
}

struct TeamScoreRow: View {
    let team: Team
    let score: Int
    let isWinner: Bool
    let isEditing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(team.player1) & \(team.player2)")
                .font(.body.weight(isWinner ? .semibold : .regular))
                .foregroundStyle(isWinner ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            if score > 0 {
                Text("\(score)")
                    .font(.headline)
                    .foregroundStyle(isWinner ? .primary : .secondary)
                    .monospacedDigit()
            }
            
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.large)
            }
        }
    }
}

struct ScorePickerView: View {
    let team1: Team
    let team2: Team
    @Binding var team1Score: Int
    @Binding var team2Score: Int
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Team names header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Team 1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(team1.player1) & \(team1.player2)")
                                .font(.headline)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Team 2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(team2.player1) & \(team2.player2)")
                                .font(.headline)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Score pickers
                HStack(spacing: 0) {
                    VStack {
                        Text("Team 1 Score")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        ScrollPickerView(selection: $team1Score, range: 0...50)
                            .frame(height: 200)
                    }
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1)
                        .padding(.vertical, 20)
                    
                    VStack {
                        Text("Team 2 Score")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        ScrollPickerView(selection: $team2Score, range: 0...50)
                            .frame(height: 200)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Enter Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(team1Score == 0 && team2Score == 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct RestingPlayersView: View {
    let players: [String]
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill.questionmark")
                .foregroundStyle(.secondary)
        Text("Resting: \(players.joined(separator: ", "))")
            .font(.subheadline)
                .foregroundStyle(.secondary)
        }
                    .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}