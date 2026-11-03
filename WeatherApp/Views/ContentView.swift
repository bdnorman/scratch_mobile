import SwiftUI

struct ContentView: View {
    @State private var viewModel = WeatherViewModel()
    @State private var showingLocations = false
    @State private var selectedDay: DailyForecast?
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage(Appearance.storageKey) private var appearanceRaw = Appearance.automatic.rawValue

    var body: some View {
        ZStack {
            WeatherBackground(style: skyStyle, black: useBlackBackground)
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(
                title: bottomTitle,
                isCurrentLocation: viewModel.selectedLocation == nil,
                useCurrentLocation: { viewModel.select(nil) },
                showLocations: { showingLocations = true }
            )
        }
        // The weather screen is always light text on a dark surface, whatever the system setting.
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showingLocations) {
            LocationListView(viewModel: viewModel)
        }
        .sheet(item: $selectedDay) { day in
            if let report = viewModel.report {
                DayDetailView(report: report, day: day, units: viewModel.units, black: useBlackBackground)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var useBlackBackground: Bool {
        switch Appearance(rawValue: appearanceRaw) ?? .automatic {
        case .black: return true
        case .sky: return false
        case .automatic: return systemColorScheme == .dark
        }
    }

    private var skyStyle: SkyStyle {
        if let report = viewModel.report {
            return SkyStyle(code: report.current.weatherCode, isDay: report.current.isDay)
        }
        return .clearDay
    }

    private var bottomTitle: String {
        viewModel.report?.location.name ?? viewModel.selectedLocation?.name ?? "My Location"
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
        case .failed(let message):
            ErrorStateView(
                message: message,
                retry: { Task { await viewModel.refresh() } },
                chooseLocation: { showingLocations = true }
            )
        case .loaded(let report):
            WeatherScrollView(report: report, stationState: viewModel.stationState, units: viewModel.units) { day in
                selectedDay = day
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}

struct WeatherBackground: View {
    let style: SkyStyle
    var black = false

    var body: some View {
        ZStack {
            if black {
                // True black for OLED, with a faint wash of the sky colour at the top so conditions still read.
                Color.black
                LinearGradient(
                    colors: [style.colors[0].opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            } else {
                LinearGradient(colors: style.colors, startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: style.colors)
        .animation(.easeInOut(duration: 0.3), value: black)
    }
}

struct WeatherScrollView: View {
    let report: WeatherReport
    let stationState: WeatherViewModel.StationState
    let units: WeatherUnits
    let onSelectDay: (DailyForecast) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                CurrentConditionsHeader(report: report)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                HourlyForecastCard(report: report)
                DailyForecastCard(report: report, units: units, onSelectDay: onSelectDay)
                DetailTilesGrid(report: report, units: units)
                StationCard(state: stationState, location: report.location, units: units)
                AttributionFooter()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    let chooseLocation: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 56))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 12) {
                Button("Try Again", action: retry)
                Button("Choose a City", action: chooseLocation)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.25))
        }
        .padding(32)
        .foregroundStyle(.white)
    }
}

struct BottomBar: View {
    let title: String
    let isCurrentLocation: Bool
    let useCurrentLocation: () -> Void
    let showLocations: () -> Void

    var body: some View {
        HStack {
            Button(action: useCurrentLocation) {
                Image(systemName: isCurrentLocation ? "location.fill" : "location")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer()
            Button(action: showLocations) {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 0.5)
        }
    }
}

struct AttributionFooter: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Forecast by Open-Meteo. Station data by NOAA.")
            Text("Daily chance of precipitation is the highest hourly value between sunrise and sunset. Tap a day for the hourly breakdown.")
                .multilineTextAlignment(.center)
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}
