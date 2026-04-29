import Foundation

/// Dispatches a ping.
/// Adapted for the Offline-First architecture (Task #184).
class TelemetryDispatcher {
    static let shared = TelemetryDispatcher()
    
    private let fileURL: URL
    private let syncQueue = DispatchQueue(label: "com.p2pshopping.telemetrySync")
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("telemetry_offline_db.json")
    }
    
    /// Dispatches a ping by saving it locally and attempting a background sync.
    func dispatch(ping: TelemetryPing) {
        print("TelemetryDispatcher: Saving ping locally for batch sync: \(ping.itemId)")
        
        syncQueue.async {
            var pings = self.loadPings()
            pings.append(ping)
            self.savePings(pings)
            
            Task {
                await self.sync()
            }
        }
    }
    
    private func loadPings() -> [TelemetryPing] {
        guard let data = try? Data(contentsOf: fileURL),
              let pings = try? JSONDecoder().decode([TelemetryPing].self, from: data) else {
            return []
        }
        return pings
    }
    
    private func savePings(_ pings: [TelemetryPing]) {
        if let data = try? JSONEncoder().encode(pings) {
            try? data.write(to: fileURL)
        }
    }
    
    /// Matches the TelemetrySyncWorker logic
    func sync() async {
        let pings = syncQueue.sync { loadPings() }
        guard !pings.isEmpty else { return }
        
        // Fetch a maximum of 200 records at a time to comply with backend constraints
        let batchPings = Array(pings.prefix(200))
        let batch = TelemetryBatch(pings: batchPings)
        
        let success = await TelemetryService.shared.sendBatch(batch)
        
        if success {
            syncQueue.async {
                let currentPings = self.loadPings()
                // Remove the ones we just successfully sent using their unique pingId
                let sentIds = Set(batchPings.map { $0.pingId })
                let remaining = currentPings.filter { !sentIds.contains($0.pingId) }
                self.savePings(remaining)
            }
        }
    }
}