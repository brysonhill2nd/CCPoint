//
//  AuthenticationView.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/25/25.
//

import SwiftUI
import AuthenticationServices
import UIKit

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingSignUp = false
    @State private var showingLogin = false

    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                // Logo and App Name
                VStack(spacing: 10) {
                    Image("logo-trans") // Point app logo asset
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .shadow(color: .white.opacity(0.2), radius: 10)

                    Text("Scorekeeping that ")
                        .font(.custom("Inter", size: 18))
                        .foregroundColor(.white.opacity(0.7))
                    Text("never slips")
                        .font(.custom("Newsreader-Italic", size: 18))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()
                Spacer()

                // Authentication Buttons
                VStack(spacing: 12) {
                    // Continue with Apple
                    SignInWithAppleButton(
                        .continue,
                        onRequest: { request in
                            authManager.handleSignInWithAppleRequest(request)
                        },
                        onCompletion: { result in
                            authManager.handleSignInWithAppleCompletion(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .cornerRadius(28)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

                    // Continue with Google - Gray
                    Button(action: {
                        Task {
                            await authManager.signInWithGoogle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if case .authenticating = authManager.authState {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            } else {
                                GoogleLogo()
                            }

                            Text("Continue with Google")
                                .font(.custom("Inter", size: 19))
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                        .cornerRadius(28)
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
                    }
                    .disabled(authManager.authState == .authenticating)

                    // Email Sign Up - Green
                    Button(action: {
                        showingSignUp = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)

                            Text("Sign up with Email")
                                .font(.custom("Inter", size: 19))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.green)
                        .cornerRadius(28)
                        .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                    }

                    // Log In Button
                    Button(action: {
                        showingLogin = true
                    }) {
                        Text("Log In")
                            .font(.custom("Inter", size: 19))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                            )
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Terms text
                VStack(spacing: 4) {
                    Text("By continuing, you agree to our")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://pointapp.app/terms-of-service")!)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
                        Text("and")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        Link("Privacy Policy", destination: URL(string: "https://pointapp.app/privacy-policy")!)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 40)
            }
        }
        .font(.custom("Inter", size: 16))
        .sheet(isPresented: $showingSignUp) {
            EmailAuthView(isSignUp: true)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingLogin) {
            EmailAuthView(isSignUp: false)
                .environmentObject(authManager)
        }
    }
}

struct EmailAuthView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.adaptiveColors) var colors
    let initialMode: Bool
    @State private var isSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showingPassword = false
    @State private var showingPasswordReset = false
    @State private var resetEmail = ""
    @State private var resetMessage = ""
    @State private var showingResetResult = false
    @Environment(\.dismiss) var dismiss

    init(isSignUp: Bool) {
        self.initialMode = isSignUp
        self._isSignUp = State(initialValue: isSignUp)
    }

    var body: some View {
        NavigationView {
            ZStack {
                colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(colors.textPrimary)
                                    .frame(width: 32, height: 32)
                            }

                            Text(isSignUp ? "Create Account" : "Welcome Back")
                                .font(.system(size: 32, weight: .bold))
                                .tracking(-1)
                                .foregroundColor(colors.textPrimary)

                            Text(isSignUp ? "Sign up to start tracking your games" : "Log in to your account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)

                        // Form Fields
                        VStack(spacing: 16) {
                            if isSignUp {
                                field(label: "Display Name") {
                                    TextField("John Doe", text: $displayName)
                                        .textContentType(.name)
                                        .autocapitalization(.words)
                                }
                            }

                            field(label: "Email") {
                                TextField("email@example.com", text: $email)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }

                            field(label: "Password") {
                                HStack {
                                    if showingPassword {
                                        TextField("••••••••", text: $password)
                                            .textContentType(isSignUp ? .newPassword : .password)
                                    } else {
                                        SecureField("••••••••", text: $password)
                                            .textContentType(isSignUp ? .newPassword : .password)
                                    }

                                    Button(action: { showingPassword.toggle() }) {
                                        Image(systemName: showingPassword ? "eye.slash" : "eye")
                                            .foregroundColor(colors.textSecondary)
                                    }
                                }
                            }

                            if !isSignUp {
                                Button("Forgot Password?") {
                                    resetEmail = email
                                    showingPasswordReset = true
                                }
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(SwissColors.green)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }

                        // Error Message
                        if case .error(let message) = authManager.authState {
                            Text(message)
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(SwissColors.red)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Submit Button
                        VStack(spacing: 16) {
                            Button(action: authenticate) {
                                Group {
                                    if case .authenticating = authManager.authState {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: SwissColors.black))
                                    } else {
                                        Text(isSignUp ? "Create Account" : "Log In")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(SwissColors.black)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(SwissColors.green)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || authManager.authState == .authenticating)
                            .opacity(isFormValid ? 1.0 : 0.5)

                            Button(action: {
                                withAnimation {
                                    isSignUp.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                        .foregroundColor(colors.textSecondary)

                                    Text(isSignUp ? "Log In" : "Sign Up")
                                        .foregroundColor(colors.textPrimary)
                                        .fontWeight(.semibold)
                                }
                                .font(.system(size: 13))
                            }
                        }
                        .padding(.top, 4)

                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Reset Password", isPresented: $showingPasswordReset) {
            TextField("Email", text: $resetEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            Button("Cancel", role: .cancel) {
                showingPasswordReset = false
            }

            Button("Send Reset Link") {
                Task {
                    let result = await authManager.resetPassword(email: resetEmail)
                    resetMessage = result.message
                    showingResetResult = true
                }
            }
        } message: {
            Text("Enter your email address to receive a password reset link")
        }
        .alert("Password Reset", isPresented: $showingResetResult) {
            Button("OK") {
                showingResetResult = false
            }
        } message: {
            Text(resetMessage)
        }
        .preferredColorScheme(.dark)
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(SwissTypography.monoLabel(10))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)

            content()
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colors.borderSubtle, lineWidth: 1)
                )
                .cornerRadius(12)
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !displayName.isEmpty && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private func authenticate() {
        Task {
            if isSignUp {
                await authManager.signUp(email: email, password: password, displayName: displayName)
            } else {
                await authManager.signIn(email: email, password: password)
            }

            if case .authenticated = authManager.authState {
                dismiss()
            }
        }
    }
}

// MARK: - Google Sign In Button Style
// Note: You'll need to implement Google Sign In SDK
struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GoogleLogo()

                Text("Continue with Google")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Google Logo (vector fallback)
struct GoogleLogo: View {
    var body: some View {
        let asset = UIImage(named: "G Logo") ?? UIImage(named: "G-Logo")
        return Group {
            if asset != nil {
                Image("G Logo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "g.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
        }
    }
}
