//
//  AuthenticationState.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/25/25.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

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
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    static let shared = AuthenticationManager()
    
    private init() {
        setAuthState(.authenticating)
        setupAuthStateListener()
    }

    private let cachedUserKey = "auth.cachedUser"

    private func setAuthState(_ state: AuthenticationState) {
        DispatchQueue.main.async {
            self.authState = state
        }
    }

    private func setCurrentUser(_ user: PointUser?) {
        DispatchQueue.main.async {
            self.currentUser = user
        }
    }

    private func cacheUser(_ user: PointUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: cachedUserKey)
        }
    }

    private func loadCachedUser() -> PointUser? {
        guard let data = UserDefaults.standard.data(forKey: cachedUserKey),
              let user = try? JSONDecoder().decode(PointUser.self, from: data) else {
            return nil
        }
        return user
    }

    private func clearCachedUser() {
        UserDefaults.standard.removeObject(forKey: cachedUserKey)
    }
    
    // MARK: - Check Current Auth Status
    func checkAuthStatus() {
        if let user = Auth.auth().currentUser {
            if let cached = loadCachedUser(), cached.id == user.uid {
                setCurrentUser(cached)
                applyDevOverridesIfNeeded(for: cached)
                setAuthState(.authenticated(cached))
            } else {
                setAuthState(.authenticating)
            }

            // Force token refresh to ensure valid credentials before Firestore calls
            user.getIDTokenForcingRefresh(true) { [weak self] _, error in
                if let error = error {
                    print("🔐 Token refresh failed: \(error.localizedDescription)")
                    // Token refresh failed - sign out for fresh login
                    self?.signOut()
                    return
                }
                // Token refreshed successfully, now fetch profile
                self?.fetchUserProfile(userId: user.uid)
            }
        } else {
            setAuthState(.unauthenticated)
        }
    }

    private func setupAuthStateListener() {
        guard authStateListenerHandle == nil else { return }
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                if let cached = self.loadCachedUser(), cached.id == user.uid {
                    self.setCurrentUser(cached)
                    self.applyDevOverridesIfNeeded(for: cached)
                    self.setAuthState(.authenticated(cached))
                } else {
                    self.setAuthState(.authenticating)
                    self.fetchUserProfile(userId: user.uid)
                }
            } else {
                self.setCurrentUser(nil)
                self.setAuthState(.unauthenticated)
            }
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
                    setAuthState(.error("Invalid state: A login callback was received, but no login request was sent."))
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    setAuthState(.error("Unable to fetch identity token"))
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    setAuthState(.error("Unable to serialize token string from data"))
                    return
                }
                
                setAuthState(.authenticating)
                
                // Create Firebase credential
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                // Sign in with Firebase
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    if let error = error {
                        self?.setAuthState(.error(error.localizedDescription))
                        return
                    }
                    
                    guard let user = authResult?.user else {
                        self?.setAuthState(.error("Failed to get user"))
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
            setAuthState(.error(error.localizedDescription))
        }
    }
    
    // MARK: - Google Sign-In
    @MainActor
    func signInWithGoogle() async {
        setAuthState(.authenticating)

        // Try to get CLIENT_ID from Firebase, or fallback to reading from plist
        let clientID: String
        if let firebaseClientID = FirebaseApp.app()?.options.clientID {
            clientID = firebaseClientID
        } else if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                  let plist = NSDictionary(contentsOfFile: path),
                  let plistClientID = plist["CLIENT_ID"] as? String {
            clientID = plistClientID
            print("📱 Using CLIENT_ID from plist: \(clientID)")
        } else {
            setAuthState(.error("Missing Google Client ID - check GoogleService-Info.plist"))
            return
        }

        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            setAuthState(.error("Unable to get root view controller"))
            return
        }

        do {
            // Start Google Sign-In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                setAuthState(.error("Failed to get ID token"))
                return
            }

            let accessToken = user.accessToken.tokenString

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user

            // Check if user exists in Firestore
            await checkAndCreateGoogleUserProfile(
                firebaseUser: firebaseUser,
                googleUser: user
            )

        } catch {
            setAuthState(.error(error.localizedDescription))
        }
    }

    private func checkAndCreateGoogleUserProfile(firebaseUser: User, googleUser: GIDGoogleUser) async {
        let userId = firebaseUser.uid

        do {
            let document = try await db.collection("users").document(userId).getDocument()

            if document.exists {
                // User exists, fetch profile
                fetchUserProfile(userId: userId)
            } else {
                // Create new user profile
                let displayName = googleUser.profile?.name ?? "Player"
                let email = googleUser.profile?.email ?? firebaseUser.email ?? ""

                let newUser = PointUser(
                    id: userId,
                    displayName: displayName,
                    email: email,
                    createdAt: Date(),
                    lastUpdated: Date()
                )

                try await createUserProfile(newUser)
            }
        } catch {
            setAuthState(.error(error.localizedDescription))
        }
    }

    // MARK: - Email/Password Authentication
    func signUp(email: String, password: String, displayName: String) async {
        setAuthState(.authenticating)
        
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
            setAuthState(.error(error.localizedDescription))
        }
    }
    
    func signIn(email: String, password: String) async {
        setAuthState(.authenticating)
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let userId = authResult.user.uid
            let document = try await db.collection("users").document(userId).getDocument()
            if document.exists {
                fetchUserProfile(userId: userId)
            } else {
                let displayName = authResult.user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = (displayName?.isEmpty == false) ? displayName! : "Player"
                let resolvedEmail = authResult.user.email ?? email
                let newUser = PointUser(
                    id: userId,
                    displayName: resolvedName,
                    email: resolvedEmail,
                    createdAt: Date(),
                    lastUpdated: Date()
                )
                try await createUserProfile(newUser)
            }
        } catch {
            setAuthState(.error(error.localizedDescription))
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
        setCurrentUser(user)
        cacheUser(user)
        setAuthState(.authenticated(user))
    }
    
    private func fetchUserProfile(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            if let error = error {
                let nsError = error as NSError

                // Check for expired/invalid credential - sign out and let user re-authenticate
                let errorMessage = error.localizedDescription.lowercased()
                if errorMessage.contains("expired") || errorMessage.contains("malformed") ||
                   errorMessage.contains("invalid") || nsError.code == 17020 {
                    print("🔐 Auth credential expired - signing out for fresh login")
                    self?.signOut()
                    return
                }

                // Try cached user for other errors
                if let cached = self?.loadCachedUser() {
                    self?.setCurrentUser(cached)
                    self?.applyDevOverridesIfNeeded(for: cached)
                    self?.setAuthState(.authenticated(cached))
                    return
                }

                if nsError.domain == FirestoreErrorDomain,
                   nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                    self?.setAuthState(.error("Unable to load your profile. Please try again or contact support."))
                } else {
                    self?.setAuthState(.error(error.localizedDescription))
                }
                return
            }
            
            guard let document = document,
                  document.exists,
                  let user = try? document.data(as: PointUser.self) else {
                if let cached = self?.loadCachedUser() {
                    self?.setCurrentUser(cached)
                    self?.applyDevOverridesIfNeeded(for: cached)
                    self?.setAuthState(.authenticated(cached))
                    return
                }
                self?.setAuthState(.error("Unable to load your profile. Please try again."))
                return
            }
            
            self?.setCurrentUser(user)
            self?.cacheUser(user)
            self?.applyDevOverridesIfNeeded(for: user)
            self?.setAuthState(.authenticated(user))
        }
    }

    private func applyDevOverridesIfNeeded(for user: PointUser) {
        let devEmail = "brysonhill2nd@yahoo.com"
        guard user.email.lowercased() == devEmail else {
            if ProEntitlements.shared.devOverrideEnabled {
                ProEntitlements.shared.setDevOverride(false)
            }
            return
        }

        if !ProEntitlements.shared.devOverrideEnabled {
            ProEntitlements.shared.setDevOverride(true)
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
    
    // MARK: - Password Reset
    func resetPassword(email: String) async -> (success: Bool, message: String) {
        guard !email.isEmpty else {
            return (false, "Please enter your email address")
        }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return (true, "Password reset email sent! Check your inbox.")
        } catch let error as NSError {
            let errorMessage: String
            switch error.code {
            case AuthErrorCode.invalidEmail.rawValue:
                errorMessage = "Invalid email address"
            case AuthErrorCode.userNotFound.rawValue:
                errorMessage = "No account found with this email"
            default:
                errorMessage = error.localizedDescription
            }
            return (false, errorMessage)
        }
    }

    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()

            // Sign out from Google if needed
            GIDSignIn.sharedInstance.signOut()

            // IMPORTANT: Set auth state to unauthenticated FIRST to show login screen
            // before clearing other data (prevents flash of onboarding)
            setCurrentUser(nil)
            clearCachedUser()
            setAuthState(.unauthenticated)

            // Now safe to clear user-specific data (login screen is already showing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                CompleteUserHealthManager.shared.clearUserData()
                WatchConnectivityManager.shared.clearAllGames()
                XPManager.shared.resetUserData()
                AchievementManager.shared.resetUserData()
                LocationDataManager.shared.resetUserData()

                // Reset Pro status for new user
                ProEntitlements.shared.setPro(false)

                // Clear AppData settings
                UserDefaults.standard.removeObject(forKey: "userSettings")

                // Clear app first launch date so new user gets fresh start
                UserDefaults.standard.removeObject(forKey: "appFirstLaunchDate")

                // Reset onboarding so new user sees it
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                UserDefaults.standard.removeObject(forKey: "selectedSports")

                print("✅ User signed out successfully - all data cleared")
            }
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
