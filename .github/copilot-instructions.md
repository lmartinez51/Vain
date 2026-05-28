<!-- Copilot / AI agent instructions for the vain_app Flutter workspace -->

# Quick Agent Guide — vain_app

Purpose: help AI coding agents be immediately productive in this Flutter mono-repo.

- **Big picture:** This is a cross-platform Flutter app (mobile + desktop). UI lives under `lib/ui/` and visual constants and colors are centralized in `lib/theme/app_theme.dart`. Firebase is integrated (see `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and generated `lib/firebase_options.dart`). Assets (logo, icons) are in `assets/images/` and referenced directly in widgets (example: `assets/images/vain_logo.png` in `lib/ui/login_page.dart`).

- **Key files / directories:**

  - `lib/main.dart` — app entry.
  - `lib/ui/*.dart` — pages and UI patterns (example: `lib/ui/login_page.dart` uses `_RoundedInput`, `_SocialButton`).
  - `lib/theme/app_theme.dart` — color tokens, sizes, and shared style helpers; prefer using these constants rather than hard-coded colors.
  - `lib/firebase_options.dart` — generated Firebase options; do not hand-edit this file.
  - `pubspec.yaml` — dependencies and fonts (project uses `google_fonts` and `font_awesome_flutter`).
  - `assets/images/` — image assets; maintain file names used in code (e.g. `vain_logo.png`).
  - `test/` — basic widget test present at `test/widget_test.dart`.

- **Build / run / test (how developers run this project):**

  - Install Flutter SDK then run `flutter pub get`.
  - Run on desktop (Windows): `flutter run -d windows`.
  - Run on Android device/emulator: `flutter run -d <device-id>` or in VS Code/Android Studio.
  - Build release APK: `flutter build apk`.
  - Run unit/widget tests: `flutter test`.
  - Linter / analyzer governed by `analysis_options.yaml` — follow existing rules.

- **Conventions & patterns (repo-specific):**

  - Private UI helpers use leading underscore (`_RoundedInput`, `_SocialButton`, `_HeaderSection`) — prefer adding small, focused private widgets for repeated UI patterns.
  - Use `AppTheme` tokens for colors and spacing; avoid hard-coded color literals unless component-specific.
  - Small stateless inputs are represented by thin wrappers around `TextField` (`_RoundedInput`) — follow its constructor shape: `hintText`, `obscureText`, `suffixIcon`.
  - Use `GoogleFonts` and `FontAwesome` — preserve font-family names (e.g., 'Readex Pro' used in headers).
  - Some UI code uses explicit layout heuristics (example: `TabBarView` in `lib/ui/login_page.dart` is given a fixed `height: 500` to avoid layout shifts). Be cautious changing fixed dimensions — verify on multiple platforms.

- **Integration points & external deps:**

  - Firebase plugins (auth, core, firestore) are in `pubspec.yaml`. Platform config files exist under `android/` and `ios/`. If you add or change Firebase services, regenerate `lib/firebase_options.dart` using `flutterfire` CLI.
  - Native platform code exists for desktop (`windows/`, `linux/`, `macos/`) — changes there require platform-specific rebuilds.

- **Examples of in-repo patterns to follow:**

  - Login page input: `lib/ui/login_page.dart` — uses `_RoundedInput(hintText: 'Email')` and a boolean to toggle password visibility via `suffixIcon`.
  - Social buttons: small circular wrappers `_SocialButton` with `FaIcon` and `InkWell` touch feedback.

- **What to avoid / watch outs:**
  - Do not modify generated files (`lib/firebase_options.dart`, platform-generated build files under `build/`).
  - Keep asset paths stable; missing assets often have a fallback (see `errorBuilder` for the logo).
  - When changing global styles, prefer updating `lib/theme/app_theme.dart` so changes propagate consistently.

If anything in this file is unclear or you want more examples (e.g., sample PR edits, common refactors, or tests to run locally), tell me which area and I will expand.
