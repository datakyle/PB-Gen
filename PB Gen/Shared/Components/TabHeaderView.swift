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
        VStack(spacing: Theme.Spacing.sm) {
            Text(tabName.uppercased())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .tracking(2)
            
            if !tournamentName.isEmpty {
                Button(action: onTournamentSelection) {
                    HStack {
                        Text(tournamentName.uppercased())
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.black)
                            .imageScale(.medium)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                            .fill(Color.white.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.Gradients.mainBackground
            .ignoresSafeArea()
        
        TabHeaderView(
            tabName: "SCHEDULE",
            tournamentName: "Summer Tournament",
            onTournamentSelection: {}
        )
        .padding()
    }
}