import SwiftUI
import UIKit

struct LeaderboardView: View {
    let leaderboard: [String: PlayerStats]
    @State private var sortOrder: SortOrder = .score
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if leaderboard.isEmpty {
                    EmptyLeaderboardView()
                } else {
                    LeaderboardHeaderView(sortOrder: $sortOrder)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    List {
                        ForEach(sortedLeaderboard, id: \.key) { player, stats in
                            LeaderboardRowView(player: player, stats: stats)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Leaderboard")
            .animation(.easeInOut, value: sortOrder)
        }
    }
    
    var sortedLeaderboard: [(key: String, value: PlayerStats)] {
        leaderboard.sorted { lhs, rhs in
            switch sortOrder {
            case .name:
                return lhs.key.lowercased() < rhs.key.lowercased()
            case .score:
                if lhs.value.wins == rhs.value.wins {
                    return lhs.value.pointDifferential > rhs.value.pointDifferential
                }
                return lhs.value.wins > rhs.value.wins
            case .wins:
                return lhs.value.wins > rhs.value.wins
            case .losses:
                return lhs.value.losses < rhs.value.losses
            case .rests:
                return lhs.value.rests < rhs.value.rests
            }
        }
    }
}

struct LeaderboardHeaderView: UIViewRepresentable {
    @Binding var sortOrder: SortOrder
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: ["Name", "Pts", "W", "L", "R"])
        segmentedControl.selectedSegmentIndex = SortOrder.allCases.firstIndex(of: sortOrder) ?? 0
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
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

struct LeaderboardRowView: View {
    let player: String
    let stats: PlayerStats
    
    var body: some View {
        HStack {
            Text(player)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(stats.pointDifferential)")
                .frame(maxWidth: .infinity)
                .foregroundColor(stats.pointDifferential >= 0 ? .primary : .red)
            Text("\(stats.wins)")
                .frame(maxWidth: .infinity)
            Text("\(stats.losses)")
                .frame(maxWidth: .infinity)
            Text("\(stats.rests)")
                .frame(maxWidth: .infinity)
        }
        .font(.subheadline)
    }
}

struct EmptyLeaderboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Leaderboard Data")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Generate a schedule and play some matches to see the leaderboard.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}

enum SortOrder: String, CaseIterable {
    case name, score, wins, losses, rests
}