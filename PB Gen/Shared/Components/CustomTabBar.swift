import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedIndex: Int
    let items: [String]
    @Namespace private var tabNamespace
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { index in
                TabBarItem(
                    title: items[index],
                    isSelected: selectedIndex == index,
                    namespace: tabNamespace,
                    action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selectedIndex = index
                        }
                    }
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            // Modern Liquid Glass container
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 25, x: 0, y: 15)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
    }
}

struct TabBarItem: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .background(
                    Group {
                        if isSelected {
                            // Smooth morphing selected state
                            Capsule()
                                .fill(.regularMaterial)
                                .overlay(
                                    Capsule()
                                        .fill(Color.white.opacity(0.8))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                                .matchedGeometryEffect(id: "selectedTab", in: namespace)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isSelected)
    }
}

#Preview {
    ZStack {
        // Simulate scrolling content with dynamic colors
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<20) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.6),
                                    Color.purple.opacity(0.4)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 80)
                        .overlay(
                            Text("Content Row \(index + 1)")
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.orange.opacity(0.3),
                    Color.pink.opacity(0.3),
                    Color.purple.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        
        // Floating tab bar overlay
        VStack {
            Spacer()
            CustomTabBar(selectedIndex: .constant(1), items: ["Details", "Schedule", "Leaderboard"])
        }
    }
    .ignoresSafeArea()
}