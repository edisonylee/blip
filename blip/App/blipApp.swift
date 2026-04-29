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
    @StateObject private var repo = BlipRepository()
    @StateObject private var moderation = ModerationService()
    @StateObject private var users = UserRepository()
    @StateObject private var deepLinks = DeepLinkRouter()
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(repo)
                .environmentObject(moderation)
                .environmentObject(users)
                .environmentObject(deepLinks)
                .environmentObject(theme)
                .preferredColorScheme(theme.preference.colorScheme)
                .onAppear {
                    appDelegate.users = users
                    appDelegate.deepLinks = deepLinks
                }
                .onOpenURL { url in
                    _ = Auth.auth().canHandle(url)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var users: UserRepository?
    var deepLinks: DeepLinkRouter?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Bypass APNs/reCAPTCHA in debug — disables app verification for phone auth using Firebase Console test numbers.
        #if DEBUG
        // In recent FirebaseAuth versions, AuthSettings initializer is internal; use the existing optional instance.
        // This disables APNs/reCAPTCHA for phone auth in debug when using Firebase Console test numbers.
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        // FCM <-> APNs registration. The aps-environment entitlement is required for
        // real push delivery; without it FCM still issues a token but messages won't arrive.
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
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
        if let deepLink = info["deepLink"] as? String, let url = URL(string: deepLink) {
            Task { @MainActor [deepLinks] in
                deepLinks?.handle(url: url)
            }
        }
        completionHandler()
    }
}
