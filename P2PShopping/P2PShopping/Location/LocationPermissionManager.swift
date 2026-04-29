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
    
    // Date de locație pentru Task #33
    @Published var lastLocation: CLLocation?
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var accuracy: Double?

    // MARK: - Public Properties
    
    /// Expunem precizia dorită pentru testare. Task #33
    var desiredAccuracy: CLLocationAccuracy {
        return locationManager.desiredAccuracy
    }

    // MARK: - Private

    private let locationManager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // Cerință Task #33
        authorizationStatus = locationManager.authorizationStatus
        updatePermissionState(for: locationManager.authorizationStatus)
        
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
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
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            permissionGranted = false
            permissionDenied = true
            locationManager.stopUpdatingLocation()
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
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.accuracy = location.horizontalAccuracy
            
            // Privacy/GDPR: Logăm doar precizia, nu și coordonatele exacte
            print("LocationManager: Location updated (Accuracy: \(String(format: "%.2f", location.horizontalAccuracy))m)")
        }
    }
}
