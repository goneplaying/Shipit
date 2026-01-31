//
//  ProfileData.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import Foundation
import Supabase

class ProfileData: ObservableObject {
    @Published var selectedTab: Int = -1 // -1 = Not selected, 0 = Shipper, 1 = Carrier
    @Published var userType: Int = 0 // 0 = Carrier, 1 = Shipper
    @Published var hasCompletedWelcome: Bool = false // Track if user selected role in WelcomePage
    @Published var showExchangeAndJobs: Bool = false // Controls visibility of Exchange and Jobs tabs
    
    // Private Person fields
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    
    // Company fields
    @Published var companyName: String = ""
    @Published var nip: String = ""
    
    // Common fields
    @Published var selectedCountry: String = "Poland"
    @Published var streetAndNumber: String = ""
    @Published var apartmentUnit: String = ""
    @Published var postalCode: String = ""
    @Published var city: String = ""
    @Published var regionState: String = ""
    @Published var phonePrefix: String = "+48" // Phone country prefix
    @Published var phoneNumber: String = ""
    @Published var email: String = "" // Login email from Supabase Auth
    
    static let shared = ProfileData()
    
    // Flag to prevent multiple concurrent loads
    private var isLoadingFromSupabase = false
    
    private init() {
        // TEMP: Uncomment to test WelcomePage
        // UserDefaults.standard.set(false, forKey: "profile_hasCompletedWelcome")
        
        loadFromUserDefaults()
    }
    
    func save() async throws {
        // Save to UserDefaults for local persistence FIRST (before Supabase)
        // This ensures data is stored locally even if Supabase save fails
        saveToUserDefaults()
        
        // Save to Supabase
        guard let userId = await SupabaseAuthService.shared.user?.id.uuidString else {
            // Even if user is not authenticated, we've saved to UserDefaults
            // Throw error but data is still stored locally
            throw NSError(domain: "ProfileData", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        struct ProfileRecord: Codable {
            let id: String
            let selectedTab: Int
            let firstName: String
            let lastName: String
            let companyName: String
            let nip: String
            let selectedCountry: String
            let streetAndNumber: String
            let apartmentUnit: String
            let postalCode: String
            let city: String
            let regionState: String
            let phonePrefix: String
            let phoneNumber: String
            let email: String
            let userType: Int
            let updatedAt: Date
            
            enum CodingKeys: String, CodingKey {
                case id
                case selectedTab = "selected_tab"
                case firstName = "first_name"
                case lastName = "last_name"
                case companyName = "company_name"
                case nip
                case selectedCountry = "selected_country"
                case streetAndNumber = "street_and_number"
                case apartmentUnit = "apartment_unit"
                case postalCode = "postal_code"
                case city
                case regionState = "region_state"
                case phonePrefix = "phone_prefix"
                case phoneNumber = "phone_number"
                case email
                case userType = "usertype"
                case updatedAt = "updated_at"
            }
        }
        
        let profileRecord = ProfileRecord(
            id: userId,
            selectedTab: selectedTab,
            firstName: firstName,
            lastName: lastName,
            companyName: companyName,
            nip: nip,
            selectedCountry: selectedCountry,
            streetAndNumber: streetAndNumber,
            apartmentUnit: apartmentUnit,
            postalCode: postalCode,
            city: city,
            regionState: regionState,
            phonePrefix: phonePrefix,
            phoneNumber: phoneNumber,
            email: email,
            userType: userType,
            updatedAt: Date()
        )
        
        do {
            try await SupabaseAuthService.shared.client
                .from("profiles")
                .upsert(profileRecord)
                .execute()
            
            print("✅ ProfileData saved to Supabase successfully")
        } catch {
            print("⚠️ ProfileData Supabase save failed: \(error.localizedDescription)")
            // Re-throw the error, but UserDefaults data is already saved
            throw error
        }
    }
    
    func loadFromSupabase() async throws {
        // Prevent multiple concurrent loads
        guard !isLoadingFromSupabase else {
            return
        }
        
        guard let userId = await SupabaseAuthService.shared.user?.id.uuidString else {
            return
        }
        
        isLoadingFromSupabase = true
        defer {
            isLoadingFromSupabase = false
        }
        
        struct ProfileRecord: Codable {
            let id: String
            let selectedTab: Int?
            let firstName: String?
            let lastName: String?
            let companyName: String?
            let nip: String?
            let selectedCountry: String?
            let streetAndNumber: String?
            let apartmentUnit: String?
            let postalCode: String?
            let city: String?
            let regionState: String?
            let phonePrefix: String?
            let phoneNumber: String?
            let email: String?
            let userType: Int?
            
            enum CodingKeys: String, CodingKey {
                case id
                case selectedTab = "selected_tab"
                case firstName = "first_name"
                case lastName = "last_name"
                case companyName = "company_name"
                case nip
                case selectedCountry = "selected_country"
                case streetAndNumber = "street_and_number"
                case apartmentUnit = "apartment_unit"
                case postalCode = "postal_code"
                case city
                case regionState = "region_state"
                case phonePrefix = "phone_prefix"
                case phoneNumber = "phone_number"
                case email
                case userType = "usertype"
            }
        }
        
        let response: [ProfileRecord] = try await SupabaseAuthService.shared.client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        
        guard let data = response.first else {
            return
        }
        
        await MainActor.run {
            // Store old values to check if anything changed
            let oldValues = (
                selectedTab: selectedTab,
                firstName: firstName,
                lastName: lastName,
                companyName: companyName,
                nip: nip,
                selectedCountry: selectedCountry,
                streetAndNumber: streetAndNumber,
                apartmentUnit: apartmentUnit,
                postalCode: postalCode,
                city: city,
                regionState: regionState,
                phonePrefix: phonePrefix,
                phoneNumber: phoneNumber,
                email: email,
                userType: userType
            )
            
            // Update values from Supabase
            selectedTab = data.selectedTab ?? 0
            firstName = data.firstName ?? ""
            lastName = data.lastName ?? ""
            companyName = data.companyName ?? ""
            nip = data.nip ?? ""
            selectedCountry = data.selectedCountry ?? "Poland"
            streetAndNumber = data.streetAndNumber ?? ""
            apartmentUnit = data.apartmentUnit ?? ""
            postalCode = data.postalCode ?? ""
            city = data.city ?? ""
            regionState = data.regionState ?? ""
            phonePrefix = data.phonePrefix ?? "+48"
            phoneNumber = data.phoneNumber ?? ""
            email = data.email ?? ""
            userType = data.userType ?? 0
            
            // Only save to UserDefaults if data actually changed
            let hasChanged = oldValues.selectedTab != selectedTab ||
                            oldValues.firstName != firstName ||
                            oldValues.lastName != lastName ||
                            oldValues.companyName != companyName ||
                            oldValues.nip != nip ||
                            oldValues.selectedCountry != selectedCountry ||
                            oldValues.streetAndNumber != streetAndNumber ||
                            oldValues.apartmentUnit != apartmentUnit ||
                            oldValues.postalCode != postalCode ||
                            oldValues.city != city ||
                            oldValues.regionState != regionState ||
                            oldValues.phonePrefix != phonePrefix ||
                            oldValues.phoneNumber != phoneNumber ||
                            oldValues.email != email ||
                            oldValues.userType != userType
            
            if hasChanged {
                saveToUserDefaults()
            }
        }
    }
    
    private func saveToUserDefaults() {
        // Batch all UserDefaults writes together
        UserDefaults.standard.set(hasCompletedWelcome, forKey: "profile_hasCompletedWelcome")
        UserDefaults.standard.set(selectedTab, forKey: "profile_selectedTab")
        UserDefaults.standard.set(userType, forKey: "profile_userType")
        UserDefaults.standard.set(firstName, forKey: "profile_firstName")
        UserDefaults.standard.set(lastName, forKey: "profile_lastName")
        UserDefaults.standard.set(companyName, forKey: "profile_companyName")
        UserDefaults.standard.set(nip, forKey: "profile_nip")
        UserDefaults.standard.set(selectedCountry, forKey: "profile_selectedCountry")
        UserDefaults.standard.set(streetAndNumber, forKey: "profile_streetAndNumber")
        UserDefaults.standard.set(apartmentUnit, forKey: "profile_apartmentUnit")
        UserDefaults.standard.set(postalCode, forKey: "profile_postalCode")
        UserDefaults.standard.set(city, forKey: "profile_city")
        UserDefaults.standard.set(regionState, forKey: "profile_regionState")
        UserDefaults.standard.set(phonePrefix, forKey: "profile_phonePrefix")
        UserDefaults.standard.set(phoneNumber, forKey: "profile_phoneNumber")
        UserDefaults.standard.set(email, forKey: "profile_email")
        
        // Note: UserDefaults.standard.synchronize() is deprecated and unnecessary
        // UserDefaults automatically synchronizes when the app goes to background
        // Forcing immediate sync causes unnecessary disk writes
        
        // Debug: Print saved values to verify (only in debug builds)
        #if DEBUG
        print("✅ ProfileData saved to UserDefaults:")
        print("   selectedTab: \(selectedTab)")
        print("   firstName: \(firstName)")
        print("   lastName: \(lastName)")
        print("   companyName: \(companyName)")
        print("   selectedCountry: \(selectedCountry)")
        print("   city: \(city)")
        print("   phoneNumber: \(phoneNumber)")
        #endif
    }
    
    func updateEmailFromAuth() {
        Task { @MainActor in
            if let user = SupabaseAuthService.shared.user, let userEmail = user.email {
                await MainActor.run {
                    email = userEmail
                }
            }
        }
    }
    
    private func loadFromUserDefaults() {
        // Check if user has completed welcome first
        hasCompletedWelcome = UserDefaults.standard.bool(forKey: "profile_hasCompletedWelcome")
        
        // Only load selectedTab if welcome is completed, otherwise keep default -1
        if hasCompletedWelcome {
            selectedTab = UserDefaults.standard.integer(forKey: "profile_selectedTab")
        } else {
            selectedTab = -1
        }
        
        userType = UserDefaults.standard.integer(forKey: "profile_userType")
        showExchangeAndJobs = UserDefaults.standard.bool(forKey: "showExchangeAndJobs")
        firstName = UserDefaults.standard.string(forKey: "profile_firstName") ?? ""
        lastName = UserDefaults.standard.string(forKey: "profile_lastName") ?? ""
        companyName = UserDefaults.standard.string(forKey: "profile_companyName") ?? ""
        nip = UserDefaults.standard.string(forKey: "profile_nip") ?? ""
        selectedCountry = UserDefaults.standard.string(forKey: "profile_selectedCountry") ?? "Poland"
        streetAndNumber = UserDefaults.standard.string(forKey: "profile_streetAndNumber") ?? ""
        apartmentUnit = UserDefaults.standard.string(forKey: "profile_apartmentUnit") ?? ""
        postalCode = UserDefaults.standard.string(forKey: "profile_postalCode") ?? ""
        city = UserDefaults.standard.string(forKey: "profile_city") ?? ""
        regionState = UserDefaults.standard.string(forKey: "profile_regionState") ?? ""
        phonePrefix = UserDefaults.standard.string(forKey: "profile_phonePrefix") ?? "+48"
        phoneNumber = UserDefaults.standard.string(forKey: "profile_phoneNumber") ?? ""
        email = UserDefaults.standard.string(forKey: "profile_email") ?? ""
        
        // Debug: Print loaded values to verify
        print("📱 ProfileData loaded from UserDefaults:")
        print("   selectedTab: \(selectedTab)")
        print("   firstName: \(firstName)")
        print("   lastName: \(lastName)")
        print("   companyName: \(companyName)")
        print("   selectedCountry: \(selectedCountry)")
        print("   city: \(city)")
        print("   phoneNumber: \(phoneNumber)")
        
        // Update email from Supabase Auth if available
        updateEmailFromAuth()
    }
    
    // Check if all required profile data is filled
    func isProfileComplete() -> Bool {
        let isCompany = selectedTab == 1
        
        // Common required fields for both: Country, Street & Number, Postal Code, City, Phone Number
        let commonFieldsComplete = !selectedCountry.isEmpty &&
                                   !streetAndNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
                                   !postalCode.trimmingCharacters(in: .whitespaces).isEmpty &&
                                   !city.trimmingCharacters(in: .whitespaces).isEmpty &&
                                   !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
        
        if isCompany {
            // Company required fields: Company name, NIP, and common fields
            return !companyName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !nip.trimmingCharacters(in: .whitespaces).isEmpty &&
                   commonFieldsComplete
        } else {
            // Private Person required fields: First Name, Last Name, and common fields
            return !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   commonFieldsComplete
        }
    }
}
