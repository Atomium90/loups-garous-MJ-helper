# Loup Garou MJ

A companion app for the Game Master (MJ) of **Les Loups-Garous de Thiercelieux** (the French
werewolf/mafia party game). The physical board game stays central: players and the MJ play face
to face, the app only helps compose a game, run the night script in the right order, and keep a
reliable record of the village's state. When in doubt between automating something and leaving it
to the MJ, the app leaves it to the MJ. Fully offline during a game, single device (the MJ's
phone).

## Current status

Early development. The rules engine (pure Dart, `packages/rules_engine`) is complete for the base
game:

- `RoleRegistry`: catalog of the 8 base-game dealt roles, with their official night-call order
  (Capitaine is an elected status, not a dealt role, so it's not in this catalog)
- `NightScriptBuilder`: computes the exact order of roles to call on a given night, from the
  active composition and who's still alive
- `GameStateMachine`: resolves every role action from explicit MJ-reported facts, including death
  cascades (lovers, the Hunter's shot, Captain succession)
- `GameStateJson`: encode/decode a `GameState` to plain maps, for the app's snapshot persistence

The Flutter app (`lib/`) runs the game from setup through the first night: Accueil → Composition
→ Les joueurs → Avant la nuit 1 → the in-game Script/Village/Journal shell, where the MJ
identifies each role as it wakes, runs the Seer / Wolves / Witch, resolves the night, and lands
on the day-1 recap.

- `lib/data/`: Drift schema (`Games`, `Players`, `NightLog`) and `GameRepository`. A running
  game's live state is a JSON snapshot of the engine's `GameState` on the `Games` row, rewritten
  after every action, so a force-quit resumes on the exact step.
- `lib/state/`: Riverpod providers. `GameSession` is the orchestrator — it loads or seeds a
  game's `GameState`, applies MJ-reported facts through the pure `GameStateMachine`, and
  persists. Plus draft-then-commit editing of the composition and the roster.
- `lib/ui/`: design-token system (`theme/`, mapped from the design handoff's colour/typography/
  spacing tables), a reusable component layer (`widgets/`), `go_router` navigation (`router/`),
  and the screens (`screens/`).

Not built yet: the Cupidon / Voleur / Seer actions (their identification steps work, the action
is a "pass"), the day loop (captain, vote), death-chain resolution, and the full Village view.

## Architecture

```
lib/
  data/                  Drift schema + repositories
  state/
    session/               GameSession orchestrator, cursor, journal-line rendering
    ...                    other Riverpod providers/controllers
  ui/
    theme/                design tokens (colors, typography, spacing/radii/sizes, icons)
    widgets/               reusable components (buttons, chips, avatars, grids...)
    router/                 go_router navigation
    screens/                 one folder per screen (in_game/ holds the tab shell + Script)
packages/rules_engine/   rules engine, pure Dart, zero Flutter dependency
```

The rules engine is deliberately isolated in its own package so it stays testable independently
of the UI (`dart test`, no Flutter test harness).

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
