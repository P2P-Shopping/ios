import Foundation
import Network
import Combine

/// Serviciu care monitorizează starea rețelei pentru a declanșa sincronizarea (Task #184)
/// și pentru a decide dacă salvăm offline sau trimitem direct (Task #183).
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected: Bool = true
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    private init() {
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { path in
            let status = path.status == .satisfied
            // Folosim Task pentru a reveni pe MainActor în mod sigur (Swift 6 compliant)
            Task { @MainActor in
                if status && !NetworkMonitor.shared.isConnected {
                    print("NetworkMonitor: Conexiune restaurată! Declanșăm sincronizarea batch (Task #184)...")
                    NotificationCenter.default.post(name: .networkRestored, object: nil)
                }
                NetworkMonitor.shared.isConnected = status
            }
        }
        self.monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkRestored = Notification.Name("networkRestored")
}
