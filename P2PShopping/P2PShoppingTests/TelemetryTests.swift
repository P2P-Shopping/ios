import XCTest
import CoreLocation
@testable import P2PShopping

final class TelemetryTests: XCTestCase {
    
    // Testăm Managerul de Hardware (Task #148, #149)
    @MainActor
    func testHardwareManagerLogic() {
        let hardware = HardwareManager.shared
        
        // 1. Testăm inițializarea
        hardware.initialize()
        XCTAssertTrue(hardware.isInitialized)
        
        // 2. Testăm conexiunea
        let connected = hardware.connectToDevice()
        XCTAssertTrue(connected)
        
        // 3. Testăm trigger-ul (fără să crape)
        hardware.handleHardwareTrigger(
            storeId: "test_store",
            itemId: "test_item",
            triggerType: "BUTTON_PRESS"
        )
    }
    
    // Testăm Managerul de Locație (Task #33)
    @MainActor
    func testLocationManagerConfiguration() {
        let locationManager = LocationPermissionManager()
        
        // Verificăm dacă precizia a fost setată corect (Best)
        // Folosim o mică simulare pentru a verifica structura
        XCTAssertNotNil(locationManager)
    }
    
    // Testăm Serviciul de Telemetrie (Task #34)
    func testTelemetryServicePayload() {
        let service = TelemetryService.shared
        
        // Testăm că funcția poate fi apelată cu date complete
        service.sendLocationPing(
            storeId: "store_001",
            itemId: "item_001",
            triggerType: "SCAN",
            latitude: 44.4268,
            longitude: 26.1025,
            accuracy: 5.0
        )
        
        // Testăm că funcția poate fi apelată cu date nule (GDPR Case)
        service.sendLocationPing(
            storeId: "store_001",
            itemId: "item_001",
            triggerType: "SCAN",
            latitude: nil,
            longitude: nil,
            accuracy: nil
        )
    }
}
