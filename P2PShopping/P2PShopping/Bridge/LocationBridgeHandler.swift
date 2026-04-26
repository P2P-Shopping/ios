import Foundation
import WebKit
import Combine
import CoreLocation

/// Issue #27 - [Bridge] Expose requestLocationPermission() to JS (iOS)
class LocationBridgeHandler: NSObject, WKScriptMessageHandler {
    
    private let permissionManager: LocationPermissionManager
    private var cancellables = Set<AnyCancellable>()
    
    init(permissionManager: LocationPermissionManager) {
        self.permissionManager = permissionManager
        super.init()
    }
    
    /// Called when JS calls: window.webkit.messageHandlers.locationBridge.postMessage("requestLocationPermission")
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "locationBridge",
              let action = message.body as? String,
              action == "requestLocationPermission" else { return }
        
        // Dacă permisiunea este deja acordată sau refuzată, trimitem rezultatul imediat
        let currentStatus = self.permissionManager.authorizationStatus
        if currentStatus != .notDetermined {
            sendResult(status: currentStatus, to: message.webView)
            return
        }
        
        // Altfel, cerem permisiunea și așteptăm răspunsul via Combine
        Task { @MainActor in
            self.permissionManager.requestWhenInUsePermission()
            
            self.permissionManager.$authorizationStatus
                .filter { $0 != .notDetermined }
                .first() // Luăm doar prima modificare validă
                .timeout(.seconds(30), scheduler: DispatchQueue.main) // Timeout de siguranță
                .sink { [weak self] status in
                    self?.sendResult(status: status, to: message.webView)
                }
                .store(in: &cancellables)
        }
    }
    
    // Expus pentru testare (Coverage)
    func test_sendResult(status: CLAuthorizationStatus, to webView: WKWebView?) {
        sendResult(status: status, to: webView)
    }

    func test_handleAction(action: String, webView: WKWebView?) {
        if action == "requestLocationPermission" {
            let currentStatus = self.permissionManager.authorizationStatus
            if currentStatus != .notDetermined {
                sendResult(status: currentStatus, to: webView)
                return
            }
            
            Task { @MainActor in
                self.permissionManager.requestWhenInUsePermission()
                self.permissionManager.$authorizationStatus
                    .filter { $0 != .notDetermined }
                    .first()
                    .timeout(.seconds(5), scheduler: DispatchQueue.main)
                    .sink { [weak self] status in
                        self?.sendResult(status: status, to: webView)
                    }
                    .store(in: &cancellables)
            }
        }
    }
    
    private func sendResult(status: CLAuthorizationStatus, to webView: WKWebView?) {
        let result: String
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            result = "Granted"
        case .denied:
            result = "Denied"
        case .restricted:
            result = "Restricted"
        case .notDetermined:
            result = "NotDetermined"
        @unknown default:
            result = "Denied"
        }
        
        let js = "window.onLocationPermissionResult('\(result)')"
        DispatchQueue.main.async {
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
