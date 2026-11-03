import SwiftUI

/// Maps WMO weather interpretation codes (as returned by Open-Meteo) to text and SF Symbols.
enum WeatherCondition {
    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53: return "Drizzle"
        case 55: return "Heavy Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61: return "Light Rain"
        case 63: return "Rain"
        case 65: return "Heavy Rain"
        case 66, 67: return "Freezing Rain"
        case 71: return "Light Snow"
        case 73: return "Snow"
        case 75: return "Heavy Snow"
        case 77: return "Snow Grains"
        case 80: return "Light Showers"
        case 81: return "Showers"
        case 82: return "Heavy Showers"
        case 85: return "Snow Showers"
        case 86: return "Heavy Snow Showers"
        case 95: return "Thunderstorms"
        case 96, 99: return "Thunderstorms with Hail"
        default: return "Cloudy"
        }
    }

    static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func isPrecipitation(_ code: Int) -> Bool {
        code >= 51
    }
}

/// Background gradient families that mimic Apple Weather's condition-driven skies.
enum SkyStyle {
    case clearDay, clearNight, cloudyDay, cloudyNight, rain, snow, storm, fog

    init(code: Int, isDay: Bool) {
        switch code {
        case 0, 1, 2: self = isDay ? .clearDay : .clearNight
        case 3: self = isDay ? .cloudyDay : .cloudyNight
        case 45, 48: self = .fog
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 99: self = .storm
        default: self = .rain
        }
    }

    var colors: [Color] {
        switch self {
        case .clearDay:
            return [Color(red: 0.16, green: 0.47, blue: 0.87), Color(red: 0.49, green: 0.73, blue: 0.96)]
        case .clearNight:
            return [Color(red: 0.05, green: 0.08, blue: 0.22), Color(red: 0.16, green: 0.22, blue: 0.42)]
        case .cloudyDay:
            return [Color(red: 0.36, green: 0.47, blue: 0.62), Color(red: 0.58, green: 0.67, blue: 0.78)]
        case .cloudyNight:
            return [Color(red: 0.13, green: 0.16, blue: 0.24), Color(red: 0.27, green: 0.32, blue: 0.42)]
        case .rain:
            return [Color(red: 0.24, green: 0.31, blue: 0.42), Color(red: 0.42, green: 0.50, blue: 0.60)]
        case .snow:
            return [Color(red: 0.45, green: 0.55, blue: 0.68), Color(red: 0.72, green: 0.78, blue: 0.86)]
        case .storm:
            return [Color(red: 0.14, green: 0.16, blue: 0.22), Color(red: 0.32, green: 0.34, blue: 0.42)]
        case .fog:
            return [Color(red: 0.42, green: 0.47, blue: 0.55), Color(red: 0.62, green: 0.66, blue: 0.72)]
        }
    }
}

enum TemperatureColor {
    /// Colour for a temperature expressed in Celsius, from cold blues to hot reds.
    static func color(celsius: Double) -> Color {
        switch celsius {
        case ..<(-10): return Color(red: 0.55, green: 0.65, blue: 1.0)
        case ..<0: return Color(red: 0.40, green: 0.75, blue: 1.0)
        case ..<10: return Color(red: 0.35, green: 0.85, blue: 0.85)
        case ..<18: return Color(red: 0.55, green: 0.85, blue: 0.45)
        case ..<25: return Color(red: 0.98, green: 0.85, blue: 0.30)
        case ..<32: return Color(red: 0.98, green: 0.60, blue: 0.25)
        default: return Color(red: 0.95, green: 0.35, blue: 0.30)
        }
    }
}

enum UVIndex {
    static func label(_ value: Double) -> String {
        switch value {
        case ..<3: return "Low"
        case ..<6: return "Moderate"
        case ..<8: return "High"
        case ..<11: return "Very High"
        default: return "Extreme"
        }
    }
}

enum WindDirection {
    static func compass(_ degrees: Int) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(degrees) + 22.5) / 45.0) % 8
        return names[(index + 8) % 8]
    }
}

enum TimeFormat {
    static func hour(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone).hour(.defaultDigits(amPM: .abbreviated)))
    }

    static func clock(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone).hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits))
    }

    static func weekday(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone).weekday(.abbreviated))
    }

    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}
