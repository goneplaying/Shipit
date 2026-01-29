//
//  LoginPage.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import SwiftUI
import UIKit

struct LoginPage: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var appSettings = AppSettingsManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showFirebaseErrorAlert = false
    @State private var firebaseErrorMessage = ""
    @State private var showUserNotFoundAlert = false
    @State private var showPasswordResetAlert = false
    @State private var showPasswordResetSuccessAlert = false
    @State private var showRegisterPage = false
    
    init() {
        print("🔧 [DEBUG] LoginPage: Initializer called")
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
                        Text("Login")
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
                        
                        // Forgot password link
                        Button(action: {
                            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                                showPasswordResetAlert = true
                            } else {
                                Task {
                                    do {
                                        try await authService.resetPassword(email: email.trimmingCharacters(in: .whitespaces))
                                        showPasswordResetSuccessAlert = true
                                    } catch {
                                        firebaseErrorMessage = error.localizedDescription
                                        showFirebaseErrorAlert = true
                                    }
                                }
                            }
                        }) {
                            Text("Forgot your password?")
                                .font(.system(size: 16))
                                .foregroundColor(Colors.secondary)
                                .underline()
                        }
                        .padding(.vertical, 10)
                        
                        // Login Button
                        Button(action: {
                            Task {
                                do {
                                    try await authService.login(
                                        email: email.trimmingCharacters(in: .whitespaces),
                                        password: password
                                    )
                                    // Login successful - ShipitApp will automatically navigate to HomePage
                                    // based on authService.user state
                                } catch {
                                    // Check if error is "user not found"
                                    if let nsError = error as NSError?, nsError.code == 17011 {
                                        // User does not exist
                                        showUserNotFoundAlert = true
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
                                Text("Login")
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
                        
                        // Register Button
                        Button(action: {
                            showRegisterPage = true
                        }) {
                            Text("Register")
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
            .alert("User Not Found", isPresented: $showUserNotFoundAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No account found with this email address. Please check your email or register for a new account.")
            }
            .alert("Login Error", isPresented: $showFirebaseErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(firebaseErrorMessage)
            }
            .alert("Email Required", isPresented: $showPasswordResetAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter your email address to reset your password.")
            }
            .alert("Password Reset", isPresented: $showPasswordResetSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A password reset email has been sent to \(email).")
            }
            .fullScreenCover(isPresented: $showRegisterPage) {
                RegisterPage()
                    .environmentObject(authService)
            }
            .onAppear {
                print("👁️ [DEBUG] LoginPage: View appeared on screen")
            }
        }
    }
}

#Preview {
    LoginPage()
        .environmentObject(AuthService())
}
