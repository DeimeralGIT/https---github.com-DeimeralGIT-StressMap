# StressMap

An interactive Flutter app that visualizes urban stress indicators on a map, helping users understand environmental quality, noise levels, traffic, air quality, and cost of living across cities and towns worldwide.

---

## Features

- **Interactive Map** — Powered by `flutter_map`; pan, zoom, and tap to explore stress indicators for any location.
- **5 Urban Stress Indicators** — Each place is scored across:
  - 🌬️ Air Quality (US AQI via Open-Meteo)
  - 🔊 Noise Pollution (road & rail density)
  - 🚦 Traffic Congestion (road network density)
  - 💰 Cost of Living (place type + population + commercial pressure)
  - 🛡️ Safety (amenity distribution)
- **Filter Panel** — Toggle any combination of indicators on/off; map and detail cards update immediately.
- **Location Detail Card** — Tap a map marker to see a breakdown of all active indicators for that place.
- **Zoom-In Hint** — A contextual chip prompts users to zoom in when the viewport is too broad to load data.
- **5 Languages** — English, Spanish, French, Portuguese, Russian via `easy_localization`.
- **AdMob Banner Ads** — Non-intrusive bottom banner ad unit.

---

## Architecture

```
lib/
├── main.dart                        # App entry point, localization setup
├── models/
│   ├── discovered_place.dart        # Place data model (name, lat, lng, type)
│   ├── indicator_filters.dart       # Active filter state
│   ├── map_bounds.dart              # Viewport bounds + broadness check
│   ├── stress_indicator.dart        # Individual indicator value model
│   └── stress_location.dart         # Aggregated place stress data
├── providers/
│   └── stress_map_controller.dart   # Central ChangeNotifier; viewport loading, filter state, zoom gating
├── screens/
│   └── stress_map_screen.dart       # Main map screen, overlays, filter modal
├── services/
│   ├── stress_aggregation_service.dart  # Orchestrates all fetches per viewport
│   ├── place_discovery_service.dart     # Overpass API — discovers places in bounds
│   ├── urban_signals_service.dart       # Overpass API — road/rail/amenity features per place
│   └── air_quality_service.dart         # Open-Meteo — US AQI per place
├── utils/
│   └── app_logger.dart              # Debug-mode-only structured logger
└── widgets/
    ├── filter_sheet.dart            # Bottom sheet indicator toggles
    ├── legend_card.dart             # Stress level colour legend
    ├── location_detail_card.dart    # Per-place indicator breakdown popup
    ├── settings_sheet.dart          # App settings sheet
    └── admob_bottom_banner.dart     # Google AdMob banner widget
assets/
└── translations/
    ├── en.json
    ├── es.json
    ├── fr.json
    ├── pt.json
    └── ru.json
```

---

## Data Sources

| Data | Source | API |
|---|---|---|
| Places (cities, towns, suburbs) | OpenStreetMap via Overpass API | `https://overpass-api.de/api/interpreter` |
| Urban features (roads, rail, amenities) | OpenStreetMap via Overpass API | `https://overpass-api.de/api/interpreter` |
| Air Quality (US AQI) | Open-Meteo | `https://air-quality-api.open-meteo.com/v1/air-quality` |

All data sources are free and open; no API keys are required for map data or air quality.

---

## Scoring Logic

### Air Quality
Raw US AQI value (0–500+) from Open-Meteo, clamped to 0–100 for display. Lower = better air.

### Noise
Derived from road and railway feature density within a **6 km radius** of each place centroid. Higher road/rail count → higher noise score.

### Traffic
Road network density (motorway, trunk, primary, secondary) within a 6 km radius. Weighted by road class.

### Cost of Living
```
score = placeTypeFactor × 0.55 + populationWeight × 0.30 + commercialPressure × 0.15
```
- Place type factor: `city > town > suburb > village`
- Commercial pressure: ratio of commercial amenities in the area

### Safety
Inverted score based on distribution of safety-related amenities (hospitals, police, fire stations) and absence of risk-correlated features.

---

## Key Constants

| Constant | Value | Description |
|---|---|---|
| `minimumDataZoom` | `6.2` | Minimum map zoom to trigger data loading |
| `maxPlaceLookupSpan` | `2.6°` | Maximum viewport span before place lookup is skipped |
| `_maxPlaces` | `6` | Maximum places loaded per viewport |
| `_signalRadiusKm` | `6.0 km` | Fixed radius around each place for feature queries |

---

## Caching Strategy

- **Place discovery cache** — keyed by viewport bounds rounded to 2 decimal places.
- **Urban signals cache** — keyed per place; features never re-fetched for the same place.
- **Air quality cache** — keyed by coordinates at 1 decimal precision (coarser key to maximise reuse across nearby towns); in-flight deduplication prevents burst requests.
- **Location cache** — assembled `StressLocation` objects cached by place ID; used to skip re-hydration on subsequent viewport loads.
- **Force refresh** — all caches are cleared when the user closes the filter sheet after changing filters.

---

## Dependencies

| Package | Purpose |
|---|---|
| `flutter_map ^8.2.2` | Interactive map rendering |
| `latlong2 ^0.9.1` | Latitude/longitude types |
| `geolocator ^14.0.2` | Device GPS location |
| `easy_localization ^3.0.8` | i18n / translations |
| `provider ^6.1.5` | State management |
| `http ^1.5.0` | HTTP requests |
| `google_mobile_ads ^6.0.0` | AdMob banner ads |

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.10.7
- Dart SDK ≥ 3.0

### Install & Run

```bash
flutter pub get
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

### Build iOS

```bash
flutter build ios --release
```

---

## Localization

Translation files live in `assets/translations/`. To add a new language:

1. Create `assets/translations/<locale>.json` following the structure of `en.json`.
2. Add the locale to the `supportedLocales` list in `main.dart`.
3. Register the asset in `pubspec.yaml` (already covered by the `assets/translations/` glob).

---

## License

This project is proprietary. All rights reserved.

