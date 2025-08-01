import SwiftUI

struct EmptyScheduleView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 20) {
                    Image(systemName: "calendar")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Schedule Generated")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Generate a schedule from the Details tab to get started.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
} 