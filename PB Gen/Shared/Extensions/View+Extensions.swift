//
//  View+Extensions.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import SwiftUI

extension View {
    
    /// Applies the main gradient background
    func gradientBackground() -> some View {
        self
            .background(
                Theme.Gradients.mainBackground
                    .ignoresSafeArea()
            )
    }
    
    /// Applies a card-style appearance with shadow and background optimized for gradient
    func gradientCardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .fill(Theme.Colors.onGradientCard)
                    .shadow(
                        color: Color.black.opacity(Theme.Layout.shadowOpacity),
                        radius: Theme.Layout.shadowRadius,
                        x: Theme.Layout.shadowOffset.width,
                        y: Theme.Layout.shadowOffset.height
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .stroke(Theme.Colors.onGradientBorder, lineWidth: Theme.Layout.borderWidth)
            )
    }
    
    /// Applies a glass morphism effect
    func glassMorphismEffect() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .fill(Theme.Colors.onGradientCard)
                    .blur(radius: Theme.Layout.blurRadius, opaque: false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }
    
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
    
    /// Applies consistent button styling for gradient background
    func gradientPrimaryButtonStyle() -> some View {
        self
            .font(Theme.Typography.button)
            .foregroundColor(Theme.Colors.onGradientPrimary)
            .padding(Theme.Spacing.md)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(Theme.Layout.cornerRadius)
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
    
    /// Applies secondary button styling for gradient background
    func gradientSecondaryButtonStyle() -> some View {
        self
            .font(Theme.Typography.button)
            .foregroundColor(Theme.Colors.onGradientPrimary)
            .padding(Theme.Spacing.md)
            .background(Color.white.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
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