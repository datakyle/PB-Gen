//
//  TournamentDetailsView.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import SwiftUI

struct TournamentDetailsView: View {
    
    // MARK: - Properties
    @ObservedObject var viewModel: TournamentViewModel
    let tournamentName: String
    
    let onScheduleGenerated: () -> Void
    let onNewTournament: () -> Void
    let onViewSavedTournaments: () -> Void
    let onAppReset: () -> Void
    let onTournamentSelection: () -> Void
    let onCleanupLeaderboard: () -> Void
    
    // MARK: - State
    @FocusState private var focusedField: Int?
    @State private var isEditing: Bool = false
    @State private var showResetConfirmation: Bool = false
    @State private var showResetWarning: Bool = false
    @State private var showInsufficientPlayersAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Shared Header
                TabHeaderView(
                    tabName: "DETAILS",
                    tournamentName: tournamentName,
                    onTournamentSelection: onTournamentSelection
                )
                
                tournamentInfoCard
                playersCard
                duplicateNamesWarning
                gameSettingsCard
                generateScheduleCard
                tournamentManagementCard
                dangerZoneCard
                
                // Bottom padding to account for floating tab bar
                Spacer()
                    .frame(height: 100)
            }
            .padding(Theme.Spacing.md)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation {
                        isEditing.toggle()
                    }
                }
                .foregroundColor(.black)
            }
        }
        .alert("Warning", isPresented: $showResetWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Proceed", role: .destructive) {
                showResetConfirmation = true
            }
        } message: {
            Text("Resetting the app will delete all tournaments and data. This action cannot be undone.")
        }
        .alert("Confirm Reset", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                withAnimation {
                    onAppReset()
                }
            }
        } message: {
            Text("Are you absolutely sure you want to reset the app? All data will be permanently deleted.")
        }
        .alert("Cannot Generate Schedule", isPresented: $showInsufficientPlayersAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter at least \(AppConstants.Tournament.minimumPlayers) player names to generate schedule")
        }
    }
    
    // MARK: - Cards
    @ViewBuilder
    var tournamentInfoCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.orange)
                    .imageScale(.large)
                Text("Tournament Info")
                    .font(Theme.Typography.headline)
                Spacer()
            }
            
            HStack {
                Text("Name:")
                    .font(Theme.Typography.body)
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.tournamentName)
                    .font(Theme.Typography.body.weight(.medium))
            }
        }
        .padding(Theme.Spacing.md)
        .gradientCardStyle()
    }
    
    @ViewBuilder
    var playersCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                    .imageScale(.large)
                Text("Players (\(viewModel.validPlayerCount))")
                    .font(Theme.Typography.headline)
                Spacer()
            }
            
            ForEach(viewModel.playerNames.indices, id: \.self) { index in
                HStack {
                    TextField("Player \(index + 1)", text: $viewModel.playerNames[index])
                        .focused($focusedField, equals: index)
                        .onChange(of: viewModel.playerNames[index]) { _, _ in
                            viewModel.validatePlayerName(at: index)
                        }
                        .foregroundColor(viewModel.duplicateNames.contains(viewModel.playerNames[index]) ? Theme.Colors.error : .primary)
                        .padding(.vertical, Theme.Spacing.xs)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .background(Color(.systemGray6))
                        .cornerRadius(Theme.Layout.cornerRadius - 4)
                    
                    if isEditing && viewModel.playerNames.count > AppConstants.Tournament.minimumPlayers {
                        Button(action: {
                            withAnimation {
                                viewModel.removePlayer(at: IndexSet(integer: index))
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(Theme.Colors.error)
                        }
                        .transition(.scale)
                    }
                }
            }
            
            Button(action: {
                withAnimation(.spring(duration: AppConstants.UI.springAnimation)) {
                    viewModel.addPlayer()
                    focusedField = viewModel.playerNames.count - 1
                }
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Add Player")
                }
                .font(Theme.Typography.body.weight(.medium))
                .foregroundColor(.blue)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.md)
        .gradientCardStyle()
    }
    
    @ViewBuilder
    var duplicateNamesWarning: some View {
        if !viewModel.duplicateNames.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.Colors.error)
                Text("Duplicate names detected")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.error)
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .fill(Theme.Colors.error.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                            .stroke(Theme.Colors.error.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    var gameSettingsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.purple)
                    .imageScale(.large)
                Text("Game Settings")
                    .font(Theme.Typography.headline)
                Spacer()
            }
            
            VStack(spacing: Theme.Spacing.md) {
                // Rounds Setting
                HStack {
                    Text("Rounds:")
                        .font(Theme.Typography.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Button(action: {
                            if viewModel.numberOfRounds > AppConstants.Tournament.minimumRounds {
                                viewModel.numberOfRounds -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.numberOfRounds > AppConstants.Tournament.minimumRounds ? .black : .gray)
                        }
                        .disabled(viewModel.numberOfRounds <= AppConstants.Tournament.minimumRounds)
                        
                        Text("\(viewModel.numberOfRounds)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(minWidth: 30)
                        
                        Button(action: {
                            if viewModel.numberOfRounds < AppConstants.Tournament.maximumRounds {
                                viewModel.numberOfRounds += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.numberOfRounds < AppConstants.Tournament.maximumRounds ? .black : .gray)
                        }
                        .disabled(viewModel.numberOfRounds >= AppConstants.Tournament.maximumRounds)
                    }
                }
                
                // Courts Setting
                HStack {
                    Text("Courts:")
                        .font(Theme.Typography.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Button(action: {
                            if viewModel.numberOfCourts > AppConstants.Tournament.minimumCourts {
                                viewModel.numberOfCourts -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.numberOfCourts > AppConstants.Tournament.minimumCourts ? .black : .gray)
                        }
                        .disabled(viewModel.numberOfCourts <= AppConstants.Tournament.minimumCourts)
                        
                        Text("\(viewModel.numberOfCourts)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(minWidth: 30)
                        
                        Button(action: {
                            if viewModel.numberOfCourts < AppConstants.Tournament.maximumCourts {
                                viewModel.numberOfCourts += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.numberOfCourts < AppConstants.Tournament.maximumCourts ? .black : .gray)
                        }
                        .disabled(viewModel.numberOfCourts >= AppConstants.Tournament.maximumCourts)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .gradientCardStyle()
    }
    
    @ViewBuilder
    var generateScheduleCard: some View {
        Button(action: {
            if viewModel.canGenerateSchedule {
                onScheduleGenerated()
            } else {
                showInsufficientPlayersAlert = true
            }
        }) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .imageScale(.large)
                Text("Generate Schedule")
                    .font(Theme.Typography.button)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.md)
            .background(viewModel.canGenerateSchedule ? Color.black : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(Theme.Layout.cardCornerRadius)
            .shadow(
                color: viewModel.canGenerateSchedule ? Color.black.opacity(0.3) : Color.clear,
                radius: 8, x: 0, y: 4
            )
        }
        .disabled(!viewModel.canGenerateSchedule)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canGenerateSchedule)
    }
    
    @ViewBuilder
    var tournamentManagementCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(action: onNewTournament) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create New Tournament")
                }
                .gradientSecondaryButtonStyle()
            }
            
            Button(action: onViewSavedTournaments) {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("View Saved Tournaments")
                }
                .gradientSecondaryButtonStyle()
            }
        }
    }
    
    @ViewBuilder
    var dangerZoneCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.Colors.error)
                    .imageScale(.large)
                Text("Danger Zone")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.error)
                Spacer()
            }
            
            VStack(spacing: Theme.Spacing.sm) {
                Button(action: { 
                    // Add cleanup action
                    onCleanupLeaderboard()
                }) {
                    HStack {
                        Image(systemName: "trash.circle")
                        Text("Clean Leaderboard")
                    }
                    .font(Theme.Typography.body.weight(.medium))
                    .foregroundColor(.orange)
                    .padding(Theme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(Theme.Layout.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Button(action: { showResetWarning = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset App")
                    }
                    .font(Theme.Typography.body.weight(.medium))
                    .foregroundColor(Theme.Colors.error)
                    .padding(Theme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.error.opacity(0.1))
                    .cornerRadius(Theme.Layout.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                            .stroke(Theme.Colors.error.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .fill(Color.white.opacity(0.95))
                .shadow(
                    color: Theme.Colors.error.opacity(0.2),
                    radius: Theme.Layout.shadowRadius,
                    x: 0, y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .stroke(Theme.Colors.error.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Theme.Gradients.mainBackground
            .ignoresSafeArea()
        
        TournamentDetailsView(
            viewModel: TournamentViewModel(),
            tournamentName: "Summer Tournament",
            onScheduleGenerated: {},
            onNewTournament: {},
            onViewSavedTournaments: {},
            onAppReset: {},
            onTournamentSelection: {},
            onCleanupLeaderboard: {}
        )
    }
}