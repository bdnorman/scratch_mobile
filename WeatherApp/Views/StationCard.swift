import MapKit
import SwiftUI

struct StationCard: View {
    let state: WeatherViewModel.StationState
    let location: WeatherLocation
    let units: WeatherUnits

    var body: some View {
        WeatherCard(title: "Nearest Weather Station", systemImage: "antenna.radiowaves.left.and.right") {
            switch state {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Finding the closest reporting station...")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            case .unavailable(let message):
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            case .found(let station):
                stationDetails(station)
            }
        }
    }

    private func stationDetails(_ station: WeatherStation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(units.formatDistance(meters: station.distanceMeters))
                    .font(.system(size: 34, weight: .medium))
                Text("away")
                    .font(.subheadline.weight(.medium))
            }
            Text(station.name)
                .font(.headline)
            Text(stationSubtitle(station))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))

            StationMap(station: station, location: location)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 4)

            Text("Source: \(station.source)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func stationSubtitle(_ station: WeatherStation) -> String {
        var parts = ["Station \(station.identifier)"]
        if let elevation = station.elevationMeters {
            parts.append("elevation \(units.formatElevation(meters: elevation))")
        }
        if let observed = station.lastObservation {
            parts.append("last report \(TimeFormat.relative(observed))")
        }
        return parts.joined(separator: " · ")
    }
}

struct StationMap: View {
    let station: WeatherStation
    let location: WeatherLocation

    private var stationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
    }

    private var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            Marker(station.identifier, systemImage: "antenna.radiowaves.left.and.right", coordinate: stationCoordinate)
                .tint(.orange)
            Marker(location.isCurrentLocation ? "You" : location.name, systemImage: "mappin", coordinate: locationCoordinate)
                .tint(.blue)
            MapPolyline(coordinates: [locationCoordinate, stationCoordinate])
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
    }
}
