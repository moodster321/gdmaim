# Fork decisions: why this GDMaim behaves differently

This fork exists so that SEVER // ctrl, a large Godot 4.7.1 game, can ship obfuscated exports
that behave exactly like plain ones. The `gdmaim-p0` workstream (PRs #1–#4) made the changes;
this page keeps the reasons. The changed defaults themselves are listed in the README under
*About this fork*.

## Decisions (made with the maintainer)

- **Fork-only, with safe defaults.** The defaults are whatever the game needs: class names kept,
  string-referenced names kept, exported variables not renamed, shuffle off. The changes are not
  shaped for upstream, and the fork may drift from upstream behaviour.
- **Auto-lock every matching literal, not just name-taking calls.** Any declared name that
  appears in a string literal (`.gd`), as a word in a `.dialogue` file, or inside a quoted string
  in `.json`/`.tscn`/`.tres`/`.cfg` keeps its real name.
  - We rejected narrowing this to literals passed to `call`, `has_method`, `Callable`, `get`,
    `set`, `connect` or `rpc`. That version would miss wrappers, such as an event bus's
    `listen(…, "method")` or a router's `_dispatch(shell, &"method")`, unless each wrapper were
    listed by hand.
  - Over-locking only leaves a name in plain text. Under-locking breaks the game.
- **Class names are never renamed.** The game identifies classes by `get_global_name()` against
  string literals. PCK encryption already hides class names from decompilers, so obfuscating them
  buys little and breaks the game.
- **Exported variables are not renamed.** Saves, Workshop content and campaign progress are keyed
  by exported names, and existing players' saves were written by builds without obfuscation.
- **`@export` is never stripped.** Godot copies and saves only storage-flagged properties, so a
  stripped `@export` silently empties `duplicate()` and `ResourceSaver` output.
- **Top-level shuffle is off.** Member initializers run in declaration order, so reordering them
  changes values.
- **Proof is an end-to-end export test, run in CI.** Every guarantee is a check in
  `tests/e2e/fixture/`, exported for real twice (obfuscated and plain) and run headless on
  GitHub-hosted Ubuntu for every PR. Exporting SEVER itself with the fork is separate,
  follow-up work.

## Measured on upstream `cdb18dc` (Godot 4.7.1, 2026-10-21)

What the unmodified addon did, compared with the same project exported with `no_gdmaim`:

| Behaviour | Obfuscated | Plain |
|---|---|---|
| `get_script().get_global_name()` | `__xJN6…` | `SpikeItem` |
| `has_method(&"spike_greet")` | false | true |
| typed `.duplicate()` of a `.tres` with 7/"abc" | 0/"" | 7/"abc" |
| `ResourceSaver.save`, then load | 0/"" | 7/"abc" |
| `importer="keep"` CSV in the PCK | missing | present |
| CSV translation (`*.translation`) | present | present |

These hold either way: a text `.tres` whose `script_class=` header names the wrong class still
loads and binds by script path, and `ResourceLoader.load(path, "<wrong hint>")` still loads. So
old saves don't depend on class names.
