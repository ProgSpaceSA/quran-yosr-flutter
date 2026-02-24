# القرآن الكريم يسر

A Flutter app that renders the complete Quran (6,236 ayahs) using the HafsSmart custom font,
loaded from a bundled SQLite database.

## Package ID
`com.quraner.yosr`

## Features

- Full Quran text via HafsSmart_08 font (private-use Unicode glyphs)
- Bidirectional infinite scroll (chunks of 30 ayahs)
- Surah name headers and Mushaf page markers
- Pinch-to-zoom text scaling
- Dark / Light theme toggle (dark by default)
- Fast-travel navigation: by page number (1–604), surah, or specific ayah
- Full-text search overlay (searches `aya_text_emlaey`, results after 3 chars)
- Auto-scroll with 5 speed levels + play/pause bottom bar
- Splash screen (dark teal background + white SVG logo)
- Persistent scroll position across app restarts (SharedPreferences)
- Clickable links in info dialog (source + contact email)

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Database | SQLite via `sqflite ^2.3.3` |
| Font | HafsSmart_08.ttf |
| SVG | `flutter_svg ^2.0.10` |
| Preferences | `shared_preferences ^2.3.2` |
| Links | `url_launcher ^6.3.1` |

## Running

```bash
flutter pub get
flutter run -d emulator-5554
```

## Building

```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```
lib/main.dart               # Entire app (single-file architecture)
assets/database/quran.db    # Bundled SQLite (6,236 ayahs)
assets/fonts/               # HafsSmart_08.ttf
assets/images/              # SVG logos and icon
android/app/src/main/res/   # Launcher icons + splash background
database/                   # MySQL schema + export script
```

See [DEVLOG.md](DEVLOG.md) for full architecture and development history.
