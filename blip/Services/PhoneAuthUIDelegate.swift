import FirebaseAuth
import UIKit

/// Presents Firebase Phone Auth's reCAPTCHA webview on simulator (and any device
/// where APNs silent-push verification isn't available). Single responsibility:
/// find the topmost view controller and forward present/dismiss to it.
final class PhoneAuthUIDelegate: NSObject, AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        topViewController()?.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        topViewController()?.dismiss(animated: flag, completion: completion)
    }

    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var vc = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}
