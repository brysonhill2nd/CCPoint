//
//  AuthenticationState.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/25/25.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Authentication State
enum AuthenticationState: Equatable {
    case authenticated(PointUser)
    case authenticating
    case unauthenticated
    case error(String)
    
    static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        case (.authenticating, .authenticating):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}


// MARK: - Authentication Manager
class AuthenticationManager: ObservableObject {
    @Published var authState: AuthenticationState = .unauthenticated
    @Published var currentUser: PointUser?
    
    private var currentNonce: String?
    private let db = Firestore.firestore()
    
    static let shared = AuthenticationManager()
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Check Current Auth Status
    func checkAuthStatus() {
        if let user = Auth.auth().currentUser {
            fetchUserProfile(userId: user.uid)
        } else {
            authState = .unauthenticated
        }
    }
    
    // MARK: - Sign In with Apple
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }
    
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    authState = .error("Invalid state: A login callback was received, but no login request was sent.")
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    authState = .error("Unable to fetch identity token")
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    authState = .error("Unable to serialize token string from data")
                    return
                }
                
                authState = .authenticating
                
                // Create Firebase credential
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                // Sign in with Firebase
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    if let error = error {
                        self?.authState = .error(error.localizedDescription)
                        return
                    }
                    
                    guard let user = authResult?.user else {
                        self?.authState = .error("Failed to get user")
                        return
                    }
                    
                    // Check if user exists in Firestore
                    self?.checkAndCreateUserProfile(
                        firebaseUser: user,
                        appleIDCredential: appleIDCredential
                    )
                }
            }
            
        case .failure(let error):
            authState = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Email/Password Authentication
    func signUp(email: String, password: String, displayName: String) async {
        authState = .authenticating
        
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = authResult.user
            
            // Create user profile
            let newUser = PointUser(
                id: user.uid,
                displayName: displayName,
                email: email,
                createdAt: Date(),
                lastUpdated: Date()
            )
            
            try await createUserProfile(newUser)
            
        } catch {
            authState = .error(error.localizedDescription)
        }
    }
    
    func signIn(email: String, password: String) async {
        authState = .authenticating
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            fetchUserProfile(userId: authResult.user.uid)
        } catch {
            authState = .error(error.localizedDescription)
        }
    }
    
    // MARK: - User Profile Management
    private func checkAndCreateUserProfile(firebaseUser: User, appleIDCredential: ASAuthorizationAppleIDCredential) {
        let userId = firebaseUser.uid
        
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            if let document = document, document.exists {
                // User exists, fetch profile
                self?.fetchUserProfile(userId: userId)
            } else {
                // Create new user profile
                let displayName = appleIDCredential.fullName.map { name in
                    [name.givenName, name.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                } ?? "Player"
                
                let newUser = PointUser(
                    id: userId,
                    displayName: displayName.isEmpty ? "Player" : displayName,
                    email: appleIDCredential.email ?? firebaseUser.email ?? "",
                    createdAt: Date(),
                    lastUpdated: Date()
                )
                
                Task {
                    try await self?.createUserProfile(newUser)
                }
            }
        }
    }
    
    private func createUserProfile(_ user: PointUser) async throws {
        try db.collection("users").document(user.id).setData(from: user)
        currentUser = user
        authState = .authenticated(user)
    }
    
    private func fetchUserProfile(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            if let error = error {
                self?.authState = .error(error.localizedDescription)
                return
            }
            
            guard let document = document,
                  document.exists,
                  let user = try? document.data(as: PointUser.self) else {
                self?.authState = .error("Failed to fetch user profile")
                return
            }
            
            self?.currentUser = user
            self?.authState = .authenticated(user)
        }
    }
    
    func updateUserProfile(_ updates: [String: Any]) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updatesWithTimestamp = updates
        updatesWithTimestamp["lastUpdated"] = Timestamp()
        
        try await db.collection("users").document(userId).updateData(updatesWithTimestamp)
        
        // Refresh user profile
        fetchUserProfile(userId: userId)
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            authState = .unauthenticated
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Computed Properties
    var isAuthenticated: Bool {
        switch authState {
        case .authenticated:
            return true
        default:
            return false
        }
    }
    
    var userId: String? {
        currentUser?.id
    }
    
    // MARK: - Update User Stats
    func incrementGamesPlayed(won: Bool) async {
        guard let user = currentUser else { return }
        
        var updates: [String: Any] = [
            "totalGamesPlayed": user.totalGamesPlayed + 1
        ]
        
        if won {
            updates["totalWins"] = user.totalWins + 1
        }
        
        do {
            try await updateUserProfile(updates)
        } catch {
            print("Failed to update user stats: \(error)")
        }
    }
    
    // MARK: - CloudKit Sync
    func syncUserProfileWithCloudKit() async {
        guard let user = currentUser else { return }
        
        do {
            try await CloudKitManager.shared.saveUserProfile(user)
            print("✅ User profile synced to CloudKit")
        } catch {
            print("Failed to sync user profile to CloudKit: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
