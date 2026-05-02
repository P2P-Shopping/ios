import Foundation
import UIKit

/// Unified Data Class for Telemetry.
/// Matches the required backend JSON schema.
struct TelemetryPing: Codable, Identifiable {
    var id: String { pingId }
    let deviceId: String
    let storeId: String
    let itemId: String
    let triggerType: String
    let lat: Double
    let lng: Double
    let accuracyMeters: Double
    let timestamp: Int64
    let pingId: String
}

struct TelemetryBatch: Codable {
    let pings: [TelemetryPing]
}

extension UIDevice {
    /// Returnează un ID unic pentru acest dispozitiv.
    /// Salvează un fallback în UserDefaults dacă identifierForVendor nu este disponibil.
    static var uniqueId: String {
        if let vendorId = current.identifierForVendor?.uuidString {
            return vendorId
        }
        
        let key = "P2PShopping_FallbackDeviceID"
        if let savedId = UserDefaults.standard.string(forKey: key) {
            return savedId
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
