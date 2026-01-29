//
//  RegistrationConfirmationPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import UIKit

struct RegistrationConfirmationPage: View {
    @State private var showLogin = false
    @Environment(\.dismiss) private var dismiss
    
    init() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.white
        navBarAppearance.titleTextAttributes = [.foregroundColor: Colors.secondaryUIColor]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: Colors.secondaryUIColor]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // White background
                Colors.background
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Headline
                        Text("Registration\nSuccessful")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                        
                        // Body text
                        Text("We've sent you a confirmation email. Please check your inbox and click the activation link to verify your email address. Once verified, you can log in to your account.")
                            .font(.system(size: 16))
                            .foregroundColor(Colors.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        
                        // Login Button
                        Button(action: {
                            showLogin = true
                        }) {
                            Text("Go to Login")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Colors.primary)
                                .cornerRadius(24)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        LucideIcon(IconHelper.close, size: 24)
                            .foregroundColor(Colors.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Shipit")
                        .foregroundColor(Colors.secondary)
                        .font(.headline)
                }
            }
            .fullScreenCover(isPresented: $showLogin) {
                LoginPage()
            }
        }
    }
}

#Preview {
    RegistrationConfirmationPage()
}
