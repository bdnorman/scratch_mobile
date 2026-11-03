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
    /// Expected precipitation amount for the hour, in the requested unit (inches or millimetres).
    let precipitationAmount: Double?
    let isDay: Bool

    var id: Date { date }
}

/// One calendar day of forecast in the location's time zone.
struct DailyForecast: Identifiable, Hashable {
    let date: Date
    /// Start of the following day; hourly samples for this day satisfy `date <= sample < endDate`.
    let endDate: Date
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
    /// Total expected precipitation for the day, in the requested unit.
    let precipitationSum: Double?

    var id: Date { date }

    /// Whether an hourly sample (covering the hour starting at `date`) overlaps this day's daylight.
    func isDaylight(_ hour: HourlyForecast) -> Bool {
        guard let sunrise, let sunset else { return true }
        return hour.date < sunset && hour.date.addingTimeInterval(DaytimePrecipitation.hourLength) > sunrise
    }
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

    /// The hourly samples that belong to `day`, in order.
    func hourly(for day: DailyForecast) -> [HourlyForecast] {
        hourly.filter { $0.date >= day.date && $0.date < day.endDate }
    }
}

/// How the weather screen paints its background.
enum Appearance: String, CaseIterable, Identifiable {
    /// Sky gradient in light mode, black in dark mode.
    case automatic
    case sky
    case black

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .sky: return "Sky"
        case .black: return "Black"
        }
    }

    static let storageKey = "appearance"
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

    var precipitationParameter: String { usesCelsius ? "mm" : "inch" }
    var precipitationLabel: String { usesCelsius ? "mm" : "in" }

    func formatPrecipitation(_ amount: Double) -> String {
        usesCelsius ? String(format: "%.1f mm", amount) : String(format: "%.2f in", amount)
    }

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
