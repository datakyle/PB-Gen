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
    
    let onScheduleGenerated: () -> Void
    let onNewTournament: () -> Void
    let onViewSavedTournaments: () -> Void
    let onAppReset: () -> Void
    
    // MARK: - State
    @FocusState private var focusedField: Int?
    @State private var isEditing: Bool = false
    @State private var showResetConfirmation: Bool = false
    @State private var showResetWarning: Bool = false
    @State private var showInsufficientPlayersAlert: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                tournamentInfoSection
                playersSection
                duplicateNamesWarning
                gameSettingsSection
                generateScheduleSection
                tournamentManagementSection
                dangerZoneSection
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Tournament Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
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
    }
    
    // MARK: - Sections
    @ViewBuilder
    var tournamentInfoSection: some View {
        Section(header: Text("Tournament Info")) {
            HStack {
                Label("Name", systemImage: "trophy")
                Spacer()
                Text(viewModel.tournamentName)
                    .foregroundColor(Theme.Colors.secondary)
            }
        }
    }
    
    @ViewBuilder
    var playersSection: some View {
        Section(header: Text("Players (\(viewModel.validPlayerCount))")) {
            ForEach(viewModel.playerNames.indices, id: \.self) { index in
                HStack {
                    TextField("Player \(index + 1)", text: $viewModel.playerNames[index])
                        .focused($focusedField, equals: index)
                        .onChange(of: viewModel.playerNames[index]) { _, _ in
                            viewModel.validatePlayerName(at: index)
                        }
                        .foregroundColor(viewModel.duplicateNames.contains(viewModel.playerNames[index]) ? Theme.Colors.error : .primary)
                    
                    if isEditing {
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
            .onDelete { offsets in
                viewModel.removePlayer(at: offsets)
            }
            
            Button(action: {
                withAnimation(.spring(duration: AppConstants.UI.springAnimation)) {
                    viewModel.addPlayer()
                    focusedField = viewModel.playerNames.count - 1
                }
            }) {
                Label("Add Player", systemImage: "person.badge.plus")
            }
        }
    }
    
    @ViewBuilder
    var duplicateNamesWarning: some View {
        if !viewModel.duplicateNames.isEmpty {
            Section {
                Label("Duplicate names detected", systemImage: "exclamationmark.triangle")
                    .foregroundColor(Theme.Colors.error)
            }
        }
    }
    
    @ViewBuilder
    var gameSettingsSection: some View {
        Section(header: Text("Game Settings")) {
            Stepper("Rounds: \(viewModel.numberOfRounds)", 
                   value: $viewModel.numberOfRounds, 
                   in: AppConstants.Tournament.minimumRounds...AppConstants.Tournament.maximumRounds)
            
            Stepper("Courts: \(viewModel.numberOfCourts)", 
                   value: $viewModel.numberOfCourts, 
                   in: AppConstants.Tournament.minimumCourts...AppConstants.Tournament.maximumCourts)
        }
    }
    
    @ViewBuilder
    var generateScheduleSection: some View {
        Section {
            Button(action: {
                if viewModel.canGenerateSchedule {
                    onScheduleGenerated()
                } else {
                    showInsufficientPlayersAlert = true
                }
            }) {
                HStack {
                    Spacer()
                    Label("Generate Schedule", systemImage: "calendar")
                    Spacer()
                }
            }
            .listRowBackground(viewModel.canGenerateSchedule ? Theme.Colors.primary : Theme.Colors.secondary)
            .foregroundColor(.white)
            .font(Theme.Typography.button)
        }
    }
    
    @ViewBuilder
    var tournamentManagementSection: some View {
        Section {
            Button(action: onNewTournament) {
                Label("Create New Tournament", systemImage: "plus.circle")
            }
            
            Button(action: onViewSavedTournaments) {
                Label("View Saved Tournaments", systemImage: "folder")
            }
        }
    }
    
    @ViewBuilder
    var dangerZoneSection: some View {
        Section {
            Button(action: { showResetWarning = true }) {
                Label("Reset App", systemImage: "arrow.counterclockwise")
                    .foregroundColor(Theme.Colors.error)
            }
        }
    }
}

#Preview {
    TournamentDetailsView(
        viewModel: TournamentViewModel(),
        onScheduleGenerated: {},
        onNewTournament: {},
        onViewSavedTournaments: {},
        onAppReset: {}
    )
}