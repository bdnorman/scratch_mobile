import SwiftUI

struct LocationListView: View {
    let viewModel: WeatherViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [WeatherLocation] = []
    @State private var isSearching = false

    private static let geocoding = GeocodingService()

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        Button {
                            choose(nil)
                        } label: {
                            Label("My Location", systemImage: "location.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                    if !viewModel.savedLocations.isEmpty {
                        Section("Saved") {
                            ForEach(viewModel.savedLocations) { location in
                                Button {
                                    choose(location)
                                } label: {
                                    LocationRow(location: location)
                                }
                            }
                            .onDelete { offsets in
                                viewModel.removeLocations(at: offsets)
                            }
                        }
                    }
                } else {
                    Section {
                        if isSearching {
                            HStack {
                                ProgressView()
                                Text("Searching...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if results.isEmpty {
                            Text("No matching cities.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(results) { location in
                            Button {
                                viewModel.addLocation(location)
                                choose(location)
                            } label: {
                                LocationRow(location: location)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Weather")
            .searchable(text: $query, prompt: "Search for a city")
            .task(id: query) {
                await runSearch()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func choose(_ location: WeatherLocation?) {
        viewModel.select(location)
        dismiss()
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        isSearching = true
        defer { isSearching = false }
        let found = (try? await Self.geocoding.search(trimmed)) ?? []
        guard !Task.isCancelled else { return }
        results = found
    }
}

private struct LocationRow: View {
    let location: WeatherLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(location.name)
                .foregroundStyle(.primary)
            if let subtitle = location.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
