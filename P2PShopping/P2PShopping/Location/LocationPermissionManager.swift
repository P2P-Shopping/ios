import Foundation
import CoreLocation
import Combine
import UIKit
import CoreMotion

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
    
    // Motion detection variables matching Android's LocationService
    private let motionManager = CMMotionManager()
    private var isMoving = true
    private var lastMoveTime: TimeInterval = 0
    private let moveDebounceMs: TimeInterval = 2.0
    
    // Device/Store identifiers
    var currentDeviceId = UUID().uuidString
    var currentStoreId = "unknown"
    var currentItemId = "unknown"

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
            startMotionDetection()
        case .denied, .restricted:
            permissionGranted = false
            permissionDenied = true
            locationManager.stopUpdatingLocation()
            stopMotionDetection()
        case .notDetermined:
            permissionGranted = false
            permissionDenied = false
        @unknown default:
            break
        }
    }
    
    // MARK: - Motion Detection (Android Parity)
    
    private func startMotionDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.5 // delay_normal equivalent
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            
            let movingNow = self.calculateIsMoving(x: x, y: y, z: z)
            let currentTime = Date().timeIntervalSince1970
            
            if movingNow {
                if self.lastMoveTime == 0 { self.lastMoveTime = currentTime }
                if !self.isMoving && (currentTime - self.lastMoveTime > self.moveDebounceMs) {
                    self.isMoving = true
                    print("TelemetryService: Motion detected")
                }
                if self.isMoving { self.lastMoveTime = currentTime }
            } else {
                if self.isMoving && (currentTime - self.lastMoveTime > self.moveDebounceMs) {
                    self.isMoving = false
                    print("TelemetryService: Stationary")
                } else if !self.isMoving {
                    self.lastMoveTime = currentTime
                }
            }
        }
    }
    
    private func stopMotionDetection() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func calculateIsMoving(x: Double, y: Double, z: Double) -> Bool {
        // iOS returns acceleration in Gs (1.0 G = 9.81 m/s^2).
        // Android magnitude formula translation to maintain the "> 0.5" threshold:
        let magnitude = sqrt(x * x + y * y + z * z)
        let acceleration = abs(magnitude - 1.0) * 9.81
        return acceleration > 0.5
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
            
            // If we are stationary, iOS might still occasionally fire. Check our motion flag.
            guard self.isMoving else { return }
            
            // Dispatch offline-first ping
            let ping = TelemetryPing(
                deviceId: self.currentDeviceId,
                storeId: self.currentStoreId,
                itemId: self.currentItemId,
                triggerType: "BACKGROUND",
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                accuracyMeters: location.horizontalAccuracy,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                pingId: UUID().uuidString
            )
            
            TelemetryDispatcher.shared.dispatch(ping: ping)
        }
    }
}
