import Foundation

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