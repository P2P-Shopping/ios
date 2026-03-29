import Foundation
import WebKit

/// Issue #27 - [Bridge] Expose requestLocationPermission() to JS (iOS)
class LocationBridgeHandler: NSObject, WKScriptMessageHandler {
    
    private let permissionManager: LocationPermissionManager
    
    init(permissionManager: LocationPermissionManager) {
        self.permissionManager = permissionManager
    }
    
    /// Called when JS calls: window.webkit.messageHandlers.locationBridge.postMessage("requestLocationPermission")
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "locationBridge",
              let action = message.body as? String,
              action == "requestLocationPermission" else { return }
        
        Task { @MainActor in
            self.permissionManager.requestWhenInUsePermission()
            
            // Wait for the permission result then send it back to JS
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            let result = self.permissionManager.permissionGranted ? "Granted" : "Denied"
            
            let js = "window.onLocationPermissionResult('\(result)')"
            message.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
