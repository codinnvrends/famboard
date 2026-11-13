# Google Play store files

Everything Play Console needs for FamBoard, except the app bundle and the
signing key, which are never committed.

| Path | Use |
| --- | --- |
| `metadata/android/<locale>/` | Store listing in Fastlane `supply` layout: `title.txt`, `short_description.txt`, `full_description.txt`, `changelogs/<versionCode>.txt` |
| `metadata/android/<locale>/images/` | `icon.png` (512 × 512), `featureGraphic.png` (1024 × 500), `phoneScreenshots/1..7.png` (1080 × 1920) |
| `privacy-policy.html` | Host on the Sapps website and link it in Play Console |
| `brand/` | Source SVGs for the app icon, themed icon and notification icon |
| `screenshots/` | Renders the raw app screens with a demo family: `flutter test store/screenshots --update-goldens` |

Locales: `en-US` (default) and `hi-IN`.

## Release build

1. Put `key.properties` in `android/` (storePassword, keyPassword, keyAlias, storeFile).
   It and the `.jks` keystore are git-ignored; keep them in a password manager.
2. Bump `version:` in `pubspec.yaml` and `appVersion` in `lib/features/settings/settings_screen.dart`.
3. `flutter build appbundle --release`, then upload
   `build/app/outputs/bundle/release/app-release.aab`.
4. Add `changelogs/<new versionCode>.txt` for each locale.
