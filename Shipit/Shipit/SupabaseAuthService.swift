//
//  SupabaseAuthService.swift
//  Shipit
//
//  Created on 29.01.2026.
//

import Foundation
import Supabase

@MainActor
class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()
    
    @Published var session: Session?
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.supabaseURL,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
        
        // Listen for auth state changes
        Task {
            for await state in client.auth.authStateChanges {
                self.session = state.session
                self.user = state.session?.user
                
                // Check if session is expired (as recommended by the warning)
                if let session = state.session {
                    // TODO: In future, check session.isExpired if needed
                    print("🔐 [DEBUG] Auth state changed: \(session.user.id.uuidString)")
                } else {
                    print("🔐 [DEBUG] Auth state changed: No session")
                }
            }
        }
    }
    
    // MARK: - Phone Authentication
    
    /// Send OTP code to phone number
    func sendOTP(to phoneNumber: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            print("📱 [DEBUG] Sending OTP to: \(phoneNumber)")
            
            try await client.auth.signInWithOTP(
                phone: phoneNumber
            )
            
            print("✅ [DEBUG] OTP sent successfully")
        } catch {
            print("❌ [ERROR] Failed to send OTP: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Verify OTP code and sign in
    func verifyOTP(phone: String, token: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            print("🔐 [DEBUG] Verifying OTP for: \(phone)")
            
            let response = try await client.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )
            
            self.session = response.session
            self.user = response.session?.user
            
            print("✅ [DEBUG] Phone verification successful")
            print("👤 [DEBUG] User ID: \(response.session?.user.id.uuidString ?? "unknown")")
        } catch {
            print("❌ [ERROR] OTP verification failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Email Authentication (Optional)
    
    /// Sign up with email and password
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            self.session = response.session
            self.user = response.session?.user
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            self.session = session
            self.user = session.user
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Password Reset
    
    /// Send password reset email
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await client.auth.resetPasswordForEmail(email)
            print("📧 [DEBUG] Password reset email sent to: \(email)")
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        try await client.auth.signOut()
        self.session = nil
        self.user = nil
        print("👋 [DEBUG] User signed out")
    }
    
    // MARK: - Helper Methods
    
    var isAuthenticated: Bool {
        session != nil
    }
}
