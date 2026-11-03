import SwiftUI

struct DetailTilesGrid: View {
    let report: WeatherReport
    let units: WeatherUnits

    private static let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 14) {
            precipitationTile
            uvTile
            sunTile
            windTile
            feelsLikeTile
            humidityTile
            visibilityTile
            pressureTile
        }
    }

    // MARK: - Tiles

    private var precipitationTile: some View {
        DetailTile(title: "Chance of Rain", systemImage: "umbrella.fill") {
            if let today = report.today {
                Text(today.daytimePrecipitationProbability.map { "\($0)%" } ?? "--")
                    .font(.system(size: 34, weight: .medium))
                Text("Daytime max")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Text(precipitationFootnote(for: today))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private func precipitationFootnote(for day: DailyForecast) -> String {
        var text: String
        if let sunrise = day.sunrise, let sunset = day.sunset {
            text = "Highest hourly chance between \(TimeFormat.clock(sunrise, in: report.timeZone)) and \(TimeFormat.clock(sunset, in: report.timeZone))."
        } else {
            text = "No sunrise or sunset today, so the full day is used."
        }
        if let allDay = day.allDayPrecipitationProbability, allDay != day.daytimePrecipitationProbability {
            text += " Full-day max is \(allDay)%."
        }
        return text
    }

    private var uvTile: some View {
        DetailTile(title: "UV Index", systemImage: "sun.max.fill") {
            let value = report.current.uvIndex ?? report.today?.uvIndexMax ?? 0
            Text("\(Int(value.rounded()))")
                .font(.system(size: 34, weight: .medium))
            Text(UVIndex.label(value))
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
            GradientMeter(fraction: min(value / 11, 1), colors: [.green, .yellow, .orange, .red, .purple])
            if let maxUV = report.today?.uvIndexMax {
                Text("Today's max is \(Int(maxUV.rounded())).")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var sunTile: some View {
        let today = report.today
        let now = report.current.time
        let showSunset = (today?.sunrise).map { $0 <= now } ?? false
        let primary = showSunset ? today?.sunset : today?.sunrise
        let secondary = showSunset ? report.daily.dropFirst().first?.sunrise : today?.sunset

        return DetailTile(title: showSunset ? "Sunset" : "Sunrise", systemImage: showSunset ? "sunset.fill" : "sunrise.fill") {
            Text(primary.map { TimeFormat.clock($0, in: report.timeZone) } ?? "--")
                .font(.system(size: 30, weight: .medium))
            Spacer(minLength: 0)
            if let secondary {
                Text("\(showSunset ? "Sunrise" : "Sunset"): \(TimeFormat.clock(secondary, in: report.timeZone))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var windTile: some View {
        DetailTile(title: "Wind", systemImage: "wind") {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(report.current.windSpeed.rounded()))")
                    .font(.system(size: 34, weight: .medium))
                Text(units.windSpeedLabel)
                    .font(.subheadline.weight(.medium))
            }
            Text("From the \(WindDirection.compass(report.current.windDirection))")
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
            if let gusts = report.current.windGusts {
                Text("Gusts up to \(Int(gusts.rounded())) \(units.windSpeedLabel).")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var feelsLikeTile: some View {
        DetailTile(title: "Feels Like", systemImage: "thermometer.medium") {
            Text(TemperatureFormat.degrees(report.current.apparentTemperature))
                .font(.system(size: 34, weight: .medium))
            Spacer(minLength: 0)
            Text(feelsLikeFootnote)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var feelsLikeFootnote: String {
        let difference = report.current.apparentTemperature - report.current.temperature
        if difference <= -3 { return "Wind is making it feel colder." }
        if difference >= 3 { return "Humidity is making it feel warmer." }
        return "Similar to the actual temperature."
    }

    private var humidityTile: some View {
        DetailTile(title: "Humidity", systemImage: "humidity.fill") {
            Text("\(report.current.humidity)%")
                .font(.system(size: 34, weight: .medium))
            Spacer(minLength: 0)
            if let dewPoint = report.current.dewPoint {
                Text("The dew point is \(TemperatureFormat.degrees(dewPoint)) right now.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var visibilityTile: some View {
        DetailTile(title: "Visibility", systemImage: "eye.fill") {
            Text(report.current.visibility.map { units.formatVisibility(meters: $0) } ?? "--")
                .font(.system(size: 34, weight: .medium))
            Spacer(minLength: 0)
            Text(visibilityFootnote)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var visibilityFootnote: String {
        guard let meters = report.current.visibility else { return "Visibility is unavailable." }
        if meters >= 16_000 { return "Perfectly clear view." }
        if meters >= 8_000 { return "It's fairly clear right now." }
        if meters >= 2_000 { return "Visibility is somewhat reduced." }
        return "Visibility is poor."
    }

    private var pressureTile: some View {
        DetailTile(title: "Pressure", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            Text(units.formatPressure(hectopascals: report.current.pressure))
                .font(.system(size: 26, weight: .medium))
            Spacer(minLength: 0)
            GradientMeter(fraction: min(max((report.current.pressure - 970) / 70, 0), 1), colors: [.white.opacity(0.4), .white])
            Text("Surface pressure.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

struct DetailTile<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(.white)
    }
}

struct GradientMeter: View {
    let fraction: Double
    let colors: [Color]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                    .offset(x: min(max(CGFloat(fraction) * geometry.size.width - 3, 0), geometry.size.width - 6))
            }
        }
        .frame(height: 6)
    }
}
