import Foundation

/// An hourly precipitation-probability sample. `start` is the beginning of the hour it covers.
struct PrecipitationSample: Hashable {
    let start: Date
    let probability: Int?
}

/// Pure functions that reduce hourly precipitation probabilities to a single daily number.
///
/// Apple Weather shows the maximum chance across the whole day. This app instead reports the
/// maximum between sunrise and sunset, so an overnight shower does not turn a dry day into "80%".
enum DaytimePrecipitation {
    static let hourLength: TimeInterval = 3600

    /// Maximum probability among samples whose hour overlaps the interval `[sunrise, sunset]`.
    ///
    /// A sample starting at 6:00 counts toward a 6:40 sunrise because part of that hour is daylight,
    /// and a sample starting at 17:00 counts toward a 17:50 sunset for the same reason. The 18:00
    /// sample after a 17:50 sunset does not count. Returns `nil` when no daylight samples exist.
    static func maximumProbability(
        samples: [PrecipitationSample],
        sunrise: Date,
        sunset: Date,
        sampleLength: TimeInterval = hourLength
    ) -> Int? {
        guard sunset > sunrise else { return nil }
        return samples
            .filter { sample in
                sample.start < sunset && sample.start.addingTimeInterval(sampleLength) > sunrise
            }
            .compactMap(\.probability)
            .max()
    }

    /// Maximum probability among samples that start within `[dayStart, dayEnd)`.
    static func maximumProbability(
        samples: [PrecipitationSample],
        dayStart: Date,
        dayEnd: Date
    ) -> Int? {
        samples
            .filter { $0.start >= dayStart && $0.start < dayEnd }
            .compactMap(\.probability)
            .max()
    }
}
