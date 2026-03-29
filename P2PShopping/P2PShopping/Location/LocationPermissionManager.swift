import Foundation
import CoreLocation
import UIKit
import Foundation
import Combine
import CoreLocation
import UIKit

/// Manages location permission requests for the P2P Shopping app.
/// Issue #26 - [Native] [iOS] Implement when-in-use location permission flow
@MainActor
class LocationPermissionManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var permissionDenied: Bool = false
    @Published var permissionGranted: Bool = false

    // MARK: - Private

    private let locationManager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
        updatePermissionState(for: locationManager.authorizationStatus)
    }

    // MARK: - Public API

    /// Triggers the when-in-use permission dialog.
    func requestWhenInUsePermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            permissionDenied = true
        case .authorizedWhenInUse, .authorizedAlways:
            permissionGranted = true
        @unknown default:
            break
        }
    }

    /// Opens iOS Settings so the user can manually enable location.
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }

    // MARK: - Private Helpers

    private func updatePermissionState(for status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionGranted = true
            permissionDenied = false
        case .denied, .restricted:
            permissionGranted = false
            permissionDenied = true
        case .notDetermined:
            permissionGranted = false
            permissionDenied = false
        @unknown default:
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationPermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            self.updatePermissionState(for: manager.authorizationStatus)
        }
    }
}
