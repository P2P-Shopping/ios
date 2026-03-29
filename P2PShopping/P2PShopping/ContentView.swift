import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationPermissionManager

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

            } else if locationManager.permissionDenied {
                Label("Location access denied", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.headline)

                Text("Please enable location access in Settings to use P2P Shopping.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button("Open Settings") {
                    locationManager.openAppSettings()
                }
                .buttonStyle(.borderedProminent)

            } else {
                Text("P2P Shopping needs your location to guide you through the store.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button("Allow Location Access") {
                    locationManager.requestWhenInUsePermission()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
