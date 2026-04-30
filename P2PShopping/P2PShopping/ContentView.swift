import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationPermissionManager
    @EnvironmentObject private var locationService: LocationService
    @State private var isWebViewLoading = true

    var body: some View {
        // Full screen presentation once granted
        Group {
            if locationManager.permissionGranted {
                VStack(spacing: 0) {
                    // UI pentru Task-ul #182 (Pornire/Oprire Background Tracking)
                    if locationService.isTracking {
                        Button(action: stopTrackingAction) {
                            Label("Stop Background Tracking", systemImage: "stop.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding()
                    } else {
                        Button(action: startTrackingAction) {
                            Label("Start Background Tracking", systemImage: "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .padding()
                    }
                    
                    ZStack {
                        P2PWebView(
                            // Pentru dezvoltare locală, folosește adresa serverului tău. Schimbă portul dacă e necesar (ex: 3000).
                            url: URL(string: "http://localhost:8080")!,
                            isLoading: $isWebViewLoading,
                            permissionManager: locationManager
                        )
                        .ignoresSafeArea(edges: .bottom)
                        
                        if isWebViewLoading {
                            ProgressView("Loading...")
                                .padding()
                                .background(Color(UIColor.systemBackground).opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                }
            } else if locationManager.permissionDenied {
                VStack(spacing: 24) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("P2P Shopping")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Divider()
                    
                    Label("Location access denied", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.headline)

                    Text("Please enable location access in Settings to use P2P Shopping.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Button("Open Settings", action: openSettingsAction)
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("P2P Shopping")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Divider()
                    
                    Text("P2P Shopping needs your location to guide you through the store.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Button("Allow Location Access", action: allowLocationAction)
                        .buttonStyle(.borderedProminent)
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
