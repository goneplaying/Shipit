//
//  PhoneAuthUIDelegate.swift
//  Shipit
//
//  Created by Christopher Wirkus on 30.12.2025.
//

import UIKit
import FirebaseAuth

class PhoneAuthUIDelegate: NSObject, AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        // Present reCAPTCHA on the main thread
        if Thread.isMainThread {
            presentViewController(viewControllerToPresent, animated: flag, completion: completion)
        } else {
            DispatchQueue.main.sync {
                presentViewController(viewControllerToPresent, animated: flag, completion: completion)
            }
        }
    }
    
    private func presentViewController(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            
            var topViewController = rootViewController
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            
            topViewController.present(viewControllerToPresent, animated: flag, completion: completion)
        } else {
            completion?()
        }
    }
    
    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        // Dismiss reCAPTCHA on the main thread
        if Thread.isMainThread {
            dismissViewController(animated: flag, completion: completion)
        } else {
            DispatchQueue.main.sync {
                dismissViewController(animated: flag, completion: completion)
            }
        }
    }
    
    private func dismissViewController(animated flag: Bool, completion: (() -> Void)?) {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            
            var topViewController = rootViewController
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            
            if topViewController != rootViewController {
                topViewController.dismiss(animated: flag, completion: completion)
            } else {
                completion?()
            }
        } else {
            completion?()
        }
    }
}
