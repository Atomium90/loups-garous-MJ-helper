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

The Flutter app (`lib/`) covers the full game-setup flow (Accueil → Composition → Les joueurs →
Avant la nuit 1):

- `lib/data/`: Drift schema (`Games` + `Players` tables) and `GameRepository`
- `lib/state/`: Riverpod providers, including draft-then-commit editing of both the composition
  and the player roster
- `lib/ui/`: design-token system (`theme/`, mapped from the design handoff's colour/typography/
  spacing tables), a small reusable component layer (`widgets/`), `go_router` navigation
  (`router/`), and the screens (`screens/`)

## Architecture

```
lib/
  data/                  Drift schema + repositories
  state/                 Riverpod providers/controllers
  ui/
    theme/                design tokens (colors, typography, spacing/radii/sizes, icons)
    widgets/               reusable components (buttons, chips, steppers, cards...)
    router/                 go_router navigation
    screens/                 one folder per screen
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
