import SwiftUI

/// Translucent rounded card with a small uppercase header, as used throughout Apple Weather.
struct WeatherCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(.white)
    }
}

struct CurrentConditionsHeader: View {
    let report: WeatherReport

    var body: some View {
        VStack(spacing: 0) {
            Text(report.location.name)
                .font(.largeTitle.weight(.regular))
            Text(TemperatureFormat.degrees(report.current.temperature))
                .font(.system(size: 100, weight: .thin))
                .padding(.leading, 18)
            Text(WeatherCondition.description(for: report.current.weatherCode))
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
            if let today = report.today {
                Text("H:\(TemperatureFormat.degrees(today.high))  L:\(TemperatureFormat.degrees(today.low))")
                    .font(.title3.weight(.medium))
                    .padding(.top, 2)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 2)
    }
}
