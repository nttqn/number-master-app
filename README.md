# Number Master

A Flutter + Flame clone of "Number Master: Run and Merge" (KAYAC, package
`com.kayac.level_up_number`): a 3-lane runner where you carry a number,
grow it through math gates and loose numbers, dodge hazards, and break
through a wall sequence at the end of each level. Levels are procedurally
generated with a difficulty curve — not hand-authored — and every
generated level is guaranteed beatable (see `lib/game/spawner/`).

## Project structure

```
lib/
  main.dart, app.dart          # Entry point, MaterialApp
  models/                      # GateOperation, lane helpers
  services/
    ads_service.dart            # AdMob banner + interstitial (test IDs — see below)
    sound_service.dart          # flame_audio AudioPool wrapper, safe with missing WAVs
    save_service.dart           # shared_preferences: unlocked level, best number per level
  screens/
    menu_screen.dart, game_screen.dart
  widgets/                      # Overlays: level banner, pause, game-over, level-complete, HUD
  game/
    number_master_game.dart     # FlameGame — owns state machine, player, callbacks
    projection.dart              # Pure 2.5D perspective math (distance -> screen pos/scale)
    level_runtime.dart           # Spawns entities from a GeneratedLevel as they enter view
    game_state.dart
    world/                       # RoadComponent (perspective road rendering)
    components/                  # PlayerComponent, TrackEntity + Gate/LooseNumber/Hazard/Wall
    spawner/                     # LevelGenerator, DifficultyParams, SpawnRow (pure Dart, no Flame)
test/
  projection_test.dart           # Unit tests for the perspective math
  level_generator_test.dart      # Unit tests: fairness + wall-feasibility invariants per level
tool/
  patch_signing.js               # CI: wires release signingConfig into build.gradle(.kts)
  proguard-rules-extra.pro       # CI: R8 keep-rule for WorkManager (see below)
.github/workflows/
  build-apk.yml                  # Builds signed APK/AAB on GitHub Actions
```

`android/`, `ios/`, `web/` are **gitignored** and regenerated fresh by CI
(`flutter create`) on every build — no Flutter/Android SDK needed locally
just to edit Dart. See `build-apk.yml` for the exact patch steps (AdMob
manifest entry, minSdk/compileSdk bump, WorkManager R8 fix, release
signing).

## How the game works

- **3 lanes**, swipe left/right to switch. The player's number starts at 1.
- **Math gates**: blue gates add/multiply your number, red gates
  subtract/divide (clamped to a minimum of 1). Different lanes usually
  offer different gates — the choice matters.
- **Loose numbers**: absorb (add to your number) if smaller than your
  current number; instant game over if bigger.
- **Hazards**: non-numeric, block a lane, fatal on contact.
- **Walls** (end of level): a sequence of full-width walls, each requiring
  your number to be at least the wall's value to break through (your
  number is reduced by the wall's value on a successful break). Clearing
  every wall completes the level.
- **Levels are procedural** (`lib/game/spawner/level_generator.dart`):
  deterministic per level number (same seed → same layout), with a
  fairness constraint (every row leaves at least one non-fatal lane) and a
  wall-feasibility check (a worst-case playthrough is simulated to size the
  wall sequence, so a level is never unbeatable) — both enforced *during*
  generation and covered by `test/level_generator_test.dart`.

## Quick local preview (no Android SDK needed)

```
flutter pub get
flutter run -d chrome
```

Or `flutter run -d web-server` for a headless preview. Note: if you're
scripting this with a headless browser (e.g. Playwright) in a sandboxed
environment, the default Flutter web bootstrap fetches CanvasKit from
`gstatic.com` — if that CDN isn't reachable, the app hangs forever with no
error. Route that request to the locally-bundled files under
`build/web/canvaskit/` instead (see CLAUDE.md for the exact `page.route()`
snippet used during development). Also note Flutter's canvas lives inside
`<flt-glass-pane>`'s **shadow DOM** — `document.querySelectorAll('canvas')`
from the top document won't find it.

## Running tests

```
flutter test
```

Covers the projection math and the level generator's fairness/feasibility
invariants across a spread of levels — the cheapest place to catch level-
design bugs, before ever looking at them rendered.

## Sound

`assets/audio/` currently has no real WAV files — `SoundService` is
designed to be safe with zero or partial audio assets (every load is
try/catch + timeout guarded, and the whole init is fire-and-forget from
`main()` so a hung/missing asset can never block the app from rendering).
Add real files matching the names in `lib/services/sound_service.dart`'s
`SfxEvent` enum (`swipe.wav`, `gate_good.wav`, `gate_bad.wav`, `absorb.wav`,
`death.wav`, `wall_break.wav`, `level_complete.wav`, `button_tap.wav`) to
`assets/audio/` whenever they're available — no code changes needed.

## Before publishing to Google Play — checklist

1. **Real AdMob account** — register at https://admob.google.com, create a
   Banner and an Interstitial ad unit, replace the test IDs in
   [lib/services/ads_service.dart](lib/services/ads_service.dart), and add
   the app's AdMob **App ID** as the `ADMOB_APP_ID` GitHub secret.
2. **Release signing** — generate a keystore and add `KEYSTORE_BASE64`,
   `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` as GitHub secrets (same
   flow as every other app in this series). Without them, CI stays
   debug-signed (fine for sideloading, not for a Play Store upload).
3. **Package name** — currently `com.trungsmail.numbermaster` (`--org
   com.trungsmail` in `build-apk.yml`); change there if needed.
4. **Icon** — replace `assets/icon/icon.png` (a placeholder generated via
   PowerShell + System.Drawing, no real art yet).
5. **Play Games Services / leaderboard** — not wired up yet in this
   project (deliberately deferred, matching how every prior game in this
   series added it near publish time rather than upfront).
6. **Google Play Console** — developer account, store listing, Data Safety
   declaration (AdMob), privacy policy URL.

## Pushing to GitHub

```
git init
git add .
git commit -m "Initial commit: Number Master runner"
git branch -M main
git remote add origin <YOUR_REPO_URL>
git push -u origin main
```
