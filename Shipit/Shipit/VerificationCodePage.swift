//
//  VerificationCodePage.swift
//  Shipit
//
//  Created on 29.01.2026.
//

import SwiftUI

struct VerificationCodePage: View {
    @EnvironmentObject var authService: SupabaseAuthService
    @Environment(\.dismiss) private var dismiss
    let phoneNumber: String
    let verificationID: String
    
    @State private var verificationCode: String = ""
    @State private var isVerifying: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        contentView
            .background(Colors.background)
            .navigationTitle("Verification")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                // Auto-focus on code field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isCodeFieldFocused = true
                }
            }
    }
    
    // MARK: - View Components
    
    private var contentView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                titleSection
                codeInputSection
                verifyButton
                resendButton
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Enter verification code")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Colors.text)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
            
            Text("We sent a code to \(cleanPhoneNumber)")
                .font(.system(size: 17))
                .foregroundColor(Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
    }
    
    // Helper to remove any emoji/flags from phone number
    private var cleanPhoneNumber: String {
        phoneNumber.filter { char in
            // Keep numbers, +, spaces, and hyphens - remove emoji/flags
            char.isNumber || char == "+" || char == " " || char == "-" || char == "(" || char == ")"
        }
    }
    
    private var codeInputSection: some View {
        VStack(spacing: 8) {
            codeTextField
            
            if showError {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
    
    private var codeTextField: some View {
        TextField("Enter code", text: $verificationCode)
            .font(.system(size: 17))
            .foregroundColor(Colors.secondary)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)  // Enable SMS auto-fill
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Colors.backgroundQuaternary)
            .cornerRadius(12)
            .focused($isCodeFieldFocused)
            .onChange(of: verificationCode) { oldValue, newValue in
                handleCodeChange(newValue)
            }
    }
    
    private var verifyButton: some View {
        Button(action: {
            HapticFeedback.light()
            verifyCode()
        }) {
            HStack(spacing: 8) {
                if isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Verify")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(verifyButtonBackground)
        }
        .disabled(verificationCode.count != 6 || isVerifying)
        .padding(.top, 24)
    }
    
    private var verifyButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(verificationCode.count == 6 && !isVerifying ? Colors.primary : Colors.tertiary)
    }
    
    private var resendButton: some View {
        Button(action: {
            HapticFeedback.light()
            resendCode()
        }) {
            Text("Resend code")
                .font(.system(size: 15))
                .foregroundColor(Colors.text)
                .underline()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
    
    private var backButton: some View {
        Button(action: {
            HapticFeedback.light()
            dismiss()
        }) {
            LucideIcon(IconHelper.arrowLeft, size: 24, color: Colors.text)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleCodeChange(_ newValue: String) {
        // Limit to 6 digits
        let filtered = newValue.filter { $0.isNumber }
        if filtered.count > 6 {
            verificationCode = String(filtered.prefix(6))
        } else {
            verificationCode = filtered
        }
        
        // Auto-verify when 6 digits entered
        if verificationCode.count == 6 {
            isCodeFieldFocused = false
            verifyCode()
        }
    }
    
    private func verifyCode() {
        guard verificationCode.count == 6 else { return }
        
        isVerifying = true
        showError = false
        
        Task {
            do {
                // verificationID contains the phone number
                try await authService.verifyOTP(phone: verificationID, token: verificationCode)
                
                // Successfully verified - user is automatically logged in
                await MainActor.run {
                    isVerifying = false
                }
                print("✅ Phone verification successful")
            } catch {
                await MainActor.run {
                    showError = true
                    errorMessage = "Invalid code. Please try again."
                    isVerifying = false
                    verificationCode = ""
                    
                    // Refocus on input field
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isCodeFieldFocused = true
                    }
                }
            }
        }
    }
    
    private func resendCode() {
        // Navigate back to phone number page to resend
        dismiss()
    }
}

#Preview {
    NavigationStack {
        VerificationCodePage(phoneNumber: "+48 790 221 569", verificationID: "+48790221569")
            .environmentObject(SupabaseAuthService.shared)
    }
}
