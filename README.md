# Weather

A SwiftUI iPhone app styled after Apple Weather, with two deliberate differences:

1. **Daily chance of precipitation covers daylight only.** For each day the app takes the
   hourly precipitation probability and keeps the maximum between that day's sunrise and
   sunset. An 80% chance of rain at 2 AM no longer turns a dry afternoon into "80%".
   The 10-day rows, the hourly summary line and the "Chance of Rain" tile all use this
   number. The tile also shows the full-day maximum when it differs, so you can compare.
2. **Nearest weather station.** A card shows the closest reporting surface station, how far
   away it is, its elevation, when it last reported, and a small map with both points.

## Requirements

- Xcode 16 or newer (the project uses file-system synchronized groups).
- iOS 17 or newer on the phone.
- No API keys. Forecasts come from [Open-Meteo](https://open-meteo.com); stations come from
  the NOAA Aviation Weather Center METAR feed, with the US National Weather Service station
  list as a fallback.

## Running on your iPhone

1. Open `WeatherApp.xcodeproj`.
2. Select the `WeatherApp` target, then under **Signing & Capabilities** pick your team and
   change the bundle identifier if Xcode asks for a unique one.
3. Plug in your iPhone, pick it as the run destination and press Run.
4. Allow location access when prompted, or tap the list button and search for a city.

Pull down to refresh. The location arrow in the bottom bar returns to your current location;
the list button opens saved cities and search.

## How the daytime rule works

`WeatherApp/Logic/DaytimePrecipitation.swift` holds the calculation. An hourly sample covers
the hour starting at its timestamp. It counts toward the day when that hour overlaps the
sunrise-to-sunset window, so the 6 AM hour counts for a 6:40 AM sunrise and the 5 PM hour
counts for a 5:50 PM sunset, while the 6 PM hour does not. Days with no sunrise or sunset
(polar regions) fall back to the full-day maximum.

## Tests

`WeatherAppTests` uses Swift Testing. Press Cmd+U in Xcode. The tests cover the daytime
filter edge cases and the mapping from the raw Open-Meteo response into the app's models.

## Layout

```
WeatherApp/
  Logic/        DaytimePrecipitation, condition code mapping, formatting helpers
  Models/       Plain value types for locations, forecasts and stations
  Services/     Open-Meteo forecast, geocoding, station lookup, CoreLocation wrapper
  ViewModels/   WeatherViewModel (loading, saved locations, station lookup)
  Views/        Apple-Weather-style SwiftUI screens and cards
WeatherAppTests/
```

## Web version

`docs/index.html` is a standalone, mobile-friendly web version of the same app with the same
daytime-only precipitation rule and nearest-station card. It needs no build step.

- Instant preview from this branch:
  https://raw.githack.com/bdnorman/scratch_mobile/claude/ios-weather-app-daytime-precip-234tc4/docs/index.html
- Permanent URL: enable GitHub Pages (repository Settings, Pages, "Deploy from a branch",
  pick this branch and the `/docs` folder). The page is then served at
  https://bdnorman.github.io/scratch_mobile/

Open it in Safari on your iPhone, allow location access, and use Share, "Add to Home Screen"
to get a full-screen app icon.
