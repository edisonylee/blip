import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFunctions
import Foundation
import UIKit

@MainActor
final class AuthService: NSObject, ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedIn(uid: String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var lastError: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private var siwaContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.state = user.map { .signedIn(uid: $0.uid) } ?? .signedOut
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple() async {
        do {
            try await performSIWA()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func performSIWA() async throws {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            siwaContinuation = cont
            controller.performRequests()
        }
    }

    // MARK: - Phone fallback (Phase B — invite/contact-sync trigger)

    func startPhoneVerification(phoneE164: String) async throws -> String {
        let verificationID = try await PhoneAuthProvider.provider()
            .verifyPhoneNumber(phoneE164, uiDelegate: nil)
        return verificationID
    }

    func confirmPhoneCode(verificationID: String, code: String) async throws {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        if let user = Auth.auth().currentUser {
            _ = try await user.link(with: credential)
        } else {
            _ = try await Auth.auth().signIn(with: credential)
        }
    }

    // MARK: - Anonymous (DEBUG only — skips real auth on simulator)

    #if DEBUG
    func signInAnonymously() async {
        do {
            _ = try await Auth.auth().signInAnonymously()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
    #endif

    // MARK: - Sign out

    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - Account deletion (App Store requirement for SIWA apps)

    /// Re-authenticates the user (Apple), then calls the `deleteAccount` Cloud Function
    /// which removes Firestore docs, Storage clips, blip memberships, and the auth user.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notSignedIn
        }

        // Re-auth confirms identity in front of a destructive action and refreshes
        // the ID token so the callable function sees fresh auth.
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            try await reauthenticateWithApple(user: user)
        }

        let functions = Functions.functions(region: "us-central1")
        _ = try await functions.httpsCallable("deleteAccount").call()

        // Server-side admin.auth().deleteUser already invalidated the session;
        // signing out clears local cached state.
        try? Auth.auth().signOut()
    }

    private func reauthenticateWithApple(user: User) async throws {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            siwaContinuation = cont
            // Hand off to the existing delegate; on success it will sign in / re-link.
            // Firebase treats a fresh signIn as recent auth, satisfying delete() if we ever fall back to client-side delete.
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "Failed to generate secure nonce")
            for r in randoms where remaining > 0 {
                if r < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            await self.handleAppleAuthorization(authorization)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.siwaContinuation?.resume(throwing: error)
            self.siwaContinuation = nil
        }
    }

    private func handleAppleAuthorization(_ authorization: ASAuthorization) async {
        defer { siwaContinuation = nil }
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let nonce = currentNonce,
            let idTokenData = credential.identityToken,
            let idToken = String(data: idTokenData, encoding: .utf8)
        else {
            siwaContinuation?.resume(throwing: AuthError.invalidAppleCredential)
            return
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            _ = try await Auth.auth().signIn(with: firebaseCredential)
            siwaContinuation?.resume()
        } catch {
            siwaContinuation?.resume(throwing: error)
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}

enum AuthError: LocalizedError {
    case invalidAppleCredential
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Sign in with Apple returned an invalid credential."
        case .notSignedIn:
            return "You're not signed in."
        }
    }
}
