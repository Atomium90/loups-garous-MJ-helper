# rules_engine

The rules of *Les Loups-Garous de Thiercelieux*, as pure Dart with no Flutter dependency. The
Loup Garou MJ app (the parent project) drives it; it is tested on its own, with no widget harness.

The engine is language-free: it knows role ids, never role names or sentences. The app owns every
text.

## What it holds

- **`RoleRegistry`** (`role_registry/`): the catalogue of roles in the official night-call order,
  each with its team, group size, wake condition and suggestion tier.
- **`NightScriptBuilder`** (`night_script/`): the order of roles to wake on a given night, from the
  composition, who is alive, the powers already spent and the settings that move a role.
- **`GameStateMachine`** (`game_state/`): applies one `GameAction` (what the MJ reports) to a
  `GameState` and returns the new state with the events it caused. It never decides for the MJ: it
  checks that the action is allowed and resolves the consequences (deaths, lovers, the Hunter's
  shot, the Capitaine's succession).
- **`GameStateJson`** (`serialization/`): turns a `GameState` into plain maps and back, for the
  app's snapshots. A save written by an older version still decodes.
- **`CardPool`, `gameBoxes`** (`boxes/`): which roles and how many copies the boxes the MJ owns can
  deal, with the cards and the stickers told apart.
- **`CompositionAdvisor`** (`composition_advisor/`): suggests a composition for a player count from
  role metadata only.

## Adding a role

1. Add it to the registry (`role_registry/data/role_data.dart`) at its place in the night order.
2. If it acts, add its `GameAction` and resolve it in the state machine.
3. Add it to the boxes that hold it (`boxes/game_boxes.dart`).
4. Test the rule in `test/`. The app adds its name and texts in each language.

## Tests

```bash
dart pub get
dart test
```
