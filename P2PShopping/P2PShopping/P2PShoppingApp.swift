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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(hardwareManager)
                .environmentObject(locationService) // Adăugat pentru UI
                .onAppear {
                    initializeHardware()
                    // Pornim NetworkMonitor la startup (Task #184)
                    _ = NetworkMonitor.shared
                }
        }
    }
    
    private func initializeHardware() {
        hardwareManager.locationManager = locationManager // Legătura necesară pentru Task #34
        hardwareManager.initialize()
    }
}
