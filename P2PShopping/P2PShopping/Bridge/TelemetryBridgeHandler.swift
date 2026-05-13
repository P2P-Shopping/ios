import Foundation
import WebKit
import CoreLocation

/// Task #217 - JS Bridge - Telemetry (Ported from Android's WebAppInterface)
class TelemetryBridgeHandler: NSObject, WKScriptMessageHandler {
    
    private let locationManager = CLLocationManager()
    
    /// Called when JS calls: window.webkit.messageHandlers.telemetryBridge.postMessage({action: "postTelemetry", storeId: "...", itemId: "...", triggerType: "..."})
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "telemetryBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
        if action == "postTelemetry" {
            let storeId = body["storeId"] as? String ?? "unknown"
            let itemId = body["itemId"] as? String ?? "unknown"
            let triggerType = body["triggerType"] as? String ?? "WEB_UI"
            
            sendPing(storeId: storeId, itemId: itemId, triggerType: triggerType)
        }
    }
    
    private func sendPing(storeId: String, itemId: String, triggerType: String) {
        // Request current location (one-shot)
        // Since we are already on MainActor (likely), we just get the last known location or current location
        let location = locationManager.location
        
        TelemetryManager.shared.handleNewPing(
            storeId: storeId,
            itemId: itemId,
            triggerType: triggerType,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            accuracy: location?.horizontalAccuracy
        )
    }
}
