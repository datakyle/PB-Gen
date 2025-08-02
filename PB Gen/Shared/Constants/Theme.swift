//
//  Theme.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import SwiftUI

struct Theme {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.blue
        static let secondary = Color.gray
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.systemGray6)
        static let cardBackground = Color(.systemBackground)
        static let borderColor = Color(.systemGray4)
        
        // MARK: - Gradient Colors
        static let gradientTop = Color(red: 1.0, green: 0.95, blue: 0.75)      // Light cream/yellow
        static let gradientMiddle = Color(red: 1.0, green: 0.85, blue: 0.4)     // Golden yellow
        static let gradientBottom = Color(red: 0.9, green: 0.3, blue: 0.9)      // Vibrant pink/magenta
        
        // MARK: - UI on Gradient
        static let onGradientPrimary = Color.white
        static let onGradientSecondary = Color.white.opacity(0.8)
        static let onGradientBackground = Color.white.opacity(0.95)
        static let onGradientCard = Color.white.opacity(0.9)
        static let onGradientBorder = Color.white.opacity(0.3)
    }
    
    // MARK: - Gradients
    struct Gradients {
        static let mainBackground = LinearGradient(
            gradient: Gradient(colors: [
                Colors.gradientTop,
                Colors.gradientMiddle,
                Colors.gradientBottom
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let cardOverlay = LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.95),
                Color.white.opacity(0.85)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold) 
        static let title2 = Font.title2.weight(.semibold)
        static let headline = Font.headline.weight(.medium)
        static let body = Font.body
        static let caption = Font.caption.weight(.medium)
        static let button = Font.headline.weight(.semibold)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Layout
    struct Layout {
        static let cornerRadius: CGFloat = 16
        static let cardCornerRadius: CGFloat = 20
        static let borderWidth: CGFloat = 1
        static let shadowRadius: CGFloat = 12
        static let shadowOffset = CGSize(width: 0, height: 4)
        static let shadowOpacity: Double = 0.15
        static let blurRadius: CGFloat = 20
    }
}