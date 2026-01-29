//
//  NewRequestPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct NewRequestPage: View {
    @State private var shipmentDescription: String = ""
    @State private var openAIOutput: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    @StateObject private var openAI = OpenAI()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Text area field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shipment Description")
                                .font(.system(size: 16))
                                .foregroundColor(Colors.text)
                            
                            TextEditor(text: $shipmentDescription)
                                .frame(minHeight: 200)
                                .scrollContentBackground(.hidden) // Hide default white background
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Colors.backgroundQuaternary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Colors.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                                .focused($isTextEditorFocused)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Send button
                        Button(action: {
                            HapticFeedback.light()
                            // Dismiss keyboard
                            isTextEditorFocused = false
                            sendToOpenAI()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text("Send")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Colors.secondary)
                            .cornerRadius(24)
                        }
                        .disabled(isLoading || shipmentDescription.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // OpenAI output
                        if !openAIOutput.isEmpty || isLoading {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Response")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.text)
                                    .padding(.top, 8)
                                
                                if isLoading {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Colors.text))
                                        Text("Processing...")
                                            .font(.system(size: 16))
                                            .foregroundColor(Colors.textSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Colors.backgroundSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Colors.textSecondary.opacity(0.2), lineWidth: 1)
                                    )
                                } else {
                                    Text(openAIOutput)
                                        .font(.system(size: 16))
                                        .foregroundColor(openAIOutput.hasPrefix("Error:") ? .red : Colors.text)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Colors.backgroundSecondary)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Colors.textSecondary.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                    }
                }
            }
        }
        .navigationTitle("New Request")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            openAI.setup()
        }
    }
    
    private func sendToOpenAI() {
        guard !shipmentDescription.isEmpty else { return }
        
        isLoading = true
        openAIOutput = ""
        
        let instructions = OpenAIInstructions.getInstructions()
        let prompt = "\(instructions)\n\nUser's shipment description:\n\(shipmentDescription)"
        
        openAI.send(text: prompt) { response in
            openAIOutput = response
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        NewRequestPage()
    }
}
