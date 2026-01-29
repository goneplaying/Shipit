//
//  PhoneNumberPage.swift
//  Shipit
//
//  Created on 29.01.2026.
//

import SwiftUI

struct PhoneNumberPage: View {
    @EnvironmentObject var authService: SupabaseAuthService
    @State private var selectedCountry: Country = .poland
    @State private var phoneNumber: String = ""
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var verificationID: String?
    @State private var navigateToVerification: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                // Title
                Text("What's your number?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Colors.text)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                
                // Phone number input section
                HStack(spacing: 12) {
                    // Country selector (left side)
                    Menu {
                        ForEach(Country.allCases, id: \.self) { country in
                            Button {
                                selectedCountry = country
                            } label: {
                                Text("\(country.flag) \(country.name) \(country.prefix)")
                                    .font(.system(size: 15))
                                    .foregroundColor(Colors.tertiary)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedCountry.flag)
                                .font(.system(size: 24))
                            Text(selectedCountry.prefix)
                                .font(.system(size: 17))
                                .foregroundColor(Colors.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(Colors.backgroundQuaternary)
                        .cornerRadius(12)
                    }
                    
                    // Phone number field (right side - wider)
                    TextField("Phone number", text: $phoneNumber)
                        .font(.system(size: 17))
                        .foregroundColor(Colors.secondary)
                        .keyboardType(.phonePad)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(Colors.backgroundQuaternary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                
                // Error message
                if showError {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                
                // Get verification code button
                Button(action: sendVerificationCode) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Get verification code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(phoneNumber.isEmpty ? Colors.tertiary : Colors.secondary)
                .cornerRadius(12)
                .disabled(phoneNumber.isEmpty || isLoading)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                
                Spacer()
                
                // Terms and Privacy text at the bottom
                VStack(spacing: 4) {
                    Text("By signing up, you're agreeing to our")
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textSecondary)
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            // Open Terms of Service
                            if let url = URL(string: "https://shipit.com/terms") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Terms of Service")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.text)
                                .underline()
                        }
                        
                        Text("and")
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textSecondary)
                        
                        Button(action: {
                            // Open Privacy Policy
                            if let url = URL(string: "https://shipit.com/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Privacy Policy")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.text)
                                .underline()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Colors.background)
            .navigationDestination(isPresented: $navigateToVerification) {
                if let verificationID = verificationID {
                    VerificationCodePage(
                        phoneNumber: "\(selectedCountry.flag) \(selectedCountry.prefix) \(phoneNumber)",
                        verificationID: verificationID
                    )
                }
            }
        }
    }
    
    private func sendVerificationCode() {
        // Validate phone number
        guard !phoneNumber.isEmpty else { return }
        
        // Format full phone number (remove spaces and ensure correct format)
        let cleanedNumber = phoneNumber.replacingOccurrences(of: " ", with: "")
        let fullPhoneNumber = "\(selectedCountry.prefix)\(cleanedNumber)"
        
        isLoading = true
        showError = false
        
        // Send OTP via Supabase
        Task {
            do {
                try await authService.sendOTP(to: fullPhoneNumber)
                
                // Success - navigate to verification
                verificationID = fullPhoneNumber // Store phone for verification
                navigateToVerification = true
                isLoading = false
            } catch {
                showError = true
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// Country model
enum Country: String, CaseIterable {
    case albania = "AL"
    case austria = "AT"
    case belgium = "BE"
    case bulgaria = "BG"
    case croatia = "HR"
    case cyprus = "CY"
    case czechRepublic = "CZ"
    case denmark = "DK"
    case estonia = "EE"
    case finland = "FI"
    case france = "FR"
    case germany = "DE"
    case greece = "GR"
    case hungary = "HU"
    case iceland = "IS"
    case ireland = "IE"
    case italy = "IT"
    case latvia = "LV"
    case lithuania = "LT"
    case luxembourg = "LU"
    case malta = "MT"
    case netherlands = "NL"
    case norway = "NO"
    case poland = "PL"
    case portugal = "PT"
    case romania = "RO"
    case serbia = "RS"
    case slovakia = "SK"
    case slovenia = "SI"
    case spain = "ES"
    case sweden = "SE"
    case switzerland = "CH"
    case turkey = "TR"
    case ukraine = "UA"
    case unitedKingdom = "GB"
    case unitedStates = "US"
    
    var name: String {
        switch self {
        case .albania: return "Albania"
        case .austria: return "Austria"
        case .belgium: return "Belgium"
        case .bulgaria: return "Bulgaria"
        case .croatia: return "Croatia"
        case .cyprus: return "Cyprus"
        case .czechRepublic: return "Czech Republic"
        case .denmark: return "Denmark"
        case .estonia: return "Estonia"
        case .finland: return "Finland"
        case .france: return "France"
        case .germany: return "Germany"
        case .greece: return "Greece"
        case .hungary: return "Hungary"
        case .iceland: return "Iceland"
        case .ireland: return "Ireland"
        case .italy: return "Italy"
        case .latvia: return "Latvia"
        case .lithuania: return "Lithuania"
        case .luxembourg: return "Luxembourg"
        case .malta: return "Malta"
        case .netherlands: return "Netherlands"
        case .norway: return "Norway"
        case .poland: return "Poland"
        case .portugal: return "Portugal"
        case .romania: return "Romania"
        case .serbia: return "Serbia"
        case .slovakia: return "Slovakia"
        case .slovenia: return "Slovenia"
        case .spain: return "Spain"
        case .sweden: return "Sweden"
        case .switzerland: return "Switzerland"
        case .turkey: return "Turkey"
        case .ukraine: return "Ukraine"
        case .unitedKingdom: return "United Kingdom"
        case .unitedStates: return "United States"
        }
    }
    
    var prefix: String {
        switch self {
        case .albania: return "+355"
        case .austria: return "+43"
        case .belgium: return "+32"
        case .bulgaria: return "+359"
        case .croatia: return "+385"
        case .cyprus: return "+357"
        case .czechRepublic: return "+420"
        case .denmark: return "+45"
        case .estonia: return "+372"
        case .finland: return "+358"
        case .france: return "+33"
        case .germany: return "+49"
        case .greece: return "+30"
        case .hungary: return "+36"
        case .iceland: return "+354"
        case .ireland: return "+353"
        case .italy: return "+39"
        case .latvia: return "+371"
        case .lithuania: return "+370"
        case .luxembourg: return "+352"
        case .malta: return "+356"
        case .netherlands: return "+31"
        case .norway: return "+47"
        case .poland: return "+48"
        case .portugal: return "+351"
        case .romania: return "+40"
        case .serbia: return "+381"
        case .slovakia: return "+421"
        case .slovenia: return "+386"
        case .spain: return "+34"
        case .sweden: return "+46"
        case .switzerland: return "+41"
        case .turkey: return "+90"
        case .ukraine: return "+380"
        case .unitedKingdom: return "+44"
        case .unitedStates: return "+1"
        }
    }
    
    var flag: String {
        switch self {
        case .albania: return "🇦🇱"
        case .austria: return "🇦🇹"
        case .belgium: return "🇧🇪"
        case .bulgaria: return "🇧🇬"
        case .croatia: return "🇭🇷"
        case .cyprus: return "🇨🇾"
        case .czechRepublic: return "🇨🇿"
        case .denmark: return "🇩🇰"
        case .estonia: return "🇪🇪"
        case .finland: return "🇫🇮"
        case .france: return "🇫🇷"
        case .germany: return "🇩🇪"
        case .greece: return "🇬🇷"
        case .hungary: return "🇭🇺"
        case .iceland: return "🇮🇸"
        case .ireland: return "🇮🇪"
        case .italy: return "🇮🇹"
        case .latvia: return "🇱🇻"
        case .lithuania: return "🇱🇹"
        case .luxembourg: return "🇱🇺"
        case .malta: return "🇲🇹"
        case .netherlands: return "🇳🇱"
        case .norway: return "🇳🇴"
        case .poland: return "🇵🇱"
        case .portugal: return "🇵🇹"
        case .romania: return "🇷🇴"
        case .serbia: return "🇷🇸"
        case .slovakia: return "🇸🇰"
        case .slovenia: return "🇸🇮"
        case .spain: return "🇪🇸"
        case .sweden: return "🇸🇪"
        case .switzerland: return "🇨🇭"
        case .turkey: return "🇹🇷"
        case .ukraine: return "🇺🇦"
        case .unitedKingdom: return "🇬🇧"
        case .unitedStates: return "🇺🇸"
        }
    }
}

#Preview {
    PhoneNumberPage()
        .environmentObject(SupabaseAuthService.shared)
}
