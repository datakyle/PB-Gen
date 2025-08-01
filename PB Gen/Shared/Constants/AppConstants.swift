//
//  AppConstants.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import Foundation

struct AppConstants {
    
    // MARK: - Tournament Configuration
    struct Tournament {
        static let minimumPlayers = 4
        static let maximumPlayers = 100
        static let minimumRounds = 1
        static let maximumRounds = 10
        static let minimumCourts = 1
        static let maximumCourts = 5
        static let defaultRounds = 3
        static let defaultCourts = 1
        static let defaultPointsPerWin = 1
    }
    
    // MARK: - Storage Keys
    struct StorageKeys {
        static let currentTournament = "currentTournament"
        static let showMainView = "showMainView"
        static let savedTournaments = "savedTournaments"
        static func tournamentKey(_ name: String) -> String {
            return "tournament_\(name)"
        }
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        static let animationDuration: Double = 0.3
        static let springAnimation = 0.6
    }
    
    // MARK: - Accessibility
    struct Accessibility {
        static let minimumTapTarget: CGFloat = 44
        static let preferredMaxLayoutWidth: CGFloat = 400
    }
}