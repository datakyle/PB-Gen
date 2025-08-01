import SwiftUI
import UIKit

struct CustomTabBar: UIViewRepresentable {
    @Binding var selectedIndex: Int
    let items: [String]

    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = selectedIndex
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return segmentedControl
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        uiView.selectedSegmentIndex = selectedIndex
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CustomTabBar

        init(_ parent: CustomTabBar) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: UISegmentedControl) {
            parent.selectedIndex = sender.selectedSegmentIndex
        }
    }
}