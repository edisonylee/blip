import AVFoundation
import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import OSLog
import SwiftUI
import UserNotifications

private let appLog = Logger(subsystem: "app.blip.ios", category: "App")

@main
struct blipApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthService()

    init() {
        // Configure a large URLCache so CachedAsyncImage never re-downloads
        // the same profile photo or thumbnail during a session.
        CachedAsyncImage.configureSharedCache()
    }
    @StateObject private var repo = BlipRepository()
    @StateObject private var moderation = ModerationService()
    @StateObject private var users = UserRepository()
    @StateObject private var friendsRepo = FriendsRepository()
    @StateObject private var friendsService = FriendsService()
    @StateObject private var userDirectory = FirestoreUserDirectory()
    @StateObject private var deepLinks = DeepLinkRouter()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(repo)
                .environmentObject(moderation)
                .environmentObject(users)
                .environmentObject(friendsRepo)
                .environmentObject(friendsService)
                .environmentObject(userDirectory)
                .environmentObject(deepLinks)
                .environmentObject(theme)
                // Theme branch: light-only pastel UI — dark mode removed.
                .preferredColorScheme(.light)
                .onAppear {
                    appDelegate.users = users
                    appDelegate.deepLinks = deepLinks
                }
                .onReceive(moderation.$blockedUsers) { friendsRepo.setBlocklist($0) }
                .onOpenURL { url in
                    // Firebase Auth gets first crack (phone/email link verifications).
                    // If it doesn't claim the URL, forward to our router so
                    // `blip://invite?ref=…` and `blip://blip/…` schemes route.
                    if Auth.auth().canHandle(url) { return }
                    deepLinks.handle(url: url)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var users: UserRepository?
    var deepLinks: DeepLinkRouter?

    /// Per-screen orientation gate. CaptureView / ReviewView flip this to
    /// `.landscape` while on screen so the device rotates to match the camera's
    /// landscape-native sensor; rest of the app stays `.portrait`.
    static var lockedOrientation: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.lockedOrientation
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Audio session — `.ambient` + `.mixWithOthers` lets the multiple muted
        // grid players run concurrently. Default `.soloAmbient` causes iOS to
        // pause sibling AVPlayers when a new one starts (bug seen in 2026-05
        // testing: only one cell played at a time on a real device).
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // DEBUG: bypass APNs/reCAPTCHA so Firebase Console "test phone numbers"
        // work on simulator + non-paid-developer devices. Production builds always
        // run real verification (APNs silent push) — see setAPNSToken below.
        #if DEBUG
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        // FCM <-> APNs registration. The aps-environment entitlement is required for
        // real push delivery; without it FCM still issues a token but messages won't arrive.
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications on launch (no permission prompt — that
        // only gates user-visible alerts). Phone Auth needs the APNs token to do
        // silent-push verification in release builds.
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - Permission flow (call only after first sign-in, never on cold launch)

    static func requestNotificationPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
        return granted
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Hand the APNs token to Firebase Auth so phone-auth silent-push
        // verification can complete without falling back to reCAPTCHA.
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        #endif
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        appLog.error("APNs register failed: \(error.localizedDescription, privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.newData)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) { return true }
        return false
    }

    // MARK: - FCM token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        appLog.info("FCM token received")
        Task { [users] in
            try? await users?.addFcmToken(token)
        }
    }

    // MARK: - Notification handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo

        Task { @MainActor [deepLinks] in
            // Priority 1: explicit deepLink payload set by Cloud Function
            if let raw = info["deepLink"] as? String, let url = URL(string: raw) {
                deepLinks?.handle(url: url)
                return
            }
            // Priority 2: route by notification type
            let type = info["type"] as? String ?? ""
            switch type {
            case "friend_request":
                // → open friends tab (handled by app routing to friends page)
                if let url = URL(string: "blip://friends") { deepLinks?.handle(url: url) }
            case "blip_invite", "blip_joined":
                if let blipId = info["blipId"] as? String,
                   let url = URL(string: "blip://blip/\(blipId)") {
                    deepLinks?.handle(url: url)
                }
            case "clip_posted", "nudge":
                if let blipId = info["blipId"] as? String,
                   let url = URL(string: "blip://blip/\(blipId)") {
                    deepLinks?.handle(url: url)
                }
            default:
                break
            }
        }
        completionHandler()
    }
}
