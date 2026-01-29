//
//  RegisterPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import UIKit
import Foundation

struct RegisterPage: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var agreedToTerms = false
    @State private var showTermsAlert = false
    @State private var showEmailEmptyAlert = false
    @State private var showPasswordEmptyAlert = false
    @State private var showPasswordLengthAlert = false
    @State private var showInvalidEmailAlert = false
    @State private var showTermsLink = false
    @State private var showFirebaseErrorAlert = false
    @State private var firebaseErrorMessage = ""
    @State private var showUserExistsAlert = false
    @State private var showRegistrationConfirmation = false
    @State private var showLoginPage = false
    
    init() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.white
        navBarAppearance.titleTextAttributes = [.foregroundColor: Colors.secondaryUIColor]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: Colors.secondaryUIColor]
        navBarAppearance.shadowColor = .clear
        navBarAppearance.shadowImage = UIImage()
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
    
    // Email validation function
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
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
                        Text("Register")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.secondary)
                            .padding(.bottom, 10)
                        
                        // Text Fields
                        VStack(spacing: 20) {
                            TextField("Email", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .frame(height: 48)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Colors.backgroundSecondary)
                                )
                            
                            ZStack(alignment: .trailing) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Colors.backgroundSecondary)
                                    .frame(height: 48)
                                
                                if isPasswordVisible {
                                    TextField("Password", text: $password)
                                        .frame(height: 48)
                                        .padding(.horizontal, 16)
                                        .padding(.trailing, 40)
                                } else {
                                    SecureField("Password", text: $password)
                                        .frame(height: 48)
                                        .padding(.horizontal, 16)
                                        .padding(.trailing, 40)
                                }
                                
                                Button(action: {
                                    isPasswordVisible.toggle()
                                }) {
                                    LucideIcon(isPasswordVisible ? IconHelper.eyeSlash : IconHelper.eye, size: 28)
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 16)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Terms & Conditions checkbox
                        HStack {
                            Button(action: {
                                agreedToTerms.toggle()
                            }) {
                                LucideIcon(agreedToTerms ? IconHelper.checkboxFilled : IconHelper.checkbox, size: 28)
                                    .foregroundColor(Colors.secondary)
                            }
                            HStack(spacing: 4) {
                                Text("I agree with ")
                                    .font(.system(size: 16))
                                    .foregroundColor(Colors.secondary)
                                Button(action: {
                                    showTermsLink = true
                                }) {
                                    Text("Terms & Conditions")
                                        .font(.system(size: 16))
                                        .foregroundColor(Colors.secondary)
                                        .underline()
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        
                        // Register Button
                        Button(action: {
                            // Validate email is not empty
                            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                                showEmailEmptyAlert = true
                                return
                            }
                            
                            // Validate email format
                            if !isValidEmail(email.trimmingCharacters(in: .whitespaces)) {
                                showInvalidEmailAlert = true
                                return
                            }
                            
                            // Validate password is not empty
                            if password.isEmpty {
                                showPasswordEmptyAlert = true
                                return
                            }
                            
                            // Validate password length (minimum 8 characters)
                            if password.count < 8 {
                                showPasswordLengthAlert = true
                                return
                            }
                            
                            // Validate terms are agreed
                            if !agreedToTerms {
                                showTermsAlert = true
                                return
                            }
                            
                            // All validations passed - handle register with Firebase
                            Task {
                                do {
                                    try await authService.register(
                                        email: email.trimmingCharacters(in: .whitespaces),
                                        password: password
                                    )
                                    // Registration successful - show confirmation page
                                    showRegistrationConfirmation = true
                                } catch {
                                    // Check if error is "user already exists"
                                    if let nsError = error as NSError?, nsError.code == 17007 {
                                        // User already exists
                                        showUserExistsAlert = true
                                    } else {
                                        // Handle other Firebase errors
                                        firebaseErrorMessage = error.localizedDescription
                                        showFirebaseErrorAlert = true
                                    }
                                }
                            }
                        }) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text("Register")
                            }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Colors.secondary)
                                .cornerRadius(24)
                        }
                        .disabled(authService.isLoading)
                        .padding(.horizontal, 20)
                        
                        // Login Button
                        Button(action: {
                            showLoginPage = true
                        }) {
                            Text("Login")
                                .font(.headline)
                                .foregroundColor(Colors.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Colors.background)
                                .cornerRadius(24)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Shipit")
                        .foregroundColor(Colors.secondary)
                        .font(.headline)
                }
            }
            .alert("Terms & Conditions", isPresented: $showTermsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You must accept the Terms and Conditions to continue.")
            }
            .alert("Email Required", isPresented: $showEmailEmptyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter your email address.")
            }
            .alert("Password Required", isPresented: $showPasswordEmptyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter your password. Password must be at least 8 characters")
            }
            .alert("Password Too Short", isPresented: $showPasswordLengthAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Password must be at least 8 characters.")
            }
            .alert("Invalid Email", isPresented: $showInvalidEmailAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid email address.")
            }
            .alert("User Already Exists", isPresented: $showUserExistsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("An account with this email address already exists. Please use a different email or try logging in.")
            }
            .alert("Registration Error", isPresented: $showFirebaseErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(firebaseErrorMessage)
            }
            .sheet(isPresented: $showTermsLink) {
                TermsConditionsView()
            }
            .fullScreenCover(isPresented: $showRegistrationConfirmation) {
                RegistrationConfirmationPage()
            }
            .fullScreenCover(isPresented: $showLoginPage) {
                LoginPage()
                    .environmentObject(authService)
            }
        }
    }
}

#Preview {
    RegisterPage()
        .environmentObject(AuthService())
}
