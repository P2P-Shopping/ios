import Foundation
import Network
import Combine

/// Serviciu care monitorizează starea rețelei pentru a declanșa sincronizarea (Task #184)
/// și pentru a decide dacă salvăm offline sau trimitem direct (Task #183).
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected: Bool = false
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    private init() {
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { path in
            let status = path.status == .satisfied
            // Folosim Task pentru a reveni pe MainActor în mod sigur (Swift 6 compliant)
            Task { @MainActor in
                let wasConnected = NetworkMonitor.shared.isConnected
                NetworkMonitor.shared.isConnected = status
                
                if status && !wasConnected {
                    print("NetworkMonitor: Conexiune restaurată! Declanșăm sincronizarea batch (Task #184)...")
                    NotificationCenter.default.post(name: .networkRestored, object: nil)
                }
            }
        }
        self.monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkRestored = Notification.Name("networkRestored")
}
