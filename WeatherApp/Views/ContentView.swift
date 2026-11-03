import SwiftUI

struct ContentView: View {
    @State private var viewModel = WeatherViewModel()
    @State private var showingLocations = false

    var body: some View {
        ZStack {
            WeatherBackground(style: skyStyle)
            content
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(
                title: bottomTitle,
                isCurrentLocation: viewModel.selectedLocation == nil,
                useCurrentLocation: { viewModel.select(nil) },
                showLocations: { showingLocations = true }
            )
        }
        .sheet(isPresented: $showingLocations) {
            LocationListView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadIfNeeded()
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
            WeatherScrollView(report: report, stationState: viewModel.stationState, units: viewModel.units)
                .refreshable {
                    await viewModel.refresh()
                }
        }
    }
}

struct WeatherBackground: View {
    let style: SkyStyle

    var body: some View {
        LinearGradient(colors: style.colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: style.colors)
    }
}

struct WeatherScrollView: View {
    let report: WeatherReport
    let stationState: WeatherViewModel.StationState
    let units: WeatherUnits

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                CurrentConditionsHeader(report: report)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                HourlyForecastCard(report: report)
                DailyForecastCard(report: report, units: units)
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
            Text("Daily chance of precipitation is the highest hourly value between sunrise and sunset.")
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
