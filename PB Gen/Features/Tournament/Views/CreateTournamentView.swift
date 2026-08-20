import SwiftUI

enum TournamentType: String, CaseIterable {
    case americano = "Americano"
    case single = "Single Elimination"
    case double = "Double Elimination"
    
    var isEnabled: Bool {
        switch self {
        case .americano:
            return true
        case .single, .double:
            return false // Coming soon
        }
    }
}

struct CreateTournamentView: View {
    
    // MARK: - Properties
    @ObservedObject var viewModel: TournamentViewModel
    @Binding var isShowingSavedTournaments: Bool
    
    let onTournamentCreated: (String) -> Void
    let onTournamentLoaded: (String) -> Void
    let onTournamentDeleted: (String) -> Void
    let onAppReset: () -> Void
    
    // MARK: - State
    @State private var selectedTournamentType: TournamentType = .americano
    @State private var tournamentName: String = ""
    @FocusState private var isTournamentNameFocused: Bool
    
    private var canStart: Bool {
        !tournamentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedTournamentType.isEnabled
    }
    
    var body: some View {
        ZStack {
            if isShowingSavedTournaments {
                savedTournamentsView
            } else {
                createTournamentView
            }
        }
        .onAppear {
            viewModel.loadSavedTournaments()
        }
    }
    
    // MARK: - Create Tournament View
    var createTournamentView: some View {
        VStack(spacing: 0) {
            // Header with App Name and Settings
            HStack {
                // Back/Saved Tournaments Arrow Button
                Button(action: {
                    isShowingSavedTournaments = true
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                }
                .opacity(viewModel.savedTournaments.isEmpty ? 0.5 : 1.0)
                .disabled(viewModel.savedTournaments.isEmpty)
                
                Spacer()
                
                // App Title
                Text("PB GEN")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .tracking(3)
                
                Spacer()
                
                // Invisible spacer to balance layout
                Circle()
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
            
            Spacer()
            
            // Main Content Area
            VStack(spacing: Theme.Spacing.xxl) {
                // Tournament Type Selector Card
                VStack(spacing: Theme.Spacing.lg) {
                    Text("What kind of tournament\nwould you like to create?")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    // Tournament Type Buttons
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(TournamentType.allCases, id: \.self) { type in
                            Button(action: {
                                if type.isEnabled {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedTournamentType = type
                                    }
                                }
                            }) {
                                Text(type.rawValue)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(selectedTournamentType == type ? .white : (type.isEnabled ? .black : .gray))
                                    .padding(.horizontal, Theme.Spacing.lg)
                                    .padding(.vertical, Theme.Spacing.md)
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedTournamentType == type ? Color.black : Color.gray.opacity(type.isEnabled ? 0.1 : 0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(type.isEnabled ? 0.2 : 0.1), lineWidth: 1)
                                            )
                                    )
                            }
                            .disabled(!type.isEnabled)
                            .scaleEffect(selectedTournamentType == type ? 1.02 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTournamentType)
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, Theme.Spacing.lg)
                
                // Tournament Name Input
                VStack(spacing: Theme.Spacing.md) {
                    Text("NAME OF TOURNAMENT")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .tracking(1.5)
                    
                    TextField("TYPE BAR", text: $tournamentName)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.thinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .focused($isTournamentNameFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if canStart {
                                createTournament()
                            }
                        }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            
            Spacer()
            
            // Start Button
            Button(action: createTournament) {
                VStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(canStart ? Color.black : Color.white)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(canStart ? 0 : 0.3), lineWidth: 1)
                            )
                            .shadow(
                                color: canStart ? Color.black.opacity(0.3) : Color.gray.opacity(0.2),
                                radius: canStart ? 20 : 8,
                                x: 0,
                                y: canStart ? 8 : 4
                            )
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(canStart ? .white : .gray)
                    }
                    
                    Text("START")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(canStart ? .black : .gray)
                        .tracking(2)
                }
            }
            .disabled(!canStart)
            .scaleEffect(canStart ? 1.05 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: canStart)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }
    
    // MARK: - Saved Tournaments View
    var savedTournamentsView: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                
                if viewModel.savedTournaments.isEmpty {
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: "folder")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Saved Tournaments")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("Create your first tournament to get started!")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(Theme.Spacing.xl)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(viewModel.savedTournaments, id: \.self) { tournament in
                                Button(action: {
                                    onTournamentLoaded(tournament)
                                }) {
                                    HStack {
                                        Image(systemName: "trophy.fill")
                                            .foregroundColor(.orange)
                                            .imageScale(.medium)
                                        
                                        Text(tournament)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.black)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(Theme.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .onDelete(perform: deleteTournaments)
                        }
                        .padding(Theme.Spacing.md)
                    }
                }
            }
            .navigationTitle("Saved Tournaments")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.savedTournaments.isEmpty {
                        EditButton()
                            .foregroundColor(.black)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isShowingSavedTournaments = false
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func createTournament() {
        guard canStart else { return }
        
        let trimmedName = tournamentName.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.tournamentName = trimmedName
        onTournamentCreated(trimmedName)
    }
    
    private func deleteTournaments(at offsets: IndexSet) {
        for index in offsets {
            onTournamentDeleted(viewModel.savedTournaments[index])
        }
    }
}

#Preview {
    ZStack {
        Theme.Gradients.mainBackground
            .ignoresSafeArea()
        
        CreateTournamentView(
            viewModel: TournamentViewModel(),
            isShowingSavedTournaments: .constant(false),
            onTournamentCreated: { _ in },
            onTournamentLoaded: { _ in },
            onTournamentDeleted: { _ in },
            onAppReset: { }
        )
    }
}