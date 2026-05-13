import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationPermissionManager
    @EnvironmentObject private var locationService: LocationService

    private var webViewURL: URL {
        let key = "WebAppURL"
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "http://localhost:5173"
        return URL(string: value)!
    }

    var body: some View {
        Group {
            if locationManager.permissionGranted {
                // Task #214: Load WebView instead of welcome screen
                ZStack {
                    P2PWebView(url: webViewURL)
                        .edgesIgnoringSafeArea(.all)
                }
                .onAppear {
                        // Pornim background tracking implicit dacă este permis
                        if !locationService.isTracking {
                            locationService.startTracking()
                        }
                    }
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("P2P Shopping")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Divider()

                    if locationManager.permissionDenied {
                        Label("Location access denied", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.headline)

                        Text("Please enable location access in Settings to use P2P Shopping.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Button("Open Settings", action: openSettingsAction)
                        .buttonStyle(.borderedProminent)

                    } else {
                        Text("P2P Shopping needs your location to guide you through the store.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Button("Allow Location Access", action: allowLocationAction)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Testable Actions
    
    func stopTrackingAction() {
        locationService.stopTracking()
    }
    
    func startTrackingAction() {
        locationService.startTracking()
    }
    
    func openSettingsAction() {
        locationManager.openAppSettings()
    }
    
    func allowLocationAction() {
        locationManager.requestWhenInUsePermission()
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationPermissionManager())
        .environmentObject(LocationService.shared)
}
