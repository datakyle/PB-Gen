import SwiftUI
import UIKit

struct LeaderboardView: View {
    
    // MARK: - Properties
    @ObservedObject var viewModel: LeaderboardViewModel
    let tournamentName: String
    let onTournamentSelection: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Shared Header
                TabHeaderView(
                    tabName: "LEADERBOARD",
                    tournamentName: tournamentName,
                    onTournamentSelection: onTournamentSelection
                )
                
                if viewModel.isEmpty {
                    EmptyLeaderboardView()
                        .padding(.top, Theme.Spacing.xxl)
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        // Sort Options
                        LeaderboardHeaderView(sortOrder: Binding(
                            get: { viewModel.sortOrder },
                            set: { viewModel.setSortOrder($0) }
                        ))
                        
                        // Leaderboard Cards
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(Array(viewModel.sortedLeaderboard.enumerated()), id: \.element.key) { index, playerData in
                                LeaderboardRowCard(
                                    position: index + 1,
                                    player: playerData.key,
                                    stats: playerData.value
                                )
                            }
                        }
                    }
                }
                
                // Bottom padding to account for floating tab bar
                Spacer()
                    .frame(height: 100)
            }
            .padding(Theme.Spacing.md)
        }
        .animation(.easeInOut(duration: AppConstants.UI.animationDuration), value: viewModel.sortOrder)
    }
}

// MARK: - Leaderboard Header View (Updated for gradient)
struct LeaderboardHeaderView: UIViewRepresentable {
    @Binding var sortOrder: SortOrder
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: ["Name", "Pts", "W", "L", "R"])
        segmentedControl.selectedSegmentIndex = SortOrder.allCases.firstIndex(of: sortOrder) ?? 0
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        
        // Style for white card background
        segmentedControl.backgroundColor = UIColor.systemGray6
        segmentedControl.selectedSegmentTintColor = UIColor.black
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 14, weight: .medium)
        ], for: .normal)
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 14, weight: .bold)
        ], for: .selected)
        
        return segmentedControl
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        uiView.selectedSegmentIndex = SortOrder.allCases.firstIndex(of: sortOrder) ?? 0
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: LeaderboardHeaderView
        
        init(_ parent: LeaderboardHeaderView) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: UISegmentedControl) {
            parent.sortOrder = SortOrder.allCases[sender.selectedSegmentIndex]
        }
    }
}

// MARK: - Leaderboard Row Card
struct LeaderboardRowCard: View {
    let position: Int
    let player: String
    let stats: PlayerStats
    
    private var positionColor: Color {
        switch position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .blue
        }
    }
    
    private var positionIcon: String {
        switch position {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "person.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Position and Icon
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: positionIcon)
                    .foregroundColor(positionColor)
                    .imageScale(.large)
                
                Text("\(position)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(minWidth: 25)
            }
            
            // Player Name
            Text(player)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats
            HStack(spacing: Theme.Spacing.lg) {
                StatItem(label: "Pts", value: "\(stats.pointDifferential)", 
                         color: stats.pointDifferential >= 0 ? .green : .red)
                StatItem(label: "W", value: "\(stats.wins)", color: .black)
                StatItem(label: "L", value: "\(stats.losses)", color: .black)
                StatItem(label: "R", value: "\(stats.rests)", color: .orange)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                .fill(Color.white.opacity(0.9))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 4, x: 0, y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                .stroke(position <= 3 ? positionColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(minWidth: 30)
    }
}

// MARK: - Empty Leaderboard View (Updated)
struct EmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundColor(.black)
            
            Text("No Leaderboard Data")
                .font(Theme.Typography.title2)
                .foregroundColor(.black)
            
            Text("Generate a schedule and play some matches to see the leaderboard.")
                .font(Theme.Typography.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .fill(Color.white.opacity(0.9))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8, x: 0, y: 4
                )
        )
    }
}

#Preview {
    ZStack {
        Theme.Gradients.mainBackground
            .ignoresSafeArea()
        
        LeaderboardView(
            viewModel: LeaderboardViewModel(),
            tournamentName: "Summer Tournament",
            onTournamentSelection: {}
        )
    }
}