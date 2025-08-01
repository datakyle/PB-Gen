import SwiftUI

struct CreateTournamentView: View {
    @Binding var tournamentName: String
    @Binding var showMainView: Bool
    @Binding var savedTournaments: [String]
    @Binding var isShowingSavedTournaments: Bool
    var loadTournament: (String) -> Void
    var deleteTournament: (String) -> Void
    var resetApp: () -> Void
    
    @State private var showResetWarning = false
    @State private var showResetConfirmation = false
    @FocusState private var isTournamentNameFocused: Bool
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                if isShowingSavedTournaments {
                    savedTournamentsView
                } else {
                    createTournamentView
                }
                
                Spacer()
                
                Text("Americano Tournament Generator")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .onAppear {
            isTournamentNameFocused = !isShowingSavedTournaments
        }

    }
    
    var createTournamentView: some View {
        VStack(spacing: 30) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding(.top, 40)
            
            Text("Simple Tournament Generator")
                .font(.system(size: 28, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            TextField("Enter tournament name", text: $tournamentName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 20)
                .focused($isTournamentNameFocused)
                .submitLabel(.done)
                .onSubmit {
                    createTournament()
                }
            
            Button(action: createTournament) {
                Text("Create")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tournamentName.isEmpty ? Color.gray : Color.accentColor)
                    .cornerRadius(10)
            }
            .disabled(tournamentName.isEmpty)
            .padding(.horizontal, 20)
            
            if !savedTournaments.isEmpty {
                Button(action: { isShowingSavedTournaments = true }) {
                    Text("Load Saved Tournament")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .frame(maxWidth: 400)
        .padding()
    }
    
    var savedTournamentsView: some View {
        NavigationView {
            List {
                ForEach(savedTournaments, id: \.self) { tournament in
                    Button(action: {
                        loadTournament(tournament)
                        isShowingSavedTournaments = false
                        showMainView = true
                    }) {
                        HStack {
                            Image(systemName: "trophy")
                                .foregroundColor(.accentColor)
                            Text(tournament)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTournaments)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Saved Tournaments")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isShowingSavedTournaments = false
                    }
                }
            }
            .overlay(Group {
                if savedTournaments.isEmpty {
                    // Content for empty state
                }
            })
        }
    }
    
    private func createTournament() {
        if !tournamentName.isEmpty {
            if !savedTournaments.contains(tournamentName) {
                savedTournaments.append(tournamentName)
            }
            showMainView = true
            isShowingSavedTournaments = false
        }
    }
    
    private func deleteTournaments(at offsets: IndexSet) {
        for index in offsets {
            deleteTournament(savedTournaments[index])
        }
        savedTournaments.remove(atOffsets: offsets)
    }
}