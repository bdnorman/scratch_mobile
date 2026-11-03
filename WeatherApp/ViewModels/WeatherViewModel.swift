import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class WeatherViewModel {
    enum LoadState {
        case idle
        case loading
        case loaded(WeatherReport)
        case failed(String)
    }

    enum StationState {
        case idle
        case loading
        case found(WeatherStation)
        case unavailable(String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var stationState: StationState = .idle
    /// `nil` means "use the device's location".
    private(set) var selectedLocation: WeatherLocation?
    private(set) var savedLocations: [WeatherLocation] = []

    let units = WeatherUnits.current

    private let weatherService = OpenMeteoService()
    private let stationService = StationService()
    private let locationProvider = LocationProvider()
    private let geocoder = CLGeocoder()
    private let defaults = UserDefaults.standard
    private var stationTask: Task<Void, Never>?

    private enum Keys {
        static let saved = "savedLocations"
        static let selected = "selectedLocation"
    }

    init() {
        if let data = defaults.data(forKey: Keys.saved),
           let decoded = try? JSONDecoder().decode([WeatherLocation].self, from: data) {
            savedLocations = decoded
        }
        if let data = defaults.data(forKey: Keys.selected),
           let decoded = try? JSONDecoder().decode(WeatherLocation.self, from: data) {
            selectedLocation = decoded
        }
    }

    var report: WeatherReport? {
        if case .loaded(let report) = loadState { return report }
        return nil
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        if case .idle = loadState {
            await refresh()
        }
    }

    func refresh() async {
        if report == nil {
            loadState = .loading
        }
        do {
            let location = try await resolveLocation()
            let fetched = try await weatherService.fetchReport(for: location, units: units)
            loadState = .loaded(fetched)
            startStationLookup(for: location)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func resolveLocation() async throws -> WeatherLocation {
        if let selectedLocation {
            return selectedLocation
        }
        let fix = try await locationProvider.requestLocation()
        let name = await placeName(for: fix) ?? "My Location"
        return WeatherLocation(
            name: name,
            region: nil,
            latitude: fix.coordinate.latitude,
            longitude: fix.coordinate.longitude,
            isCurrentLocation: true
        )
    }

    private func placeName(for location: CLLocation) async -> String? {
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return nil }
        return placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? placemark.name
    }

    private func startStationLookup(for location: WeatherLocation) {
        stationTask?.cancel()
        stationState = .loading
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        stationTask = Task { [self] in
            do {
                let station = try await stationService.nearestStation(to: coordinate)
                guard !Task.isCancelled else { return }
                stationState = .found(station)
            } catch {
                guard !Task.isCancelled else { return }
                stationState = .unavailable(error.localizedDescription)
            }
        }
    }

    // MARK: - Location management

    func select(_ location: WeatherLocation?) {
        selectedLocation = location
        if let location, let data = try? JSONEncoder().encode(location) {
            defaults.set(data, forKey: Keys.selected)
        } else {
            defaults.removeObject(forKey: Keys.selected)
        }
        loadState = .loading
        stationState = .idle
        Task { await self.refresh() }
    }

    func addLocation(_ location: WeatherLocation) {
        guard !savedLocations.contains(where: { $0.id == location.id }) else { return }
        savedLocations.append(location)
        persistSavedLocations()
    }

    func removeLocations(at offsets: IndexSet) {
        let removed = offsets.map { savedLocations[$0] }
        savedLocations = savedLocations.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        persistSavedLocations()
        if let selectedLocation, removed.contains(where: { $0.id == selectedLocation.id }) {
            select(nil)
        }
    }

    private func persistSavedLocations() {
        if let data = try? JSONEncoder().encode(savedLocations) {
            defaults.set(data, forKey: Keys.saved)
        }
    }
}
