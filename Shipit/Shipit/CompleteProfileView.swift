//
//  CompleteProfileView.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI

struct CompleteProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var profileData = ProfileData.shared
    var onComplete: (() -> Void)?
    @Binding var isPresented: Bool
    
    @State private var showMissingDataAlert = false
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""
    
    // European countries list
    private let europeanCountries = [
        "Albania", "Andorra", "Austria", "Belarus", "Belgium", "Bosnia and Herzegovina",
        "Bulgaria", "Croatia", "Cyprus", "Czech Republic", "Denmark", "Estonia",
        "Finland", "France", "Germany", "Greece", "Hungary", "Iceland", "Ireland",
        "Italy", "Kosovo", "Latvia", "Liechtenstein", "Lithuania", "Luxembourg",
        "Malta", "Moldova", "Monaco", "Montenegro", "Netherlands", "North Macedonia",
        "Norway", "Poland", "Portugal", "Romania", "Russia", "San Marino", "Serbia",
        "Slovakia", "Slovenia", "Spain", "Sweden", "Switzerland", "Ukraine",
        "United Kingdom", "Vatican City"
    ]
    
    // European phone prefixes
    private let phonePrefixes: [(country: String, prefix: String)] = [
        ("Albania", "+355"), ("Andorra", "+376"), ("Austria", "+43"), ("Belarus", "+375"),
        ("Belgium", "+32"), ("Bosnia and Herzegovina", "+387"), ("Bulgaria", "+359"),
        ("Croatia", "+385"), ("Cyprus", "+357"), ("Czech Republic", "+420"), ("Denmark", "+45"),
        ("Estonia", "+372"), ("Finland", "+358"), ("France", "+33"), ("Germany", "+49"),
        ("Greece", "+30"), ("Hungary", "+36"), ("Iceland", "+354"), ("Ireland", "+353"),
        ("Italy", "+39"), ("Kosovo", "+383"), ("Latvia", "+371"), ("Liechtenstein", "+423"),
        ("Lithuania", "+370"), ("Luxembourg", "+352"), ("Malta", "+356"), ("Moldova", "+373"),
        ("Monaco", "+377"), ("Montenegro", "+382"), ("Netherlands", "+31"), ("North Macedonia", "+389"),
        ("Norway", "+47"), ("Poland", "+48"), ("Portugal", "+351"), ("Romania", "+40"),
        ("Russia", "+7"), ("San Marino", "+378"), ("Serbia", "+381"), ("Slovakia", "+421"),
        ("Slovenia", "+386"), ("Spain", "+34"), ("Sweden", "+46"), ("Switzerland", "+41"),
        ("Ukraine", "+380"), ("United Kingdom", "+44"), ("Vatican City", "+39")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom top toolbar matching Figma design
                    HStack {
                        // Left button - White background with black arrow-left icon
                        Button(action: {
                            HapticFeedback.light()
                            isPresented = false
                        }) {
                            Circle()
                                .fill(.white)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    LucideIcon(IconHelper.arrowLeft, size: 24, color: Colors.text)
                                )
                        }
                        
                        Spacer()
                        
                        // Right button - Secondary background with white arrow-right icon
                        Button(action: {
                            saveProfile()
                        }) {
                            Circle()
                                .fill(Colors.secondary)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    LucideIcon(IconHelper.arrowRight, size: 24, color: .white)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .background(Colors.background)
                    
                    ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        Text("Set Up Your Profile")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Colors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Private Person Fields
                            FormField(label: "First Name", text: $profileData.firstName, isRequired: true)
                            FormField(label: "Last Name", text: $profileData.lastName, isRequired: true)
                            
                            // Optional Company Fields
                            FormField(label: "Company Name", text: $profileData.companyName, isRequired: false)
                            FormField(label: "NIP", text: $profileData.nip, isRequired: false)
                            
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
                                    ForEach(europeanCountries, id: \.self) { country in
                                        Button(country) {
                                            profileData.selectedCountry = country
                                            // Auto-update phone prefix based on country
                                            if let prefix = phonePrefixes.first(where: { $0.country == country }) {
                                                profileData.phonePrefix = prefix.prefix
                                            }
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
                            
                            // Phone Number - Split into prefix dropdown and number field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Phone Number")
                                        .font(.system(size: 16))
                                        .foregroundColor(Colors.text)
                                    Text("*")
                                        .foregroundColor(.red)
                                }
                                
                                HStack(spacing: 8) {
                                    // Phone Prefix Dropdown
                                    Menu {
                                        ForEach(phonePrefixes, id: \.prefix) { item in
                                            Button("\(item.country) \(item.prefix)") {
                                                profileData.phonePrefix = item.prefix
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(profileData.phonePrefix)
                                                .foregroundColor(Colors.text)
                                            Spacer()
                                            LucideIcon(IconHelper.chevronDown, size: 18)
                                                .foregroundColor(Colors.text)
                                        }
                                        .frame(width: 80)
                                        .frame(height: 48)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Colors.backgroundSecondary)
                                        )
                                    }
                                    
                                    // Phone Number Field (no formatting)
                                    TextField("Phone Number", text: $profileData.phoneNumber)
                                        .keyboardType(.phonePad)
                                        .frame(height: 48)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Colors.backgroundSecondary)
                                        )
                                }
                                
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
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                } // End VStack
            }
            .navigationBarHidden(true)
            .alert("Required Data Missing", isPresented: $showMissingDataAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please fill in all required fields before closing. Required fields are marked with an asterisk (*).")
            }
            .alert("Save Error", isPresented: $showSaveErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .onAppear {
                // Update email from Firebase Auth when view appears
                profileData.updateEmailFromAuth()
            }
        }
    }
    
    private func saveProfile() {
        // Check if profile is complete before saving
        if profileData.isProfileComplete() {
            // Update email from Firebase Auth before saving
            profileData.updateEmailFromAuth()
            
            // Save profile data
            Task {
                do {
                    // Save will also save to UserDefaults first
                    try await profileData.save()
                    print("✅ Profile saved successfully")
                    
                    // Call onComplete callback first to update parent state
                    onComplete?()
                    
                    // Dismiss the sheet on main thread
                    await MainActor.run {
                        print("✅ All necessary data saved, closing sheet")
                        // Update the binding to close the sheet (this will trigger sheet dismissal)
                        isPresented = false
                    }
                } catch {
                    print("❌ Profile save error: \(error.localizedDescription)")
                    
                    await MainActor.run {
                        // Show error alert but keep sheet open
                        saveErrorMessage = error.localizedDescription.isEmpty ? "Failed to save profile data. Please try again." : error.localizedDescription
                        showSaveErrorAlert = true
                    }
                }
            }
        } else {
            // Show alert if required data is missing - don't close sheet
            print("❌ Profile incomplete - showing missing data alert")
            showMissingDataAlert = true
        }
    }
}

struct FormField: View {
    let label: String
    @Binding var text: String
    let isRequired: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(Colors.text)
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            
            TextField(isRequired ? "" : "Optional", text: $text)
                .frame(height: 48)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Colors.backgroundSecondary)
                )
        }
    }
}

#Preview {
    CompleteProfileView(isPresented: .constant(true))
        .environmentObject(AuthService())
}
