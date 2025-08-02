//
//  TournamentSelectionSheet.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import SwiftUI

struct TournamentSelectionSheet: View {
    let savedTournaments: [String]
    let currentTournament: String
    let onTournamentSelected: (String) -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if savedTournaments.isEmpty {
                    emptyState
                } else {
                    tournamentList
                }
            }
            .navigationTitle("Select Tournament")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Saved Tournaments")
                .font(Theme.Typography.title2)
                .foregroundColor(.black)
            
            Text("Create tournaments in the Details tab to see them here.")
                .font(Theme.Typography.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    var tournamentList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(savedTournaments, id: \.self) { tournament in
                    Button(action: {
                        onTournamentSelected(tournament)
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.orange)
                                .imageScale(.medium)
                            
                            Text(tournament)
                                .font(Theme.Typography.body.weight(.medium))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            if tournament == currentTournament {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .imageScale(.medium)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                    .imageScale(.medium)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                                .fill(tournament == currentTournament ? Color.green.opacity(0.1) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                                        .stroke(tournament == currentTournament ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Color(.systemGray6))
    }
}

#Preview {
    TournamentSelectionSheet(
        savedTournaments: ["Summer Tournament", "Winter League", "Championship"],
        currentTournament: "Summer Tournament",
        onTournamentSelected: { _ in },
        isPresented: .constant(true)
    )
}