# Loup Garou MJ

A companion app for the Game Master (MJ) of **Les Loups-Garous de Thiercelieux** (the French
werewolf/mafia party game). The physical board game stays central: players and the MJ play face
to face, the app only helps compose a game, run the night script in the right order, and keep a
reliable record of the village's state. When in doubt between automating something and leaving it
to the MJ, the app leaves it to the MJ. Fully offline during a game, single device (the MJ's
phone).

## Current status

Very early development. The rules engine (pure Dart, `packages/rules_engine`) currently has:

- `RoleRegistry`: catalog of the 9 base-game roles, with their official night-call order
- `NightScriptBuilder`: computes the exact order of roles to call on a given night, from the
  active composition and who's still alive

Nothing on the UI or persistence side yet.

## Architecture

```
lib/                    Flutter app (UI, state, data layer) — not started yet
packages/rules_engine/  rules engine, pure Dart, zero Flutter dependency
```

The rules engine is deliberately isolated in its own package so it stays testable independently
of the UI (`dart test`, no Flutter test harness).

Planned stack for the rest of the app: Riverpod (state), go_router (navigation), Drift (typed
SQLite), freezed / json_serializable (models).

## Development

```bash
# Flutter app
flutter pub get
flutter test

# Rules engine (standalone pure-Dart package)
cd packages/rules_engine
dart pub get
dart test
```
