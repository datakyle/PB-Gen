import SwiftUI

struct DetailsView: View {
    @Binding var tournamentName: String
    @Binding var playerNames: [String]
    @Binding var numberOfRounds: Int
    @Binding var pointsPerWin: Int
    @Binding var numberOfCourts: Int
    let generateSchedule: () -> Void
    let resetApp: () -> Void
    var saveData: () -> Void
    var createNewTournament: () -> Void
    var viewSavedTournaments: () -> Void
    
    @FocusState private var focusedField: Int?
    @State private var duplicateNames: Set<String> = []
    @State private var isEditing: Bool = false
    @State private var showResetConfirmation: Bool = false
    @State private var showResetWarning: Bool = false
    @State private var showInsufficientPlayersAlert: Bool = false
    
    var canGenerateSchedule: Bool {
        playerNames.filter { !$0.isEmpty }.count >= 4 && duplicateNames.isEmpty
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Tournament Info")) {
                    HStack {
                        Label("Name", systemImage: "trophy")
                        Spacer()
                        Text(tournamentName)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Players")) {
                    ForEach(playerNames.indices, id: \.self) { index in
                        HStack {
                            TextField("Player \(index + 1)", text: $playerNames[index])
                                .focused($focusedField, equals: index)
                                .onChange(of: playerNames[index]) { _, _ in
                                    checkForDuplicates()
                                }
                                .foregroundColor(duplicateNames.contains(playerNames[index]) ? .red : .primary)
                            
                            if isEditing {
                                Button(action: {
                                    withAnimation {
                                        deletePlayer(at: IndexSet(integer: index))
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .transition(.scale)
                            }
                        }
                    }
                    .onDelete(perform: deletePlayer)
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            playerNames.append("")
                            focusedField = playerNames.count - 1
                        }
                    }) {
                        Label("Add Player", systemImage: "person.badge.plus")
                    }
                }
                
                if !duplicateNames.isEmpty {
                    Section {
                        Label("Duplicate names detected", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Game Settings")) {
                    Stepper("Rounds: \(numberOfRounds)", value: $numberOfRounds, in: 1...10)
                    Stepper("Courts: \(numberOfCourts)", value: $numberOfCourts, in: 1...5)
                }
                
                Section {
                    Button(action: {
                        if canGenerateSchedule {
                            generateSchedule()
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
                    .listRowBackground(canGenerateSchedule ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .font(.headline)
                }
                
                Section {
                    Button(action: createNewTournament) {
                        Label("Create New Tournament", systemImage: "plus.circle")
                    }
                    
                    Button(action: viewSavedTournaments) {
                        Label("View Saved Tournaments", systemImage: "folder")
                    }
                }
                
                Section {
                    Button(action: { showResetWarning = true }) {
                        Label("Reset App", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Tournament Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation {
                            isEditing.toggle()
                        }
                        saveData()
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
                        resetApp()
                    }
                }
            } message: {
                Text("Are you absolutely sure you want to reset the app? All data will be permanently deleted.")
            }
            .alert("Cannot Generate Schedule", isPresented: $showInsufficientPlayersAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter at least 4 player names to generate schedule")
            }
        }
        .onChange(of: playerNames) { _, _ in saveData() }
        .onChange(of: numberOfRounds) { _, _ in saveData() }
        .onChange(of: pointsPerWin) { _, _ in saveData() }
        .onChange(of: numberOfCourts) { _, _ in saveData() }
    }
    
    private func deletePlayer(at offsets: IndexSet) {
        // Ensure we don't delete if it would leave us with less than 4 slots
        let remainingCount = playerNames.count - offsets.count
        if remainingCount < 4 {
            // Add empty slots to maintain minimum of 4
            let slotsToAdd = 4 - remainingCount
            playerNames.append(contentsOf: Array(repeating: "", count: slotsToAdd))
        }
        
        playerNames.remove(atOffsets: offsets)
        checkForDuplicates()
    }
    
    private func checkForDuplicates() {
        let nonEmptyNames = playerNames.filter { !$0.isEmpty }
        let nameCounts = Dictionary(nonEmptyNames.map { ($0, 1) }, uniquingKeysWith: +)
        duplicateNames = Set(nameCounts.filter { $0.value > 1 }.keys)
    }
}