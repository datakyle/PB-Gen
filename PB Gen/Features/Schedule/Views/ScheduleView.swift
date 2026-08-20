import SwiftUI

struct ScheduleView: View {
    
    // MARK: - Properties
    @ObservedObject var viewModel: ScheduleViewModel
    let tournamentName: String
    let onTournamentSelection: () -> Void
    @State private var expandedRounds: Set<Int> = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Shared Header
                TabHeaderView(
                    tabName: "SCHEDULE",
                    tournamentName: tournamentName,
                    onTournamentSelection: onTournamentSelection
                )
                
                if viewModel.schedule.isEmpty {
                    EmptyScheduleView()
                        .padding(.top, Theme.Spacing.xxl)
                } else {
                    // Rounds
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(0..<viewModel.numberOfRounds, id: \.self) { round in
                            ExpandableRoundCard(
                                round: round,
                                viewModel: viewModel,
                                isExpanded: Binding(
                                    get: { expandedRounds.contains(round) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedRounds.insert(round)
                                        } else {
                                            expandedRounds.remove(round)
                                        }
                                    }
                                )
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.numberOfRounds)
                        }
                    }
                    
                    // Add Round Button
                    AddRoundButton(viewModel: viewModel)
                        .padding(.top, Theme.Spacing.md)
                }
                
                // Bottom padding to account for floating tab bar
                Spacer()
                    .frame(height: 100)
            }
            .padding(Theme.Spacing.md)
        }
    }
}

// MARK: - Expandable Round Card
struct ExpandableRoundCard: View {
    let round: Int
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var isExpanded: Bool
    
    private var matches: [Match] {
        viewModel.matchesForRound(round)
    }
    
    private var restingPlayers: [String] {
        viewModel.restingPlayersForRound(round)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Header (Always Visible)
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                RoundCardHeader(
                    round: round,
                    matches: matches,
                    isExpanded: isExpanded
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable Content
            if isExpanded {
                RoundCardContent(
                    matches: matches,
                    restingPlayers: restingPlayers,
                    onScoreUpdate: { match, team1Score, team2Score in
                        viewModel.processScoreUpdate(for: match, team1Score: team1Score, team2Score: team2Score)
                        viewModel.updateMatch(match)
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .fill(Color.white.opacity(0.9))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8, x: 0, y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Round Card Header
struct RoundCardHeader: View {
    let round: Int
    let matches: [Match]
    let isExpanded: Bool
    
    private var previewText: String {
        if matches.isEmpty {
            return "No matches"
        } else if matches.count == 1 {
            let match = matches[0]
            return "\(match.team1.player1) & \(match.team1.player2) vs \(match.team2.player1) & \(match.team2.player2)"
        } else {
            return "\(matches.count) matches"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("RD \(round + 1)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                if !isExpanded {
                    Text(previewText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Score Summary or Expand Icon
            if !isExpanded && !matches.isEmpty {
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    if let firstMatch = matches.first, firstMatch.team1Score > 0 || firstMatch.team2Score > 0 {
                        Text("\(firstMatch.team1Score) - \(firstMatch.team2Score)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            } else {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
        .padding(Theme.Spacing.md)
    }
}

// MARK: - Round Card Content
struct RoundCardContent: View {
    let matches: [Match]
    let restingPlayers: [String]
    let onScoreUpdate: (Match, Int, Int) -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Matches
            ForEach(matches, id: \.id) { match in
                ExpandedMatchView(
                    match: match,
                    onScoreUpdate: onScoreUpdate
                )
            }
            
            // Resting Players
            if !restingPlayers.isEmpty {
                RestingPlayersExpandedView(players: restingPlayers)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }
}

// MARK: - Expanded Match View (Updated with Score Pickers)
struct ExpandedMatchView: View {
    let match: Match
    let onScoreUpdate: (Match, Int, Int) -> Void
    
    @State private var team1Score: Int
    @State private var team2Score: Int
    @State private var updatedMatch: Match
    
    init(match: Match, onScoreUpdate: @escaping (Match, Int, Int) -> Void) {
        self.match = match
        self.onScoreUpdate = onScoreUpdate
        self._updatedMatch = State(initialValue: match)
        self._team1Score = State(initialValue: match.team1Score)
        self._team2Score = State(initialValue: match.team2Score)
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Court Number
            HStack {
                Text("Court \(match.court)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            // Team 1
            HStack {
                Text("\(match.team1.player1) & \(match.team1.player2)")
                    .font(.system(size: 16, weight: updatedMatch.winningTeam == 1 ? .bold : .medium))
                    .foregroundColor(updatedMatch.winningTeam == 1 ? .black : .gray)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: Theme.Spacing.sm) {
                    ScorePickerButton(score: $team1Score)
                        .onChange(of: team1Score) { _, _ in updateScores() }
                    
                    if updatedMatch.winningTeam == 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .imageScale(.medium)
                    }
                }
            }
            
            // VS Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("VS")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, Theme.Spacing.sm)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Team 2
            HStack {
                Text("\(match.team2.player1) & \(match.team2.player2)")
                    .font(.system(size: 16, weight: updatedMatch.winningTeam == 2 ? .bold : .medium))
                    .foregroundColor(updatedMatch.winningTeam == 2 ? .black : .gray)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: Theme.Spacing.sm) {
                    ScorePickerButton(score: $team2Score)
                        .onChange(of: team2Score) { _, _ in updateScores() }
                    
                    if updatedMatch.winningTeam == 2 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .imageScale(.medium)
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(Theme.Layout.cornerRadius)
    }
    
    private func updateScores() {
        guard team1Score >= 0,
              team2Score >= 0,
              team1Score != team2Score else { 
            return 
        }
        
        // Only update if scores have actually changed
        if updatedMatch.team1Score != team1Score || updatedMatch.team2Score != team2Score {
            updatedMatch.team1Score = team1Score
            updatedMatch.team2Score = team2Score
            
            if team1Score > team2Score {
                updatedMatch.winningTeam = 1
            } else if team2Score > team1Score {
                updatedMatch.winningTeam = 2
            }
            
            onScoreUpdate(updatedMatch, team1Score, team2Score)
        }
    }
}

// MARK: - Resting Players Expanded View
struct RestingPlayersExpandedView: View {
    let players: [String]
    
    var body: some View {
        HStack {
            Image(systemName: "figure.seated")
                .foregroundColor(.orange)
                .imageScale(.medium)
            
            Text("Resting: \(players.joined(separator: ", "))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(Theme.Layout.cornerRadius)
    }
}

// MARK: - Add Round Button (Enhanced with error handling)
struct AddRoundButton: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(action: {
                if viewModel.canAddRound() {
                    viewModel.addRound()
                } else if viewModel.addRoundError != nil {
                    showingError = true
                }
            }) {
                HStack {
                    if viewModel.isAddingRound {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.medium)
                    }
                    
                    Text(viewModel.isAddingRound ? "Adding Round..." : "Add Round")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(viewModel.canAddRound() ? Color.black : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(Theme.Layout.cardCornerRadius)
                .shadow(
                    color: viewModel.canAddRound() ? Color.black.opacity(0.3) : Color.clear,
                    radius: 8, x: 0, y: 4
                )
            }
            .disabled(!viewModel.canAddRound())
            .scaleEffect(viewModel.animateNewRound ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.animateNewRound)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isAddingRound)
            
            // Error message
            if let error = viewModel.addRoundError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.md)
                    .transition(.opacity)
            }
        }
        .alert("Unable to Add Round", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(viewModel.addRoundError ?? "An error occurred while adding a new round.")
        }
    }
}

#Preview {
    ZStack {
        Theme.Gradients.mainBackground
            .ignoresSafeArea()
        
        ScheduleView(
            viewModel: ScheduleViewModel(pointsPerWin: 1) { _, _, _, _ in },
            tournamentName: "Summer Tournament",
            onTournamentSelection: {}
        )
    }
}