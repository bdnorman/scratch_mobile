import SwiftUI

struct HourlyForecastCard: View {
    let report: WeatherReport

    private enum Item: Identifiable {
        case hour(HourlyForecast, isNow: Bool)
        case sunrise(Date)
        case sunset(Date)

        var id: String {
            switch self {
            case .hour(let forecast, _): return "hour-\(forecast.date.timeIntervalSince1970)"
            case .sunrise(let date): return "sunrise-\(date.timeIntervalSince1970)"
            case .sunset(let date): return "sunset-\(date.timeIntervalSince1970)"
            }
        }

        var date: Date {
            switch self {
            case .hour(let forecast, _): return forecast.date
            case .sunrise(let date), .sunset(let date): return date
            }
        }
    }

    private var items: [Item] {
        let now = report.current.time
        let startIndex = report.hourly.lastIndex { $0.date <= now } ?? 0
        let hours = Array(report.hourly[startIndex..<min(startIndex + 25, report.hourly.count)])
        guard let first = hours.first, let last = hours.last else { return [] }

        var items: [Item] = hours.enumerated().map { offset, forecast in
            .hour(forecast, isNow: offset == 0)
        }
        for day in report.daily {
            if let sunrise = day.sunrise, sunrise > first.date, sunrise < last.date {
                items.append(.sunrise(sunrise))
            }
            if let sunset = day.sunset, sunset > first.date, sunset < last.date {
                items.append(.sunset(sunset))
            }
        }
        return items.sorted { $0.date < $1.date }
    }

    private var summary: String {
        guard let today = report.today else { return "" }
        var parts: [String] = []
        if let probability = today.daytimePrecipitationProbability {
            parts.append("\(probability)% chance of precipitation during daylight hours")
        }
        if let sunset = today.sunset, sunset > report.current.time {
            parts.append("sunset at \(TimeFormat.clock(sunset, in: report.timeZone))")
        } else if let sunrise = report.daily.dropFirst().first?.sunrise {
            parts.append("sunrise at \(TimeFormat.clock(sunrise, in: report.timeZone))")
        }
        guard !parts.isEmpty else { return WeatherCondition.description(for: report.current.weatherCode) }
        let sentence = parts.joined(separator: ", ")
        return sentence.prefix(1).uppercased() + String(sentence.dropFirst()) + "."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
            Divider().overlay(Color.white.opacity(0.3))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 22) {
                    ForEach(items) { item in
                        column(for: item)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func column(for item: Item) -> some View {
        switch item {
        case .hour(let forecast, let isNow):
            VStack(spacing: 6) {
                Text(isNow ? "Now" : TimeFormat.hour(forecast.date, in: report.timeZone))
                    .font(.subheadline.weight(.medium))
                Image(systemName: WeatherCondition.symbol(for: forecast.weatherCode, isDay: forecast.isDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                    .frame(height: 30)
                precipitationLabel(forecast.precipitationProbability)
                Text(TemperatureFormat.degrees(forecast.temperature))
                    .font(.title3.weight(.medium))
            }
        case .sunrise(let date):
            VStack(spacing: 6) {
                Text(TimeFormat.clock(date, in: report.timeZone))
                    .font(.subheadline.weight(.medium))
                Image(systemName: "sunrise.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                    .frame(height: 30)
                Color.clear.frame(height: 12)
                Text("Sunrise")
                    .font(.subheadline.weight(.medium))
            }
        case .sunset(let date):
            VStack(spacing: 6) {
                Text(TimeFormat.clock(date, in: report.timeZone))
                    .font(.subheadline.weight(.medium))
                Image(systemName: "sunset.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                    .frame(height: 30)
                Color.clear.frame(height: 12)
                Text("Sunset")
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    @ViewBuilder
    private func precipitationLabel(_ probability: Int?) -> some View {
        if let probability, probability > 0 {
            Text("\(probability)%")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                .frame(height: 12)
        } else {
            Color.clear.frame(height: 12)
        }
    }
}
