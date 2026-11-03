import SwiftUI

/// Hour-by-hour precipitation breakdown for one forecast day, opened by tapping a row in the daily list.
struct DayDetailView: View {
    let report: WeatherReport
    let day: DailyForecast
    let units: WeatherUnits
    var black = false

    @Environment(\.dismiss) private var dismiss

    private var hours: [HourlyForecast] { report.hourly(for: day) }
    private var daylightHours: [HourlyForecast] { hours.filter { day.isDaylight($0) } }
    private var timeZone: TimeZone { report.timeZone }

    private var title: String {
        day.date.formatted(Date.FormatStyle(timeZone: timeZone).weekday(.wide).month(.abbreviated).day())
    }

    private var daytimeAmount: Double {
        daylightHours.compactMap(\.precipitationAmount).reduce(0, +)
    }

    private var allDayAmount: Double {
        day.precipitationSum ?? hours.compactMap(\.precipitationAmount).reduce(0, +)
    }

    private var peakDaylightHour: HourlyForecast? {
        daylightHours.max { ($0.precipitationProbability ?? -1) < ($1.precipitationProbability ?? -1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    summaryCard
                    chartCard
                    amountCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(WeatherBackground(style: SkyStyle(code: day.weatherCode, isDay: true), black: black))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Cards

    private var summaryCard: some View {
        WeatherCard(title: "Chance of Precipitation", systemImage: "umbrella.fill") {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.daytimePrecipitationProbability.map { "\($0)%" } ?? "--")
                        .font(.system(size: 44, weight: .medium))
                    Text("Daytime max")
                        .font(.subheadline.weight(.medium))
                }
                Divider().overlay(Color.white.opacity(0.3)).frame(height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.allDayPrecipitationProbability.map { "\($0)%" } ?? "--")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Full day max")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Text(windowDescription)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.top, 4)
        }
    }

    private var windowDescription: String {
        guard let sunrise = day.sunrise, let sunset = day.sunset else {
            return "No sunrise or sunset on this day, so the full day is used."
        }
        var text = "Daylight runs from \(TimeFormat.clock(sunrise, in: timeZone)) to \(TimeFormat.clock(sunset, in: timeZone))."
        if let peak = peakDaylightHour, let probability = peak.precipitationProbability, probability > 0 {
            text += " The daytime peak is \(probability)% around \(TimeFormat.hour(peak.date, in: timeZone))."
        }
        return text
    }

    private var chartCard: some View {
        WeatherCard(title: "Hourly Chance", systemImage: "chart.bar.fill") {
            PrecipitationBars(hours: hours, timeZone: timeZone) { day.isDaylight($0) }
            HStack(spacing: 14) {
                legendSwatch(color: PrecipitationBars.daylightColor, label: "Daylight")
                legendSwatch(color: PrecipitationBars.nightColor, label: "Night")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.78))
            .padding(.top, 2)
        }
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private var amountCard: some View {
        WeatherCard(title: "Precipitation Amount", systemImage: "drop.fill") {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(units.formatPrecipitation(daytimeAmount))
                        .font(.title2.weight(.semibold))
                    Text("During daylight")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(units.formatPrecipitation(allDayAmount))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Full day")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            let wetHours = hours.filter { ($0.precipitationAmount ?? 0) > 0 || ($0.precipitationProbability ?? 0) >= 30 }
            if wetHours.isEmpty {
                Text("No precipitation expected at any hour.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(wetHours) { hour in
                        HStack {
                            Text(TimeFormat.hour(hour.date, in: timeZone))
                                .frame(width: 64, alignment: .leading)
                            Image(systemName: WeatherCondition.symbol(for: hour.weatherCode, isDay: hour.isDay))
                                .symbolRenderingMode(.multicolor)
                                .frame(width: 28)
                            Text("\(hour.precipitationProbability ?? 0)%")
                                .foregroundStyle(day.isDaylight(hour) ? PrecipitationBars.daylightColor : .white.opacity(0.7))
                                .frame(width: 48, alignment: .trailing)
                            Spacer()
                            Text(units.formatPrecipitation(hour.precipitationAmount ?? 0))
                                .foregroundStyle(.white.opacity(0.85))
                            if !day.isDaylight(hour) {
                                Image(systemName: "moon.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 7)
                        Divider().overlay(Color.white.opacity(0.2))
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

/// 24 bars, one per hour, with daylight hours in blue and night hours dimmed.
struct PrecipitationBars: View {
    static let daylightColor = Color(red: 0.55, green: 0.85, blue: 1.0)
    static let nightColor = Color.white.opacity(0.3)

    let hours: [HourlyForecast]
    let timeZone: TimeZone
    let isDaylight: (HourlyForecast) -> Bool

    private let chartHeight: CGFloat = 120

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(hours) { hour in
                    let probability = hour.precipitationProbability ?? 0
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isDaylight(hour) ? Self.daylightColor : Self.nightColor)
                        .frame(height: max(CGFloat(probability) / 100 * chartHeight, 2))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .accessibilityLabel("\(TimeFormat.hour(hour.date, in: timeZone)), \(probability) percent")
                }
            }
            .frame(height: chartHeight, alignment: .bottom)
            .background(alignment: .top) {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5)
                        Spacer(minLength: 0)
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(stride(from: 0, to: hours.count, by: 6)), id: \.self) { index in
                    Text(TimeFormat.hour(hours[index].date, in: timeZone))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
        }
    }
}
