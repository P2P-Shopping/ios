import Foundation
import WebKit

/// Task #218 - Bridge for saving/syncing JWT token to native side
class AuthBridgeHandler: NSObject, WKScriptMessageHandler {
    
    /// Called when JS calls: window.webkit.messageHandlers.authBridge.postMessage({action: "saveToken", token: "..."})
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "authBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
        if action == "saveToken", let token = body["token"] as? String {
            print("[P2P iOS] Saving token to UserDefaults")
            UserDefaults.standard.set(token, forKey: "jwt_token")
        } else if action == "clearToken" {
            print("[P2P iOS] Clearing token from UserDefaults")
            UserDefaults.standard.removeObject(forKey: "jwt_token")
        }
    }
}
