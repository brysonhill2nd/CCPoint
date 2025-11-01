//
//  AuthenticationView.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/25/25.
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingEmailAuth = false
    @State private var isSignUp = true
    
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
                VStack(spacing: 20) {
                    Image("Image") // Your app logo
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(color: .white.opacity(0.2), radius: 10)
                    
                    Text("WatchPoint")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Track every point")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                Spacer()
                
                // Authentication Buttons
                VStack(spacing: 12) {
                    // Continue with Apple - Gray
                    SignInWithAppleButton(
                        .continue,
                        onRequest: { request in
                            authManager.handleSignInWithAppleRequest(request)
                        },
                        onCompletion: { result in
                            authManager.handleSignInWithAppleCompletion(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(height: 56)
                    .cornerRadius(28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.gray.opacity(0.9))
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    
                    // Continue with Google - Gray
                    Button(action: {
                        // TODO: Implement Google Sign In
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            
                            Text("Continue with Google")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gray.opacity(0.9))
                        .cornerRadius(28)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                    
                    // Email Sign Up - Green
                    Button(action: {
                        isSignUp = true
                        showingEmailAuth = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                            
                            Text("Sign up with Email")
                                .font(.system(size: 19, weight: .medium))
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
                        isSignUp = false
                        showingEmailAuth = true
                    }) {
                        Text("Log In")
                            .font(.system(size: 19, weight: .medium))
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
                Text("By continuing, you agree to our\nTerms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(isSignUp: isSignUp)
                .environmentObject(authManager) // CRITICAL: Pass authManager to the sheet
        }
    }
}

struct EmailAuthView: View {
    @EnvironmentObject var authManager: AuthenticationManager // Changed from @StateObject to @EnvironmentObject
    @State var isSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showingPassword = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(isSignUp ? "Sign up to start tracking your games" : "Log in to your account")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        if isSignUp {
                            // Display Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                TextField("John Doe", text: $displayName)
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("email@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
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
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        if !isSignUp {
                            Button("Forgot Password?") {
                                // Handle password reset
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Error Message
                    if case .error(let message) = authManager.authState {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Submit Button
                    VStack(spacing: 16) {
                        Button(action: authenticate) {
                            Group {
                                if case .authenticating = authManager.authState {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Text(isSignUp ? "Create Account" : "Log In")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        }
                        .disabled(!isFormValid || authManager.authState == .authenticating)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        
                        // Switch between Sign Up and Log In
                        Button(action: {
                            withAnimation {
                                isSignUp.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.gray)
                                
                                Text(isSignUp ? "Log In" : "Sign Up")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
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
                Image("google-logo") // You'll need to add Google logo asset
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
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
