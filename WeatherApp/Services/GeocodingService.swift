import Foundation

/// City search backed by the Open-Meteo geocoding API (no key required).
struct GeocodingService {
    var session: URLSession = .shared

    private struct Response: Decodable {
        let results: [Result]?
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let country: String?
            let admin1: String?
        }
    }

    func search(_ query: String) async throws -> [WeatherLocation] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return (decoded.results ?? []).map { result in
            let region = [result.admin1, result.country].compactMap { $0 }.joined(separator: ", ")
            return WeatherLocation(
                name: result.name,
                region: region.isEmpty ? nil : region,
                latitude: result.latitude,
                longitude: result.longitude,
                isCurrentLocation: false
            )
        }
    }
}
