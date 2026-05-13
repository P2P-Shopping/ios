import Foundation
import WebKit
import Security

/// Task #218 - Bridge for saving/syncing JWT token to native side
class AuthBridgeHandler: NSObject, WKScriptMessageHandler {
    
    private let service = Bundle.main.bundleIdentifier ?? "com.p2ps.P2PShopping"
    private let account = "jwt_token"

    /// Called when JS calls: window.webkit.messageHandlers.authBridge.postMessage({action: "saveToken", token: "..."})
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "authBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
        if action == "saveToken", let token = body["token"] as? String {
            print("[P2P iOS] Saving token to Keychain")
            saveToKeychain(token: token)
        } else if action == "clearToken" {
            print("[P2P iOS] Clearing token from Keychain")
            deleteFromKeychain()
        }
    }

    private func saveToKeychain(token: String) {
        guard let data = token.data(using: .utf8) else { return }
        
        // Delete existing item if any
        deleteFromKeychain()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Keychain] Error saving token: \(status)")
        }
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
