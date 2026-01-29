//
//  AuthService.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import Foundation
import FirebaseAuth
import FirebaseCore

class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        // Listen for authentication state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
            }
        }
    }
    
    deinit {
        // Remove listener when AuthService is deallocated
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // Register a new user
    func register(email: String, password: String) async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Send email verification
            try await result.user.sendEmailVerification()
            
            // Sign out the user until they verify their email
            try Auth.auth().signOut()
            
            await MainActor.run {
                self.user = nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            
            // Check if error is "email already in use" (error code 17007)
            if let authError = error as NSError?, authError.code == 17007 {
                throw NSError(
                    domain: "AuthService",
                    code: 17007,
                    userInfo: [NSLocalizedDescriptionKey: "An account with this email address already exists. Please use a different email or try logging in."]
                )
            }
            
            throw error
        }
    }
    
    // Login existing user
    func login(email: String, password: String) async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Check if email is verified
            if !result.user.isEmailVerified {
                // Sign out if email is not verified
                try Auth.auth().signOut()
                throw NSError(
                    domain: "AuthService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Please verify your email address before logging in. Check your inbox for the activation link."]
                )
            }
            
            await MainActor.run {
                self.user = result.user
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            
            // Check if error is "user not found" (error code 17011)
            if let authError = error as NSError?, authError.code == 17011 {
                throw NSError(
                    domain: "AuthService",
                    code: 17011,
                    userInfo: [NSLocalizedDescriptionKey: "No account found with this email address. Please check your email or register for a new account."]
                )
            }
            
            throw error
        }
    }
    
    // Send password reset email
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    // Logout current user
    func logout() throws {
        try Auth.auth().signOut()
        self.user = nil
    }
}
