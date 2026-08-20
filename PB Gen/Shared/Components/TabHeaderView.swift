//
//  TabHeaderView.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import SwiftUI

struct TabHeaderView: View {
    let tabName: String
    let tournamentName: String
    let onTournamentSelection: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            // Tab name on the left
            Text(tabName.uppercased())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .tracking(2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tournament selector on the right
            if !tournamentName.isEmpty {
                Button(action: onTournamentSelection) {
                    HStack(spacing: Theme.Spacing.sm) {
                        // Tournament icon
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                        
                        // Tournament name
                        Text(tournamentName.uppercased())
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        // Dropdown indicator
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack {
        Theme.Gradients.mainBackground
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            TabHeaderView(
                tabName: "SCHEDULE",
                tournamentName: "Summer Championship Tournament",
                onTournamentSelection: {}
            )
            
            TabHeaderView(
                tabName: "LEADERBOARD", 
                tournamentName: "Test",
                onTournamentSelection: {}
            )
            
            TabHeaderView(
                tabName: "DETAILS",
                tournamentName: "Winter Tournament Series 2024",
                onTournamentSelection: {}
            )
        }
        .padding()
    }
}