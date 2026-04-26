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
    /// Returnează un ID unic pentru acest dispozitiv, cerut de Android (deviceId).
    static var uniqueId: String {
        return current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
