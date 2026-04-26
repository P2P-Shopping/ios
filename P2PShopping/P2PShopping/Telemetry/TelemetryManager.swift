import Foundation
import SwiftData
import UIKit

/// Gestionează fluxul de date: Online (trimite) vs Offline (salvează local).
/// Implementează cerințele de la Task #183 și #184.
@MainActor
class TelemetryManager {
    static let shared = TelemetryManager()
    
    private var container: ModelContainer?
    private var context: ModelContext?
    
    private init() {
        do {
            // Inițializăm baza de date pentru TelemetryPing
            container = try ModelContainer(for: TelemetryPing.self)
            if let container = container {
                context = ModelContext(container)
            }
        } catch {
            print("TelemetryManager: Eroare inițializare SwiftData: \(error)")
        }
        
        // Ascultăm evenimentul de reconectare a rețelei
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkRestored),
            name: .networkRestored,
            object: nil
        )
    }
    
    /// Primit de la HardwareManager sau LocationService
    func handleNewPing(
        storeId: String,
        itemId: String,
        triggerType: String,
        latitude: Double?,
        longitude: Double?,
        accuracy: Double?
    ) {
        if NetworkMonitor.shared.isConnected {
            // Online: Trimitem direct la backend
            TelemetryService.shared.sendLocationPing(
                storeId: storeId,
                itemId: itemId,
                triggerType: triggerType,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy
            )
        } else {
            // Offline: Salvăm în SwiftData (Offline Cache) - Task #183
            guard let context = context else { return }
            
            let ping = TelemetryPing(
                deviceId: UIDevice.uniqueId,
                storeId: storeId,
                itemId: itemId,
                triggerType: triggerType,
                lat: latitude ?? 0.0,
                lng: longitude ?? 0.0,
                accuracy: Float(accuracy ?? 0.0),
                timestamp: Int64(Date().timeIntervalSince1970 * 1000)
            )
            
            context.insert(ping)
            do {
                try context.save()
                print("TelemetryManager: Ping salvat offline (Task #183).")
            } catch {
                print("TelemetryManager: Eroare salvare offline: \(error)")
            }
        }
    }
    
    @objc private func handleNetworkRestored() {
        Task {
            await syncBatch()
        }
    }
    
    /// Sincronizează datele offline cu backend-ul în calupuri de max 200 (Task #184)
    func syncBatch() async {
        guard let context = context else { return }
        
        // Luăm primele 200, cele mai vechi
        var descriptor = FetchDescriptor<TelemetryPing>()
        descriptor.fetchLimit = 200
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
        
        do {
            let pings = try context.fetch(descriptor)
            guard !pings.isEmpty else { return }
            
            print("TelemetryManager: Începem sincronizarea a \(pings.count) ping-uri (Task #184)...")
            
            // Construim array-ul JSON cerut de backend
            let batchPayload = pings.map { ping -> [String: Any] in
                var dict: [String: Any] = [
                    "deviceId": ping.deviceId,
                    "storeId": ping.storeId,
                    "itemId": ping.itemId,
                    "triggerType": ping.triggerType,
                    "timestamp": ping.timestamp
                ]
                
                // Dacă ambele sunt fix 0.0 înseamnă că nu aveam locație la momentul respectiv
                if ping.lat != 0.0 || ping.lng != 0.0 {
                    dict["lat"] = ping.lat
                    dict["lng"] = ping.lng
                    dict["accuracy"] = ping.accuracy
                } else {
                    dict["lat"] = NSNull()
                    dict["lng"] = NSNull()
                    dict["accuracy"] = NSNull()
                }
                return dict
            }
            
            let success = await TelemetryService.shared.sendBatchPings(payload: batchPayload)
            
            if success {
                // Am primit 202 Accepted -> Ștergem doar înregistrările trimise
                for ping in pings {
                    context.delete(ping)
                }
                try context.save()
                print("TelemetryManager: Batch sincronizat cu succes. Am șters datele locale.")
                
                // Dacă erau fix 200, e posibil să mai fie. Apelăm din nou.
                if pings.count == 200 {
                    await syncBatch()
                }
            } else {
                print("TelemetryManager: Sincronizarea batch a eșuat. Păstrăm datele local pentru retry.")
            }
            
        } catch {
            print("TelemetryManager: Eroare la fetch batch: \(error)")
        }
    }
}
