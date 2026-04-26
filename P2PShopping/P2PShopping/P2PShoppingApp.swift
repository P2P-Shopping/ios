//
//  P2PShoppingApp.swift
//  P2PShopping
//
//  Created by George Sandu on 29/03/2026.
//

import SwiftUI
import WebKit

@main
struct P2PShoppingApp: App {
    
    @StateObject private var locationManager = LocationPermissionManager()
    @StateObject private var hardwareManager = HardwareManager.shared
    
    // Flag pentru a ne asigura că testul rulează o singură dată
    @State private var hasRunDebugTest = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(hardwareManager)
                .onAppear {
                    setupBridge()
                    initializeHardware()
                }
        }
    }
    
    private func setupBridge() {
        let contentController = WKUserContentController()
        let bridgeHandler = LocationBridgeHandler(permissionManager: locationManager)
        contentController.add(bridgeHandler, name: "locationBridge")
    }
    
    private func initializeHardware() {
        hardwareManager.locationManager = locationManager // Legătura necesară pentru Task #34
        hardwareManager.initialize()
        
        #if DEBUG
        if !hasRunDebugTest {
            print("P2PShoppingApp: Running Debug test trigger for Task #149...")
            hardwareManager.handleHardwareTrigger(
                storeId: "debug_store_001",
                itemId: "debug_item_999",
                triggerType: "BUTTON_PRESS"
            )
            hasRunDebugTest = true
        }
        #endif
    }
}
