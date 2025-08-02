//
//  ScorePicker.swift
//  PB Gen - Americano Tournament Generator
//
//  Created on 2025-01-01.
//

import SwiftUI

struct ScorePicker: View {
    @Binding var score: Int
    let maxScore: Int = 21
    
    var body: some View {
        Picker("Score", selection: $score) {
            ForEach(0...maxScore, id: \.self) { number in
                Text("\(number)")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .tag(number)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 60, height: 100)
        .clipped()
    }
}

struct ScorePickerButton: View {
    @Binding var score: Int
    @State private var showingPicker = false
    let maxScore: Int = 21
    
    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            Text("\(score)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 40, height: 32)
                .background(Color(.systemGray6))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .sheet(isPresented: $showingPicker) {
            NavigationView {
                VStack {
                    Text("Select Score")
                        .font(.title2.weight(.semibold))
                        .padding(.top)
                    
                    ScorePicker(score: $score)
                    
                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.height(300)])
        }
    }
}

#Preview {
    VStack {
        ScorePickerButton(score: .constant(11))
        
        ScorePicker(score: .constant(15))
            .border(Color.gray)
    }
    .padding()
}