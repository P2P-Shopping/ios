import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationPermissionManager
    @State private var isWebViewLoading = true

    var body: some View {
        // Full screen presentation once granted
        Group {
            if locationManager.permissionGranted {
                ZStack {
                    P2PWebView(
                        url: URL(string: "https://p2p-shopping.app")!, 
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

                    Button("Open Settings") {
                        locationManager.openAppSettings()
                    }
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

                    Button("Allow Location Access") {
                        locationManager.requestWhenInUsePermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
}

#Preview {
    ContentView()
}
