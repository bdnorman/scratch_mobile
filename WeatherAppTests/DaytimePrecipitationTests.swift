import Foundation
import Testing
@testable import WeatherApp

struct DaytimePrecipitationTests {
    private let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// 2026-11-03 at the given local hour and minute in Los Angeles.
    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: hour, minute: minute))!
    }

    private func day(_ probabilities: [Int?]) -> [PrecipitationSample] {
        precondition(probabilities.count == 24)
        return probabilities.enumerated().map { PrecipitationSample(start: time($0.offset), probability: $0.element) }
    }

    @Test func ignoresHoursOutsideDaylight() {
        // 90% overnight, 10% during the day. Apple Weather would say 90%; we say 10%.
        var probabilities: [Int?] = Array(repeating: 90, count: 24)
        for hour in 7...16 { probabilities[hour] = 10 }
        let samples = day(probabilities)

        let result = DaytimePrecipitation.maximumProbability(samples: samples, sunrise: time(6, 40), sunset: time(17, 50))

        #expect(result == 10)
    }

    @Test func includesPartialHoursAtSunriseAndSunset() {
        var probabilities: [Int?] = Array(repeating: 0, count: 24)
        probabilities[5] = 99   // 5:00-6:00 ends before a 6:40 sunrise: excluded
        probabilities[6] = 35   // 6:00-7:00 straddles sunrise: included
        probabilities[17] = 55  // 17:00-18:00 straddles a 17:50 sunset: included
        probabilities[18] = 99  // 18:00-19:00 starts after sunset: excluded
        let samples = day(probabilities)

        let result = DaytimePrecipitation.maximumProbability(samples: samples, sunrise: time(6, 40), sunset: time(17, 50))

        #expect(result == 55)
    }

    @Test func skipsMissingValues() {
        var probabilities: [Int?] = Array(repeating: nil, count: 24)
        probabilities[12] = 20
        let samples = day(probabilities)

        let result = DaytimePrecipitation.maximumProbability(samples: samples, sunrise: time(6, 40), sunset: time(17, 50))

        #expect(result == 20)
    }

    @Test func returnsNilWithoutDaylightSamples() {
        let samples = day(Array(repeating: 50, count: 24))
        let tomorrow = time(6, 40).addingTimeInterval(86_400)

        let result = DaytimePrecipitation.maximumProbability(samples: samples, sunrise: tomorrow, sunset: tomorrow.addingTimeInterval(36_000))

        #expect(result == nil)
    }

    @Test func returnsNilWhenSunsetPrecedesSunrise() {
        let samples = day(Array(repeating: 50, count: 24))

        let result = DaytimePrecipitation.maximumProbability(samples: samples, sunrise: time(17), sunset: time(6))

        #expect(result == nil)
    }

    @Test func allDayMaximumUsesEveryHour() {
        var probabilities: [Int?] = Array(repeating: 10, count: 24)
        probabilities[2] = 80
        let samples = day(probabilities)

        let result = DaytimePrecipitation.maximumProbability(samples: samples, dayStart: time(0), dayEnd: time(0).addingTimeInterval(86_400))

        #expect(result == 80)
    }
}

struct WeatherReportBuilderTests {
    private let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    private func time(_ hour: Int, _ minute: Int = 0) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return Int(calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: hour, minute: minute))!.timeIntervalSince1970)
    }

    private func response() throws -> OpenMeteoResponse {
        let hours = (0..<24).map { time($0) }
        // Heavy overnight rain, light chance by day.
        let probabilities = (0..<24).map { hour in hour < 6 || hour > 18 ? 85 : 15 }
        let json = """
        {
          "latitude": 37.77, "longitude": -122.42,
          "timezone": "America/Los_Angeles", "utc_offset_seconds": -28800,
          "current": {
            "time": \(time(14)), "temperature_2m": 61.2, "relative_humidity_2m": 55,
            "apparent_temperature": 60.0, "is_day": 1, "weather_code": 2,
            "wind_speed_10m": 9.1, "wind_direction_10m": 280, "wind_gusts_10m": 14.0,
            "surface_pressure": 1015.2
          },
          "hourly": {
            "time": \(hours),
            "temperature_2m": \(Array(repeating: 58.0, count: 24)),
            "precipitation_probability": \(probabilities),
            "weather_code": \(Array(repeating: 2, count: 24)),
            "is_day": \(Array(repeating: 1, count: 24)),
            "visibility": \(Array(repeating: 16093.0, count: 24)),
            "dew_point_2m": \(Array(repeating: 45.0, count: 24)),
            "uv_index": \(Array(repeating: 3.0, count: 24))
          },
          "daily": {
            "time": [\(time(0))],
            "weather_code": [2],
            "temperature_2m_max": [64.0],
            "temperature_2m_min": [52.0],
            "sunrise": [\(time(6, 40))],
            "sunset": [\(time(17, 5))],
            "uv_index_max": [4.0],
            "precipitation_probability_max": [85]
          }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(OpenMeteoResponse.self, from: Data(json.utf8))
    }

    private let location = WeatherLocation(name: "San Francisco", region: "California", latitude: 37.77, longitude: -122.42, isCurrentLocation: false)

    @Test func dailyRowUsesDaytimeMaximum() throws {
        let report = try WeatherReportBuilder.makeReport(from: response(), location: location)

        let today = try #require(report.daily.first)
        #expect(today.daytimePrecipitationProbability == 15)
        #expect(today.allDayPrecipitationProbability == 85)
        #expect(report.timeZone.identifier == "America/Los_Angeles")
    }

    @Test func currentConditionsPickUpHourlyExtras() throws {
        let report = try WeatherReportBuilder.makeReport(from: response(), location: location)

        #expect(report.current.visibility == 16093.0)
        #expect(report.current.dewPoint == 45.0)
        #expect(report.current.uvIndex == 3.0)
        #expect(report.hourly.count == 24)
    }
}
