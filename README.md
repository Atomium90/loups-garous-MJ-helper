# Loup Garou MJ

[![Tests](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/tests.yml/badge.svg)](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/tests.yml)
[![Build APK](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/build-apk.yml/badge.svg)](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/build-apk.yml)

A companion app for the Game Master (MJ) of **Les Loups-Garous de Thiercelieux** (the French
werewolf/mafia party game). The physical board game stays central: players and the MJ play face
to face, the app only helps compose a game, run the night script in the right order, and keep a
reliable record of the village's state. When in doubt between automating something and leaving it
to the MJ, the app leaves it to the MJ. Fully offline during a game, single device (the MJ's
phone).

## Current status

Early development. The full day/night loop is in — a game runs from setup through repeated
cycles to a declared winner and its recap, resuming exactly where it left off after a
force-quit. All 8 base-game roles are now fully assisted, the Seer and the Voleur included:
the Seer picks a player and the MJ notes the card if it isn't on record yet; the Voleur's two
reserve cards are chosen at composition time (spelled out before night 1) and offered as his
swap, with the stolen role folded into that night's script and the following ones. The
composition screen also suggests a full composition for the chosen player count, one tap to
apply it.

The rules engine (pure Dart, `packages/rules_engine`) is complete for the base game:

- `RoleRegistry`: catalog of the 8 base-game dealt roles, with their official night-call order
  (Capitaine is an elected status, not a dealt role, so it's not in this catalog)
- `NightScriptBuilder`: computes the exact order of roles to call on a given night, from the
  active composition and who's still alive
- `GameStateMachine`: resolves every role action from explicit MJ-reported facts — the night,
  the day vote and captain election, `StartNextNight`, and the death cascade (lovers, the
  Hunter's shot, captain succession). `RevealRole` records a card the app never learned (a
  player who dies un-identified) and replays that player's on-death effect. Each `Player`
  carries how and when they died.
- `GameStateJson`: encode/decode a `GameState` to plain maps — including a paused death
  cascade — for the app's snapshot persistence
- `CompositionAdvisor`: suggests a full composition for a player count from role metadata
  alone (a small wolf-count band table, plus each role's declared "suggestion tier") — no
  per-player-count table to hand-maintain as roles are added

The Flutter app (`lib/`) drives the loop: Accueil → Composition → Les joueurs → Avant la
nuit 1 → the in-game Script / Village / Journal shell. The MJ identifies each role as it wakes,
runs Cupidon / the Seer / the Wolves / the Witch, resolves the night, then works through the
day — the recap (with any card to reveal and any chain effect), the captain election, the
village vote — and on into the next night, until they end the game and declare a winner. A
finished game can be reopened from Accueil for its recap.

- `lib/data/`: Drift schema (`Games`, `Players`, `NightLog`) and `GameRepository`. A running
  game's live state is a JSON snapshot of the engine's `GameState` on the `Games` row, rewritten
  after every action, so a force-quit resumes on the exact step — mid death-cascade included.
  A finished game keeps its `winner` and its snapshot for the recap.
- `lib/state/`: Riverpod providers. `GameSession` is the orchestrator — it loads or seeds a
  game's `GameState`, applies MJ-reported facts through the pure `GameStateMachine`, tracks the
  day stage, and persists. Plus draft-then-commit editing of the composition and the roster, and
  `settings/` — the theme override and two in-game toggles, persisted with `shared_preferences`.
- `lib/ui/`: design-token system (`theme/`, mapped from the design handoff's colour/typography/
  spacing tables), a reusable component layer (`widgets/`), `go_router` navigation (`router/`),
  and the screens (`screens/`).

Réglages (theme, keep-screen-awake, aide-mémoire visibility) is reachable from the Accueil gear
and from a persistent 46px header inside a game; that header's home button leaves the game
running and returns to Accueil. Mes boîtes is informational for now — the base box, extensions
listed as coming soon.

Also not built: the regulars address book and the extension boxes.

## Architecture

```
lib/
  data/                  Drift schema + repositories
  state/
    session/               GameSession orchestrator, night cursor + day snapshot, journal-line rendering
    ...                    other Riverpod providers/controllers
  ui/
    theme/                design tokens (colors, typography, spacing/radii/sizes, icons)
    widgets/               reusable components (buttons, chips, avatars, grids...)
    router/                 go_router navigation
    screens/                 one folder per screen (in_game/ holds the tab shell, the Script, the day panels)
packages/rules_engine/   rules engine, pure Dart, zero Flutter dependency
```

The rules engine is deliberately isolated in its own package so it stays testable independently
of the UI (`dart test`, no Flutter test harness).

The in-game shell is a 3-tab `IndexedStack` (Script / Village / Journal), not routed. The day
side of the Script tab is state-driven: a `dayInterrupt` (a card to reveal, a chain effect, a
lover's grief) takes over the body when set, otherwise the current day stage shows. Those
panels are ordinary tab bodies, not modal sheets — the only true modals are the past-game
recap and the aide-mémoire.

Stack: Riverpod (state), Drift (typed SQLite), freezed (immutable models), go_router
(navigation), tabler_icons_plus (icons). json_serializable isn't wired in yet.

## Development

```bash
# Flutter app
flutter pub get
dart run build_runner build   # generates Drift/Riverpod/freezed code, not committed to git
flutter test

# Rules engine (standalone pure-Dart package)
cd packages/rules_engine
dart pub get
dart test
```

### CI

Two GitHub Actions workflows, `.github/workflows/`:

- **`tests.yml`** — on every push/PR to `main`: `flutter analyze`, `flutter test`, and
  `dart test` for `packages/rules_engine`. Both regenerate the Drift/Riverpod/freezed code
  first (`build_runner`), same as the local `dart run build_runner build` step above — it isn't
  committed to git.
- **`build-apk.yml`** — on push to `main` and on manual dispatch (the Actions tab): builds a
  release APK and publishes it as a GitHub Release tagged `build-N`, ready to download and
  sideload on a phone. Signed with Flutter's default debug key for now (see the `TODO` in
  `android/app/build.gradle.kts`) — installable for testing, not a store release.

### App icon & splash

`assets/icon/` and `assets/splash/` hold placeholder art. To use real art, replace the PNGs
(same names, same sizes — see the comments in `pubspec.yaml`), then regenerate the per-platform
files:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

- `assets/icon/app_icon.png` — 1024×1024, opaque (iOS + Android fallback)
- `assets/icon/app_icon_foreground.png` — 1024×1024, transparent, mark inside the centre ~66%
  (Android adaptive foreground; the background is the `#1D4ED8` colour in the config)
- `assets/splash/splash_logo.png` — centred logo, transparent

The generated files under `android/` and `ios/` are committed.
