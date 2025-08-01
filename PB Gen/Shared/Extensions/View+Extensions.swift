//
//  View+Extensions.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import SwiftUI

extension View {
    
    /// Applies a card-style appearance with shadow and background
    func cardStyle() -> some View {
        self
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Layout.cornerRadius)
            .shadow(
                color: Color.black.opacity(Theme.Layout.shadowOpacity),
                radius: Theme.Layout.shadowRadius,
                x: Theme.Layout.shadowOffset.width,
                y: Theme.Layout.shadowOffset.height
            )
    }
    
    /// Applies consistent button styling
    func primaryButtonStyle() -> some View {
        self
            .font(Theme.Typography.button)
            .foregroundColor(.white)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.primary)
            .cornerRadius(Theme.Layout.cornerRadius)
    }
    
    /// Applies secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .font(Theme.Typography.button)
            .foregroundColor(Theme.Colors.primary)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.primary.opacity(0.1))
            .cornerRadius(Theme.Layout.cornerRadius)
    }
    
    /// Conditional view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}