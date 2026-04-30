import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationPermissionManager
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("P2P Shopping")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            if locationManager.permissionGranted {
                Label("Location access granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
                    
                // UI pentru Task-ul #182 (Pornire/Oprire Background Tracking)
                if locationService.isTracking {
                    Button(action: stopTrackingAction) {
                        Label("Stop Background Tracking", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: startTrackingAction) {
                        Label("Start Background Tracking", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }

            } else if locationManager.permissionDenied {
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
