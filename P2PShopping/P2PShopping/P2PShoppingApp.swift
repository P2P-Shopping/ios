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
    @StateObject private var locationService = LocationService.shared // Task #182
    
    // Componente pentru bridge persistate pentru a preveni deealocarea
    private let webViewConfiguration = WKWebViewConfiguration()
    @State private var bridgeHandler: LocationBridgeHandler?
    
    // Flag pentru a ne asigura că testul rulează o singură dată
    @State private var hasRunDebugTest = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(hardwareManager)
                .environmentObject(locationService) // Adăugat pentru UI
                .onAppear {
                    setupBridge()
                    initializeHardware()
                    // Pornim NetworkMonitor la startup (Task #184)
                    _ = NetworkMonitor.shared
                }
        }
    }
    
    private func setupBridge() {
        // Inițializăm handler-ul și îl salvăm în starea aplicației pentru a fi persistat
        let handler = LocationBridgeHandler(permissionManager: locationManager)
        self.bridgeHandler = handler
        
        // Configurăm controller-ul de conținut
        let contentController = WKUserContentController()
        contentController.add(handler, name: "locationBridge")
        
        // Atașăm controller-ul la configurația WebView-ului care va fi folosită în aplicație
        webViewConfiguration.userContentController = contentController
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
