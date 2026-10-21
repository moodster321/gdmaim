# GDMaim P0 Phase 3 — keep class names

Part of the GDMaim P0 workstream. Read `plans/gdmaim-p0-overview.md` first for the user decisions
and the verified Godot facts. Branch: `claude/gdmaim-p0-phase3-keep-class-names`, cut from
`claude/gdmaim-p0-phase2-keep-data`; open the PR with base `claude/gdmaim-p0-phase2-keep-data` on
`moodster321/gdmaim`. Predecessor: `plans/gdmaim-p0-phase2-keep-data.md`. Successor:
`plans/gdmaim-p0-phase4-string-auto-lock.md`. visual: no

## Context

GDMaim renames every `class_name`. `_parse_class_name` (`parser.gd:435-451`) creates a global
symbol, which is locked only when the line carries the `##LOCK_SYMBOLS` hint. `_export_begin`
then rewrites the class cache with the new names (`export_plugin.gd:216-231`), so in the exported
game `get_script().get_global_name()` returns `__xJN6…` (overview facts).

SEVER identifies classes by that string. `Utils.scriptExtendsClass` (SEVER `scripts/utils.gd:805`)
compares `get_global_name()` against literals like `&"TargetComponent"` in 28 template-validator
calls, so every template would fail to load. Encryption already hides class names from
decompilers, so obfuscating them buys nothing.

Phase 1 put two checks under `# phase 3` in `tests/e2e/xfail.txt`: `class_identity` and
`script_extends_class`.

`_class_symbols` (`export_plugin.gd:27`) is filled per script at `:518-519` and is never cleared,
so a second export in the same editor session still sees the first export's entries.

## Design

### 1. Setting

In `settings.gd`, add `var lock_class_names : bool = true` next to `obfuscate_export_vars`.
Register it with `add_entry("lock_class_names", "lock_class_names", "Keep Class Names", "If true,
class_name declarations keep their names, so get_global_name(), script_class headers and
string-based class checks still match. Fork default: on.")` directly after the
`obfuscate_export_vars` entry in the `obfuscator` category (`settings.gd:95`).

### 2. Lock

In `export_plugin.gd` `_export_begin`:

1. Add `_class_symbols.clear()` beside `_autoloads.clear()` (`:96-98`).
2. After the parse loop (`:163-165`) and before `_symbols.resolve_symbol_paths()` (`:188`), add:

```gdscript
if settings.lock_class_names:
	for class_name_ : String in _class_symbols:
		_symbols.lock_symbol_name(class_name_)
```

`lock_symbol_name` keeps the name in `obfuscate_symbols` (`symbol_table.gd:142-150`). The class
cache rewrite at `:221-226` then writes each class's own name back, so it changes nothing. The
`script_class=` header rewrite in `resource_obfuscator.gd:62-72` finds a symbol whose name is
unchanged. Leave both as they are.

Inner classes (`class Foo:`) are **not** covered: they're renamed unless phase 4 finds them
referenced by a string.

`class_name` is a reserved word, so the loop variable can't be called that; `class_name_` is fine.

### 3. xfail

Delete `class_identity`, `script_extends_class` and the `# phase 3` header from
`tests/e2e/xfail.txt`.

### 4. README

Under `### Changed defaults`, add: "`lock_class_names` (new, on): class names are never renamed".

## Files to touch

- Edit: `addons/gdmaim/settings.gd`, `addons/gdmaim/export_plugin.gd`, `tests/e2e/xfail.txt`,
  `README.md`.

## Tests to add

None new; phase 1's two checks cover it. Optionally add the check `class_cache_consistent`: in
both builds, `ProjectSettings.get_global_class_list()` contains an entry whose `class` is
`&"E2EItem"`. If you add it, it must pass in both builds with no xfail line, and the counts in
Verification grow by one.

## Verification

1. **The suite passes.** Run `python tests/run_e2e.py`: exit 0, with 10 passed, 8 xfail, 0 failed
   (obfuscated), plus 18/18 plain (or 11/19 with the optional check).
2. **The setting is the cause.** Flip the new default to `false` locally and re-run:
   `class_identity` and `script_extends_class` are reported as failing. Paste that output, then
   restore the default (`git diff` shows only your intended change).
3. **Obfuscation still happens.** `obfuscation_active` is among the passes.
4. **Scope.** `git diff --stat claude/gdmaim-p0-phase2-keep-data` touches only the four files
   above, plus the fixture if you added the optional check.
5. **CI.** The `e2e` job is green on the PR.

## Risks / open questions

- **Embedded scripts.** A `class_name` inside a script embedded in a `.tscn` is parsed through
  the embedded path (`export_plugin.gd:462-504`), which never fills `_class_symbols`. That's out
  of scope (SEVER has none); note it under Follow-ups if you confirm it.
