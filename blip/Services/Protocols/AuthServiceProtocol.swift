import Foundation

/// Contract for all authentication operations.
/// Concrete: `AuthService`. Use this type in ViewModels and logic layers so they
/// remain testable without a live Firebase session.
@MainActor
protocol AuthServiceProtocol: ObservableObject {
    var state: AuthState { get }
    var lastError: String? { get }

    func signInWithApple() async
    func signInAnonymously() async
    func startPhoneVerification(phoneE164: String) async throws -> String
    func confirmPhoneCode(verificationID: String, code: String) async throws
    func signOut()
    func deleteAccount() async throws
}

enum AuthState: Equatable {
    case loading
    case signedOut
    case signedIn(uid: String)
}
