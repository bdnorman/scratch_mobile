import SwiftUI

struct DailyForecastCard: View {
    let report: WeatherReport
    let units: WeatherUnits
    var onSelectDay: (DailyForecast) -> Void = { _ in }

    private var overallLow: Double { report.daily.map(\.low).min() ?? 0 }
    private var overallHigh: Double { report.daily.map(\.high).max() ?? 1 }

    var body: some View {
        WeatherCard(title: "\(report.daily.count)-Day Forecast", systemImage: "calendar") {
            VStack(spacing: 0) {
                ForEach(Array(report.daily.enumerated()), id: \.element.id) { index, day in
                    Button {
                        onSelectDay(day)
                    } label: {
                        row(for: day, isToday: index == 0)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows the hourly precipitation breakdown")
                    if index < report.daily.count - 1 {
                        Divider().overlay(Color.white.opacity(0.3))
                    }
                }
            }
        }
    }

    private func row(for day: DailyForecast, isToday: Bool) -> some View {
        HStack(spacing: 10) {
            Text(isToday ? "Today" : TimeFormat.weekday(day.date, in: report.timeZone))
                .font(.body.weight(.medium))
                .frame(width: 58, alignment: .leading)

            VStack(spacing: 2) {
                Image(systemName: WeatherCondition.symbol(for: day.weatherCode, isDay: true))
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                    .frame(height: 24)
                if let probability = day.daytimePrecipitationProbability, probability > 0 {
                    Text("\(probability)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                }
            }
            .frame(width: 44)

            Text(TemperatureFormat.degrees(day.low))
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 40, alignment: .trailing)

            TemperatureRangeBar(
                low: day.low,
                high: day.high,
                overallLow: overallLow,
                overallHigh: overallHigh,
                current: isToday ? report.current.temperature : nil,
                units: units
            )

            Text(TemperatureFormat.degrees(day.high))
                .font(.body.weight(.medium))
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct TemperatureRangeBar: View {
    let low: Double
    let high: Double
    let overallLow: Double
    let overallHigh: Double
    let current: Double?
    let units: WeatherUnits

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let span = max(overallHigh - overallLow, 1)
            let startX = width * CGFloat((low - overallLow) / span)
            let endX = width * CGFloat((high - overallLow) / span)
            let barWidth = max(endX - startX, 8)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.25))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                TemperatureColor.color(celsius: units.celsius(low)),
                                TemperatureColor.color(celsius: units.celsius(high)),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth)
                    .offset(x: min(startX, width - barWidth))
                if let current {
                    let x = width * CGFloat((current - overallLow) / span)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                        .offset(x: min(max(x - 3, 0), width - 6))
                }
            }
        }
        .frame(height: 6)
    }
}
