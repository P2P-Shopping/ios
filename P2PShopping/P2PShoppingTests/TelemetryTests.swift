import XCTest
import CoreLocation
import SwiftUI
import WebKit
@testable import P2PShopping

final class TelemetryTests: XCTestCase {
    
    @MainActor
    func testEverythingForCoverage() async {
        // 1. Hardware Manager
        let hardware = HardwareManager.shared
        hardware.initialize()
        XCTAssertTrue(hardware.isInitialized)
        _ = hardware.connectToDevice()
        
        // 2. Location Manager
        let locManager = LocationPermissionManager()
        
        // Verificăm dacă precizia a fost setată corect (CodeRabbit fix)
        XCTAssertEqual(locManager.desiredAccuracy, kCLLocationAccuracyBest)
        
        locManager.requestWhenInUsePermission()
        locManager.permissionGranted = true
        locManager.permissionDenied = true
        locManager.authorizationStatus = .authorizedWhenInUse
        locManager.openAppSettings()
        
        let mockLoc = CLLocation(latitude: 45.0, longitude: 25.0)
        locManager.locationManager(CLLocationManager(), didUpdateLocations: [mockLoc])
        
        // 3. Telemetry Service - Testăm payload-ul (CodeRabbit fix)
        let telemetry = TelemetryService.shared
        let fullPayload = telemetry.makePayload(storeId: "s", itemId: "i", triggerType: "t", latitude: 1, longitude: 1, accuracy: 1)
        XCTAssertEqual(fullPayload["storeId"] as? String, "s")
        XCTAssertEqual(fullPayload["lat"] as? Double, 1)
        
        let nullPayload = telemetry.makePayload(storeId: "s", itemId: "i", triggerType: "t", latitude: nil, longitude: nil, accuracy: nil)
        XCTAssertTrue(nullPayload["lat"] is NSNull)
        XCTAssertTrue(nullPayload["accuracy"] is NSNull)
        
        // 4. ContentView
        // Cazul 1: Permisiune acordată
        locManager.permissionGranted = true
        locManager.permissionDenied = false
        let view1 = ContentView().environmentObject(locManager)
        let controller1 = UIHostingController(rootView: view1)
        _ = controller1.view
        
        // Cazul 2: Permisiune respinsă
        locManager.permissionGranted = false
        locManager.permissionDenied = true
        let view2 = ContentView().environmentObject(locManager)
        let controller2 = UIHostingController(rootView: view2)
        _ = controller2.view
        
        // Cazul 3: Fără permisiune (ecranul inițial)
        locManager.permissionGranted = false
        locManager.permissionDenied = false
        let view3 = ContentView().environmentObject(locManager)
        let controller3 = UIHostingController(rootView: view3)
        _ = controller3.view
        
        // 5. P2PShoppingApp
        let app = P2PShoppingApp()
        XCTAssertNotNil(app)
        
        // 6. Bridge Handler
        let bridge = LocationBridgeHandler(permissionManager: locManager)
        
        class MockScriptMessage: WKScriptMessage {
            let mockName: String
            let mockBody: Any
            override var name: String { return mockName }
            override var body: Any { return mockBody }
            init(name: String, body: Any) {
                self.mockName = name
                self.mockBody = body
                super.init()
            }
        }
        
        let message = MockScriptMessage(name: "locationBridge", body: "requestLocationPermission")
        bridge.userContentController(WKUserContentController(), didReceive: message)
        
        // Așteptăm 1 secundă pentru a permite URLSession să prindă erorile
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
