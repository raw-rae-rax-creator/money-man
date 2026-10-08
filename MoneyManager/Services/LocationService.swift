import Foundation
import CoreLocation

/// One-shot location lookups for tagging transactions with where they were added.
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authorizationContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    /// Shows the system permission prompt if the user hasn't answered yet.
    @MainActor
    @discardableResult
    func requestAuthorization() async -> Bool {
        if manager.authorizationStatus == .notDetermined && authorizationContinuation == nil {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        return isAuthorized
    }

    @MainActor
    func currentLocation() async -> CLLocation? {
        guard await requestAuthorization() else { return nil }
        // A request is already running; don't replace its continuation.
        guard locationContinuation == nil else { return nil }

        return await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// Short human-readable place, e.g. "Abay Ave 10, Almaty".
    func placeName(for location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }
        let parts = [placemark.name, placemark.locality].compactMap { $0 }
        var unique: [String] = []
        for part in parts where !unique.contains(part) {
            unique.append(part)
        }
        return unique.isEmpty ? nil : unique.joined(separator: ", ")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Called once right after the delegate is set, too — only resume a pending request.
        guard manager.authorizationStatus != .notDetermined else { return }
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }
}
