import Foundation

/// Decoded shape of the Open-Meteo forecast endpoint, requested with `timeformat=unixtime`.
struct OpenMeteoResponse: Decodable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let utcOffsetSeconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily

    struct Current: Decodable {
        let time: Int
        let temperature2m: Double
        let relativeHumidity2m: Int
        let apparentTemperature: Double
        let isDay: Int
        let weatherCode: Int
        let windSpeed10m: Double
        let windDirection10m: Int
        let windGusts10m: Double?
        let surfacePressure: Double
    }

    struct Hourly: Decodable {
        let time: [Int]
        let temperature2m: [Double?]
        let precipitationProbability: [Int?]
        let weatherCode: [Int?]
        let isDay: [Int?]
        let visibility: [Double?]?
        let dewPoint2m: [Double?]?
        let uvIndex: [Double?]?
    }

    struct Daily: Decodable {
        let time: [Int]
        let weatherCode: [Int?]
        let temperature2mMax: [Double?]
        let temperature2mMin: [Double?]
        let sunrise: [Int?]
        let sunset: [Int?]
        let uvIndexMax: [Double?]?
        let precipitationProbabilityMax: [Int?]?
    }
}

enum WeatherServiceError: LocalizedError {
    case badResponse(Int)
    case emptyForecast

    var errorDescription: String? {
        switch self {
        case .badResponse(let status): return "The weather service returned an error (\(status))."
        case .emptyForecast: return "The weather service returned no forecast for this location."
        }
    }
}

struct OpenMeteoService {
    var session: URLSession = .shared

    func fetchReport(for location: WeatherLocation, units: WeatherUnits) async throws -> WeatherReport {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code,is_day,visibility,dew_point_2m,uv_index"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "10"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "temperature_unit", value: units.temperatureParameter),
            URLQueryItem(name: "wind_speed_unit", value: units.windSpeedParameter),
        ]

        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.badResponse(http.statusCode)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(OpenMeteoResponse.self, from: data)
        return try WeatherReportBuilder.makeReport(from: decoded, location: location)
    }
}

/// Turns the raw API arrays into the app's models. Kept separate so it can be unit tested without networking.
enum WeatherReportBuilder {
    static func makeReport(from response: OpenMeteoResponse, location: WeatherLocation, fetchedAt: Date = Date()) throws -> WeatherReport {
        let timeZone = TimeZone(identifier: response.timezone)
            ?? TimeZone(secondsFromGMT: response.utcOffsetSeconds)
            ?? .current

        let hourlyTimes = response.hourly.time.map { Date(timeIntervalSince1970: TimeInterval($0)) }

        let hourly: [HourlyForecast] = hourlyTimes.indices.compactMap { index in
            guard let temperature = value(response.hourly.temperature2m, at: index) else { return nil }
            return HourlyForecast(
                date: hourlyTimes[index],
                temperature: temperature,
                weatherCode: value(response.hourly.weatherCode, at: index) ?? 3,
                precipitationProbability: value(response.hourly.precipitationProbability, at: index),
                isDay: (value(response.hourly.isDay, at: index) ?? 1) == 1
            )
        }

        let samples: [PrecipitationSample] = hourlyTimes.indices.map { index in
            PrecipitationSample(start: hourlyTimes[index], probability: value(response.hourly.precipitationProbability, at: index))
        }

        let dailyTimes = response.daily.time.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        let daily: [DailyForecast] = dailyTimes.indices.compactMap { index in
            guard let high = value(response.daily.temperature2mMax, at: index),
                  let low = value(response.daily.temperature2mMin, at: index) else { return nil }

            let dayStart = dailyTimes[index]
            let dayEnd = index + 1 < dailyTimes.count ? dailyTimes[index + 1] : dayStart.addingTimeInterval(86_400)
            let sunrise = value(response.daily.sunrise, at: index).map { Date(timeIntervalSince1970: TimeInterval($0)) }
            let sunset = value(response.daily.sunset, at: index).map { Date(timeIntervalSince1970: TimeInterval($0)) }

            let allDay = DaytimePrecipitation.maximumProbability(samples: samples, dayStart: dayStart, dayEnd: dayEnd)
                ?? value(response.daily.precipitationProbabilityMax ?? [], at: index)

            let daytime: Int?
            if let sunrise, let sunset {
                daytime = DaytimePrecipitation.maximumProbability(samples: samples, sunrise: sunrise, sunset: sunset)
            } else {
                // Polar day/night: no sunrise or sunset, so fall back to the whole day.
                daytime = allDay
            }

            return DailyForecast(
                date: dayStart,
                weatherCode: value(response.daily.weatherCode, at: index) ?? 3,
                high: high,
                low: low,
                sunrise: sunrise,
                sunset: sunset,
                uvIndexMax: value(response.daily.uvIndexMax ?? [], at: index),
                daytimePrecipitationProbability: daytime,
                allDayPrecipitationProbability: allDay
            )
        }

        guard !daily.isEmpty, !hourly.isEmpty else { throw WeatherServiceError.emptyForecast }

        let currentTime = Date(timeIntervalSince1970: TimeInterval(response.current.time))
        let currentHourIndex = response.hourly.time.lastIndex { $0 <= response.current.time } ?? 0

        let current = CurrentConditions(
            time: currentTime,
            temperature: response.current.temperature2m,
            apparentTemperature: response.current.apparentTemperature,
            humidity: response.current.relativeHumidity2m,
            weatherCode: response.current.weatherCode,
            isDay: response.current.isDay == 1,
            windSpeed: response.current.windSpeed10m,
            windDirection: response.current.windDirection10m,
            windGusts: response.current.windGusts10m,
            pressure: response.current.surfacePressure,
            visibility: value(response.hourly.visibility ?? [], at: currentHourIndex),
            dewPoint: value(response.hourly.dewPoint2m ?? [], at: currentHourIndex),
            uvIndex: value(response.hourly.uvIndex ?? [], at: currentHourIndex)
        )

        return WeatherReport(
            location: location,
            timeZone: timeZone,
            current: current,
            hourly: hourly,
            daily: daily,
            fetchedAt: fetchedAt
        )
    }

    private static func value<T>(_ array: [T?], at index: Int) -> T? {
        guard index >= 0, index < array.count else { return nil }
        return array[index]
    }
}
