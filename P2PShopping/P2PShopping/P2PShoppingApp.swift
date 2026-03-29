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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .onAppear {
                    setupBridge()
                }
        }
    }
    
    private func setupBridge() {
        let contentController = WKUserContentController()
        let bridgeHandler = LocationBridgeHandler(permissionManager: locationManager)
        contentController.add(bridgeHandler, name: "locationBridge")
    }
}
