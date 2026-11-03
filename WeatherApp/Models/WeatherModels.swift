import Foundation

/// A place the app can show weather for.
struct WeatherLocation: Identifiable, Hashable, Codable {
    let name: String
    let region: String?
    let latitude: Double
    let longitude: Double
    let isCurrentLocation: Bool

    var id: String { "\(latitude),\(longitude)" }

    var subtitle: String? {
        if isCurrentLocation { return "My Location" }
        return region
    }
}

/// One hour of forecast. `date` is the start of the hour.
struct HourlyForecast: Identifiable, Hashable {
    let date: Date
    let temperature: Double
    let weatherCode: Int
    let precipitationProbability: Int?
    let isDay: Bool

    var id: Date { date }
}

/// One calendar day of forecast in the location's time zone.
struct DailyForecast: Identifiable, Hashable {
    let date: Date
    let weatherCode: Int
    let high: Double
    let low: Double
    let sunrise: Date?
    let sunset: Date?
    let uvIndexMax: Double?
    /// Highest hourly precipitation probability between sunrise and sunset only.
    /// This is the number the app displays as the day's chance of precipitation.
    let daytimePrecipitationProbability: Int?
    /// Highest hourly precipitation probability across the whole 24 hours (what most apps show).
    let allDayPrecipitationProbability: Int?

    var id: Date { date }
}

struct CurrentConditions: Hashable {
    let time: Date
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let weatherCode: Int
    let isDay: Bool
    let windSpeed: Double
    let windDirection: Int
    let windGusts: Double?
    /// Surface pressure in hPa.
    let pressure: Double
    /// Visibility in meters.
    let visibility: Double?
    let dewPoint: Double?
    let uvIndex: Double?
}

struct WeatherReport {
    let location: WeatherLocation
    let timeZone: TimeZone
    let current: CurrentConditions
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
    let fetchedAt: Date

    var today: DailyForecast? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return daily.first { calendar.isDate($0.date, inSameDayAs: current.time) } ?? daily.first
    }
}

struct WeatherStation: Hashable {
    let identifier: String
    let name: String
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double?
    let distanceMeters: Double
    let lastObservation: Date?
    let source: String
}

/// Units requested from the forecast API and used for labels.
struct WeatherUnits {
    let temperatureParameter: String
    let windSpeedParameter: String
    let windSpeedLabel: String
    let usesCelsius: Bool
    let usesKilometers: Bool

    static var current: WeatherUnits {
        let system = Locale.current.measurementSystem
        let celsius = system != .us
        let kilometers = system == .metric
        return WeatherUnits(
            temperatureParameter: celsius ? "celsius" : "fahrenheit",
            windSpeedParameter: kilometers ? "kmh" : "mph",
            windSpeedLabel: kilometers ? "km/h" : "mph",
            usesCelsius: celsius,
            usesKilometers: kilometers
        )
    }

    static let imperial = WeatherUnits(temperatureParameter: "fahrenheit", windSpeedParameter: "mph", windSpeedLabel: "mph", usesCelsius: false, usesKilometers: false)

    func formatDistance(meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let converted = measurement.converted(to: usesKilometers ? .kilometers : .miles)
        return converted.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
    }

    func formatElevation(meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let converted = measurement.converted(to: usesKilometers ? .meters : .feet)
        return converted.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    func formatVisibility(meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let converted = measurement.converted(to: usesKilometers ? .kilometers : .miles)
        return converted.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    func formatPressure(hectopascals: Double) -> String {
        if usesCelsius {
            return "\(Int(hectopascals.rounded())) hPa"
        }
        let inHg = hectopascals * 0.029_53
        return String(format: "%.2f inHg", inHg)
    }

    /// Temperature in Celsius regardless of display unit, for colour mapping.
    func celsius(_ value: Double) -> Double {
        usesCelsius ? value : (value - 32) * 5 / 9
    }
}

enum TemperatureFormat {
    static func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }
}
