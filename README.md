# Loup Garou MJ

[![Tests](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/tests.yml/badge.svg)](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/tests.yml)
[![Release](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/release.yml/badge.svg)](https://github.com/Atomium90/loups-garous-MJ-helper/actions/workflows/release.yml)

A companion app for the Game Master (MJ) of **Les Loups-Garous de Thiercelieux** (the French
werewolf/mafia party game). The physical board game stays central: players and the MJ play face
to face, the app only helps compose a game, run the night script in the right order, and keep a
reliable record of the village's state. When in doubt between automating something and leaving it
to the MJ, the app leaves it to the MJ. Fully offline during a game, single device (the MJ's
phone).

## Current status

Playable end to end: a game runs from setup through repeated nights and days to a declared winner
and its recap, and resumes exactly where it left off after a force-quit. The app speaks French and
English.

**Roles.** 29 roles are fully assisted: the eight of the base game (Loup-Garou, Villageois,
Voyante, Sorcière, Chasseur, Cupidon, Petite Fille, Voleur) and those of the New Moon, Characters,
Pact and Best Of boxes (Salvateur, Ancien, Bouc Émissaire, Joueur de Flûte, Idiot du Village, Ange,
Juge Bègue, Chevalier, Comédien, Servante Dévouée, Renard, Montreur d'Ours, Abominable Sectaire,
Enfant Sauvage, Chien-Loup, Loup-Garou Blanc, Infect Père des Loups, Grand Méchant Loup, Deux Sœurs,
Trois Frères, Villageois-Villageois). The roles that need buildings or event cards (Pyromane,
Corbeau, Gitane, Garde Champêtre) and the 25th-anniversary edition are not built yet.

**A game, step by step**

1. *Accueil*: start a game, resume the running one, pick up a draft, or reopen a finished game's
   recap. A game whose save can no longer be read is flagged and can be deleted.
2. *Composition*: the number of players and the roles to deal, bounded by the boxes the MJ owns
   (Réglages > Mes boîtes). A suggestion for the player count is one tap away. With the Voleur, the
   two reserve cards are either the two left after the deal (the booklet's rule, noted on night 1)
   or chosen here (a setting).
3. *Les joueurs*: the names, and optionally each player's role noted at the deal, so the app knows
   who holds what before the first night and asks less during the game.
4. *The game*: a three-tab shell, Script / Village / Journal. The Script walks the MJ through each
   night in the order of the booklets: who to wake, what to ask, what to say out loud (as much as
   Réglages says), then the morning, the vote, the election of the Capitaine and the chain effects of
   a death (lovers, the Hunter's shot, the Capitaine's successor). What the app cannot know, the MJ
   tells it, and a card is noted as it is revealed.
5. *End of the game*: the winner, a recap, and the journal, which can be shared as text.

**Réglages** has five sections: content (Mes boîtes), the rules where the booklets disagree or
the tables differ (a tied vote, the Thief's reserve, the Fox's place in the night, the White
Werewolf's nights, the Knight's disease), during the game (the lines the MJ reads aloud, the
aide-mémoire, dead players' cards shown or kept hidden, role notes at the deal, screen kept awake),
display (theme, language) and data (crash reports, delete all games).

Everything stays on the phone: no account, no network during a game. Crash reports are strictly
opt-in: a build only knows where to send them when it is given the DSN of a Sentry project
(`flutter build apk --dart-define=SENTRY_DSN=...`; the release workflow reads it from the optional
`SENTRY_DSN` repository secret). Without a DSN the app never reports anything and the setting is not
shown; with one, the setting is off until the MJ turns it on, and nothing about the games (names,
roles, journal) is attached to a report.

Not built yet: the regulars address book, the hidden-composition mode, import/export of a save file,
the roles listed above, and a real accessibility pass (large text, screen reader, tablets).

## The rules engine

`packages/rules_engine` is pure Dart with no Flutter dependency, so the rules are tested on their own
(`dart test`):

- `RoleRegistry`: the catalogue of roles, with their official night-call order and the metadata the
  rest derives from (wake condition, team, group size, suggestion tier). Adding a role means a line
  there, its actions in the state machine, and its texts in each language in the app.
- `NightScriptBuilder`: computes the exact order of roles to call on a given night, from the
  composition, who is still alive, which powers are spent and the settings that move a role.
- `GameStateMachine`: resolves every role action from explicit MJ-reported facts: the night, the
  day vote and the Capitaine election, `StartNextNight`, and the death cascade. `RevealRole` records a
  card the app never learned and replays that player's on-death effect. Each `Player` carries how and
  when they died.
- `GameStateJson`: encodes and decodes a `GameState` to plain maps, a paused death cascade included,
  for the app's snapshots.
- `CardPool` and `gameBoxes`: what the owned boxes can deal (cards and stickers).
- `CompositionAdvisor`: suggests a composition for a player count from role metadata alone, with no
  per-count table to maintain as roles are added.

## The app

The Flutter app (`lib/`) is the MJ's side of it:

- `lib/data/`: Drift schema (`Games`, `Players`, `NightLog`) and `GameRepository`. A running game's
  live state is a JSON snapshot of the engine's `GameState` on the `Games` row, rewritten after every
  action, so a force-quit resumes on the exact step, mid death-cascade included. A finished game
  keeps its winner and its snapshot for the recap.
- `lib/state/`: Riverpod providers. `GameSession` is the orchestrator: it loads or seeds a game's
  `GameState`, applies MJ-reported facts through the pure `GameStateMachine`, tracks the day stage,
  and persists. Plus draft-then-commit editing of the composition and the roster, `settings/`
  (persisted with `shared_preferences`) and the opt-in crash reporting.
- `lib/ui/`: a design-token system (`theme/`), a reusable component layer (`widgets/`), `go_router`
  navigation (`router/`), and the screens (`screens/`). The in-game header's home button leaves the
  game running and returns to Accueil.

## Architecture

```
lib/
  l10n/                  French and English messages (.arb) and the delegates the app uses
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
(navigation), intl and ARB files (texts), shared_preferences (settings), share_plus (sharing the
journal), wakelock_plus (screen kept awake), sentry_flutter (opt-in crash reports), tabler_icons_plus
(icons).

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

### Languages and texts

Every text the user reads lives in `lib/l10n/app_fr.arb` (the template, with a description per
message) and `lib/l10n/app_en.arb`. `flutter pub get` generates the typed `AppLocalizations`
class from them into `lib/l10n/generated/` (not committed); screens read it with
`context.l10n.someMessage`.

- **A new text**: add the message to `app_fr.arb` with its `@message` description (and its
  placeholders), add the translation to `app_en.arb`, then use it. `flutter test` checks that
  both files have the same messages and the same placeholders.
- **Counts and genders** are ICU `plural` / `select` messages in the file, never string
  concatenation in Dart. French treats 0 as singular, so a message that can show zero spells out
  `=0`.
- **A role** has no text in the rules engine, which is language-free: its name, plural, article,
  rule text and game master tip are `select` messages keyed by the role id (`roleName`,
  `rolePlural`, `roleWithArticle`, `roleRuleText`, `roleMjTips`). Adding a role means adding a
  line to each; a test fails if a role of the registry lacks one in either language.
- **The lines the MJ reads aloud** are `narr...` messages: a head (the essential) and a body
  (the rest) per moment, and a call, a task and a closing line per role as `select` messages
  keyed by the role id, so a new role adds a line to each. `lib/ui/utils/narration.dart`
  assembles them; the `NarrationBlock` widget shows them at the level chosen in Réglages.
- **The journal** stores what happened (a kind, player names, a role id), not a sentence, and
  is turned into text when displayed. Journal lines saved before this existed stay in French.
- **A new language** is a new `app_xx.arb`, the language in `AppLanguage`, and its name in
  Réglages.

### CI

Two GitHub Actions workflows, `.github/workflows/`:

- **`tests.yml`** — on every push/PR to `main`: `flutter analyze`, `flutter test`, and
  `dart test` for `packages/rules_engine`. Both regenerate the Drift/Riverpod/freezed code
  first (`build_runner`), same as the local `dart run build_runner build` step above — it isn't
  committed to git. It also writes LCOV coverage reports for the app and the engine and runs a
  SonarCloud analysis on them (`sonar-project.properties`). The analysis stores no secret: it
  authenticates through GitHub OIDC, which needs the repository bound to a SonarCloud project
  with secretless analysis enabled in the organization settings.
- **`release.yml`** — on a pushed `vX.Y.Z` tag (or manual dispatch with an existing tag, from
  the Actions tab): checks that the tag matches the `version:` in `pubspec.yaml`, builds a
  release APK and attaches it, with a SHA-256 checksum, to a **draft** GitHub Release marked
  pre-release. Release notes are written by hand before publishing, and a published release is
  never overwritten. The APK is signed with Flutter's default debug key for now (see the
  `TODO` in `android/app/build.gradle.kts`) — installable for testing, not a store release.

Only real releases get a tag. A version bump in `pubspec.yaml` alone does not publish anything:

```bash
git tag v0.2.0     # must match `version: 0.2.0+N` in pubspec.yaml
git push origin v0.2.0
```

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
