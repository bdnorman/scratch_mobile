import CoreLocation
import Foundation

enum StationError: LocalizedError {
    case noneFound

    var errorDescription: String? {
        "No reporting weather station was found near this location."
    }
}

/// Finds the nearest surface weather station to a coordinate.
///
/// Primary source: NOAA Aviation Weather Center METAR feed, which covers reporting stations worldwide.
/// Fallback: the US National Weather Service observation-station list for the containing grid point.
struct StationService {
    var session: URLSession = .shared

    func nearestStation(to coordinate: CLLocationCoordinate2D) async throws -> WeatherStation {
        for halfSpanDegrees in [1.0, 2.5] {
            if let station = try? await nearestReportingStation(to: coordinate, halfSpanDegrees: halfSpanDegrees) {
                return station
            }
        }
        if let station = try? await nearestNWSStation(to: coordinate) {
            return station
        }
        throw StationError.noneFound
    }

    // MARK: - Aviation Weather Center (global)

    private struct METAR: Decodable {
        let icaoId: String
        let obsTime: Int?
        let lat: Double
        let lon: Double
        let elev: Double?
        let name: String?
    }

    /// Decodes an element or swallows it, so one odd record cannot break the whole list.
    private struct Lossy<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws {
            value = try? Value(from: decoder)
        }
    }

    private func nearestReportingStation(to coordinate: CLLocationCoordinate2D, halfSpanDegrees: Double) async throws -> WeatherStation? {
        let latitudeSpan = halfSpanDegrees
        let longitudeSpan = min(halfSpanDegrees / max(cos(coordinate.latitude * .pi / 180), 0.2), 10)
        let minLat = max(coordinate.latitude - latitudeSpan, -90)
        let maxLat = min(coordinate.latitude + latitudeSpan, 90)
        let minLon = max(coordinate.longitude - longitudeSpan, -180)
        let maxLon = min(coordinate.longitude + longitudeSpan, 180)

        var components = URLComponents(string: "https://aviationweather.gov/api/data/metar")!
        components.queryItems = [
            URLQueryItem(name: "bbox", value: String(format: "%.3f,%.3f,%.3f,%.3f", minLat, minLon, maxLat, maxLon)),
            URLQueryItem(name: "format", value: "json"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        let records = try JSONDecoder().decode([Lossy<METAR>].self, from: data).compactMap(\.value)
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let candidates = records.map { record -> WeatherStation in
            let distance = CLLocation(latitude: record.lat, longitude: record.lon).distance(from: origin)
            return WeatherStation(
                identifier: record.icaoId,
                name: Self.cleanedName(record.name) ?? record.icaoId,
                latitude: record.lat,
                longitude: record.lon,
                elevationMeters: record.elev,
                distanceMeters: distance,
                lastObservation: record.obsTime.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                source: "NOAA Aviation Weather Center"
            )
        }
        return candidates.min { $0.distanceMeters < $1.distanceMeters }
    }

    private static func cleanedName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - National Weather Service (United States)

    private struct NWSPoint: Decodable {
        let properties: Properties
        struct Properties: Decodable {
            let observationStations: URL
        }
    }

    private struct NWSStations: Decodable {
        let features: [Feature]
        struct Feature: Decodable {
            let geometry: Geometry
            let properties: Properties
        }
        struct Geometry: Decodable {
            let coordinates: [Double]
        }
        struct Properties: Decodable {
            let stationIdentifier: String
            let name: String
            let elevation: Elevation?
        }
        struct Elevation: Decodable {
            let value: Double?
        }
    }

    private func nwsRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("WeatherApp (github.com/bdnorman/scratch_mobile)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        return request
    }

    private func nearestNWSStation(to coordinate: CLLocationCoordinate2D) async throws -> WeatherStation? {
        let pointURL = URL(string: String(format: "https://api.weather.gov/points/%.4f,%.4f", coordinate.latitude, coordinate.longitude))!
        let (pointData, pointResponse) = try await session.data(for: nwsRequest(pointURL))
        if let http = pointResponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        let point = try JSONDecoder().decode(NWSPoint.self, from: pointData)

        let (stationData, stationResponse) = try await session.data(for: nwsRequest(point.properties.observationStations))
        if let http = stationResponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        let stations = try JSONDecoder().decode(NWSStations.self, from: stationData)
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let candidates: [WeatherStation] = stations.features.compactMap { feature in
            guard feature.geometry.coordinates.count >= 2 else { return nil }
            let longitude = feature.geometry.coordinates[0]
            let latitude = feature.geometry.coordinates[1]
            return WeatherStation(
                identifier: feature.properties.stationIdentifier,
                name: feature.properties.name,
                latitude: latitude,
                longitude: longitude,
                elevationMeters: feature.properties.elevation?.value,
                distanceMeters: CLLocation(latitude: latitude, longitude: longitude).distance(from: origin),
                lastObservation: nil,
                source: "National Weather Service"
            )
        }
        return candidates.min { $0.distanceMeters < $1.distanceMeters }
    }
}
