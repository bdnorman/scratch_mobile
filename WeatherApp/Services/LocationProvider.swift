import CoreLocation
import Foundation

enum LocationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied: return "Location access is off. Allow it in Settings or pick a city from the list."
        case .unavailable: return "Your location could not be determined right now."
        }
    }
}

/// Async wrapper around CLLocationManager that resolves a single fix, requesting permission first if needed.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var waitingForAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isDenied: Bool {
        switch manager.authorizationStatus {
        case .denied, .restricted: return true
        default: return false
        }
    }

    func requestLocation() async throws -> CLLocation {
        if let previous = continuation {
            continuation = nil
            previous.resume(throwing: LocationError.unavailable)
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                waitingForAuthorization = true
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                finish(.failure(LocationError.denied))
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForAuthorization else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            return
        case .authorizedWhenInUse, .authorizedAlways:
            waitingForAuthorization = false
            manager.requestLocation()
        default:
            waitingForAuthorization = false
            finish(.failure(LocationError.denied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        finish(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .denied {
            finish(.failure(LocationError.denied))
        } else {
            finish(.failure(LocationError.unavailable))
        }
    }
}
