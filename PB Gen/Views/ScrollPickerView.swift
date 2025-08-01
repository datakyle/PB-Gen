import SwiftUI
import UIKit

struct ScrollPickerView: UIViewRepresentable {
    @Binding var selection: Int
    let range: ClosedRange<Int>
    
    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        
        // Style similar to Timer app
        picker.preferredContentSizeCategory = .large
        
        // Set initial selection
        if range.contains(selection) {
            picker.selectRow(selection - range.lowerBound, inComponent: 0, animated: false)
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: UIPickerView, context: Context) {
        if range.contains(selection) {
            let row = selection - range.lowerBound
            if uiView.selectedRow(inComponent: 0) != row {
                uiView.selectRow(row, inComponent: 0, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        var parent: ScrollPickerView
        
        init(_ parent: ScrollPickerView) {
            self.parent = parent
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 1
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return parent.range.count
        }
        
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            let value = parent.range.lowerBound + row
            return "\(value)"
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            parent.selection = parent.range.lowerBound + row
        }
        
        // Styling similar to Timer app
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = UILabel()
            let value = parent.range.lowerBound + row
            label.text = "\(value)"
            label.textAlignment = .center
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .regular)
            label.textColor = UIColor.label
            return label
        }
        
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            return 60
        }
    }
}

struct RoundSelectorView: View {
    @Binding var selectedRound: Int
    let numberOfRounds: Int
    
    var body: some View {
        HStack {
            Text("Round")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Menu {
                ForEach(0..<numberOfRounds, id: \.self) { round in
                    Button("Round \(round + 1)") {
                        selectedRound = round
                    }
                }
            } label: {
                HStack {
                    Text("Round \(selectedRound + 1)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}