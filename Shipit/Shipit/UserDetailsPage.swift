//
//  UserDetailsPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct UserDetailsPage: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileData = ProfileData.shared
    
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""
    @State private var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    
    private let countries = ["Poland", "Germany", "France", "United Kingdom", "United States", "Canada", "Spain", "Italy", "Netherlands", "Belgium"]
    
    var body: some View {
        ZStack {
            Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Track scroll position at the top
                    ScrollViewOffsetTracker()
                    
                    // Tab Bar
                    HStack(spacing: 0) {
                        // Private Person Tab
                        Button(action: {
                            profileData.selectedTab = 0
                        }) {
                            Text("Private Person")
                                .font(.system(size: 16))
                                .foregroundColor(profileData.selectedTab == 0 ? .white : Colors.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(profileData.selectedTab == 0 ? Colors.primary : Color.clear)
                                .cornerRadius(20)
                        }
                        
                        // Company Tab
                        Button(action: {
                            profileData.selectedTab = 1
                        }) {
                            Text("Company")
                                .font(.system(size: 16))
                                .foregroundColor(profileData.selectedTab == 1 ? .white : Colors.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(profileData.selectedTab == 1 ? Colors.primary : Color.clear)
                                .cornerRadius(20)
                        }
                    }
                    .padding(4)
                    .background(Colors.backgroundSecondary)
                    .cornerRadius(24)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        if profileData.selectedTab == 0 {
                            // Private Person Fields
                            FormField(label: "First Name", text: $profileData.firstName, isRequired: true)
                            FormField(label: "Last Name", text: $profileData.lastName, isRequired: true)
                        } else {
                            // Company Fields
                            FormField(label: "Company name", text: $profileData.companyName, isRequired: true)
                            FormField(label: "NIP (Tax ID)", text: $profileData.nip, isRequired: true)
                        }
                        
                        // Country Dropdown
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Country")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.text)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            
                            Menu {
                                ForEach(countries, id: \.self) { country in
                                    Button(country) {
                                        profileData.selectedCountry = country
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(profileData.selectedCountry)
                                        .foregroundColor(Colors.text)
                                    Spacer()
                                    LucideIcon(IconHelper.chevronDown, size: 22)
                                        .foregroundColor(Colors.text)
                                }
                                .frame(height: 48)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Colors.backgroundSecondary)
                                )
                            }
                        }
                        
                        FormField(label: "Street & Number", text: $profileData.streetAndNumber, isRequired: true)
                        FormField(label: "Apartment / Unit", text: $profileData.apartmentUnit, isRequired: false)
                        FormField(label: "Postal Code", text: $profileData.postalCode, isRequired: true)
                        FormField(label: "City", text: $profileData.city, isRequired: true)
                        FormField(label: "Region / State", text: $profileData.regionState, isRequired: false)
                        
                        // Phone Number with formatting
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Phone number")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.text)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            
                            HStack(spacing: 8) {
                                Text("+48")
                                    .foregroundColor(Colors.text)
                                    .frame(width: 40)
                                
                                TextField("___ ___ ___", text: $profileData.phoneNumber)
                                    .keyboardType(.phonePad)
                                    .onChange(of: profileData.phoneNumber) { oldValue, newValue in
                                        profileData.phoneNumber = formatPhoneNumber(newValue)
                                    }
                            }
                            .frame(height: 48)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Colors.backgroundSecondary)
                            )
                            
                            Text("Required if you use SMS/2FA; otherwise optional")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                        }
                        
                        // Email field (read-only from Firebase Auth)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Login Email")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.text)
                            }
                            
                            TextField("Email", text: .constant(profileData.email))
                                .disabled(true)
                                .frame(height: 48)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Colors.backgroundSecondary)
                                )
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Save Button
                    Button(action: {
                        // Update email from Firebase Auth before saving
                        profileData.updateEmailFromAuth()
                        
                        // Save profile data to Firestore
                        Task {
                            do {
                                try await profileData.save()
                                await MainActor.run {
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    saveErrorMessage = error.localizedDescription
                                    showSaveErrorAlert = true
                                }
                            }
                        }
                    }) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Colors.primary)
                            .cornerRadius(24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let threshold: CGFloat = -50
                let newMode: NavigationBarItem.TitleDisplayMode = value < threshold ? .inline : .large
                if titleDisplayMode != newMode {
                    titleDisplayMode = newMode
                }
            }
        }
        .navigationTitle("User Details")
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert("Save Error", isPresented: $showSaveErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            // Update email from Firebase Auth when view appears
            profileData.updateEmailFromAuth()
            // Load profile data from Firestore
            Task {
                try? await profileData.loadFromFirestore()
            }
            // Reset scroll position and title display mode
            titleDisplayMode = .large
        }
        .onDisappear {
            // Reset title display mode when view disappears to prevent state issues
            titleDisplayMode = .large
        }
    }
    
    private func formatPhoneNumber(_ phone: String) -> String {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .prefix(9) // Limit to 9 digits
        
        var formatted = ""
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % 3 == 0 {
                formatted += " "
            }
            formatted += String(char)
        }
        
        return formatted
    }
}

#Preview {
    NavigationStack {
        UserDetailsPage()
    }
}
