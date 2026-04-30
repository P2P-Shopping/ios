import Foundation
import SwiftData
import UIKit

/// Entitatea de bază pentru telemetrie, stocată offline folosind SwiftData (alternativa modernă la CoreData).
/// Task #183 - Offline Cache
@Model
final class TelemetryPing {
    @Attribute(.unique) var id: String
    var deviceId: String
    var storeId: String
    var itemId: String
    var triggerType: String
    var lat: Double
    var lng: Double
    var accuracy: Float
    var timestamp: Int64

    init(id: String = UUID().uuidString,
         deviceId: String,
         storeId: String,
         itemId: String,
         triggerType: String,
         lat: Double,
         lng: Double,
         accuracy: Float,
         timestamp: Int64) {
        self.id = id
        self.deviceId = deviceId
        self.storeId = storeId
        self.itemId = itemId
        self.triggerType = triggerType
        self.lat = lat
        self.lng = lng
        self.accuracy = accuracy
        self.timestamp = timestamp
    }
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
