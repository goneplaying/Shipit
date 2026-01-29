//
//  WelcomePage.swift
//  Shipit
//
//  Created on 29.01.2026.
//

import SwiftUI

struct WelcomePage: View {
    @EnvironmentObject var authService: SupabaseAuthService
    @ObservedObject var profileData = ProfileData.shared
    @State private var navigateToShipper = false
    @State private var navigateToCarrier = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        headerSection
                        
                        // Teasers
                        VStack(spacing: 16) {
                            // Teaser 1 - Shipper
                            shipperTeaser
                            
                            // Teaser 2 - Carrier
                            carrierTeaser
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToShipper) {
                HomePageShipper()
            }
            .navigationDestination(isPresented: $navigateToCarrier) {
                HomePageCarrier()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Welcome to Shipit")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Color(hex: "#141414"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text("Choose the option that suits you best")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#707070"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 48)
        .padding(.bottom, 40)
    }
    
    // MARK: - Shipper Teaser
    
    private var shipperTeaser: some View {
        Button(action: {
            HapticFeedback.light()
            selectShipper()
        }) {
            ZStack(alignment: .topLeading) {
                // Background
                Color(hex: "#FFAD00")
                
                // Image positioned at bottom right
                Image("teaserImageShipper")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 232)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Text overlay at top left
                VStack(alignment: .leading, spacing: 0) {
                    Text("I want")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#222222"))
                    Text("send a shipment")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#222222"))
                }
                .padding(20)
            }
            .frame(height: 232)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Carrier Teaser
    
    private var carrierTeaser: some View {
        Button(action: {
            HapticFeedback.light()
            selectCarrier()
        }) {
            ZStack(alignment: .topLeading) {
                // Background
                Color(hex: "#FFAD00")
                
                // Image positioned at bottom right
                Image("teaserImageCarrier")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 232)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Text overlay at top left
                VStack(alignment: .leading, spacing: 0) {
                    Text("I want")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#222222"))
                    Text("find loads")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#222222"))
                }
                .padding(20)
            }
            .frame(height: 232)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func selectShipper() {
        // Save selection
        profileData.selectedTab = 0 // Shipper
        profileData.hasCompletedWelcome = true // Mark welcome as completed
        Task {
            try? await profileData.save()
        }
        
        // Navigate
        navigateToShipper = true
    }
    
    private func selectCarrier() {
        // Save selection
        profileData.selectedTab = 1 // Carrier
        profileData.hasCompletedWelcome = true // Mark welcome as completed
        Task {
            try? await profileData.save()
        }
        
        // Navigate
        navigateToCarrier = true
    }
}

// MARK: - Preview

#Preview {
    WelcomePage()
        .environmentObject(SupabaseAuthService.shared)
}
