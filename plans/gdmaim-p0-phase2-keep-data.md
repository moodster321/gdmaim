# GDMaim P0 Phase 2 — keep data: @export kept, keep-CSVs shipped, safe defaults

Part of the GDMaim P0 workstream. Read `plans/gdmaim-p0-overview.md` first for the user decisions
and the verified Godot facts. Branch: `claude/gdmaim-p0-phase2-keep-data`, cut from
`claude/gdmaim-p0-phase1-e2e-harness`; open the PR with base
`claude/gdmaim-p0-phase1-e2e-harness` on `moodster321/gdmaim`. Predecessor:
`plans/gdmaim-p0-phase1-e2e-harness.md`. Successor: `plans/gdmaim-p0-phase3-keep-class-names.md`.
visual: no

## Context

Phase 1 put five checks in `tests/e2e/xfail.txt` under `# phase 2`. This phase makes them pass:

- **`export_duplicate`, `export_save_roundtrip`.**
  - Cause: `strip_editor_annotations` (default true, `settings.gd:27`) deletes every `@export*`
    annotation, including `@export_storage` (`obfuscator/script/script_obfuscator.gd:417`, the
    condition `token.get_value().contains("@export") or … in Builtins.ANNOTATIONS`).
  - Effect: the field loses its storage flag, so `duplicate()` and `ResourceSaver` drop it.
    The overview's facts show this measured as 0/"".
- **`legacy_save_load`.**
  - Cause: `obfuscate_export_vars` defaults to true (`settings.gd:17`), so exported names are
    renamed.
  - Effect: a save written by a build without obfuscation no longer matches.
  - Where the name is kept: `@export` and `@export_storage` both go through
    `create_export_symbol` (`parser.gd:157-170, 637, 667`), which keeps the name when the setting
    is false (`symbol_table.gd:54-55`).
- **`keep_csv_exported`.**
  - Cause: `_export_file` calls `skip()` on every `.csv` (`export_plugin.gd:364-365`, marked
    `#HACK`).
  - Effect: a CSV with `importer="keep"` (read raw at runtime) disappears from the PCK.
  - Not affected: translation CSVs. Their `.translation` output still ships (overview facts).
- **`init_order`.**
  - Cause: `shuffle_top_level` defaults to true (`settings.gd:14`). `_shuffle_toplevel`
    (`script_obfuscator.gd:281-375`) reorders member declarations, deterministically from path,
    seed and line content.
  - Effect: a member whose initializer reads an earlier member gets that member's default.

## Design

### 1. Never strip `@export` annotations

At `script_obfuscator.gd:417`, drop the `token.get_value().contains("@export") or` part. The
branch then only strips `Builtins.ANNOTATIONS` (`@icon`, `@tool`, `@warning_ignore*`; `@abstract`
is already kept by the `DECORATORS` check just above).

`@export_category` / `@export_group` / `@export_subgroup` are still removed by the `ATTRIBUTES`
branch (`:411-413`). They are editor-only and carry no storage, so that stays. Every other
`@export*` annotation, with its parentheses, survives unchanged.

Update the `strip_editor_annotations` tooltip in `settings.gd` to say `@export` annotations are
always kept, because removing them drops the fields from `duplicate()` and `ResourceSaver`.

### 2. Defaults

In `settings.gd`, set `shuffle_top_level : bool = false` (`:14`) and
`obfuscate_export_vars : bool = false` (`:17`). Each `add_entry` tooltip (`:95`, `:97`) gets one
sentence: "Fork default: off, because …" (saves and other data keyed by exported names; member
initializers that depend on declaration order).

### 3. Ship `importer="keep"` CSVs

At `export_plugin.gd:364-365`, read `path + ".import"` when it exists. If it contains
`importer="keep"`, `return` without calling `skip()`, so Godot exports the file itself (the plain
build proves this ships it). Every other `.csv` keeps today's `skip()`. Don't touch the `.ico`
branch.

### 4. xfail

Delete the five ids and the `# phase 2` header from `tests/e2e/xfail.txt`.

### 5. README

Under `### Changed defaults`, add one line each:

- `shuffle_top_level` is off.
- `obfuscate_export_vars` is off.
- `@export` annotations are never stripped.
- `importer="keep"` CSVs are exported.

## Files to touch

- Edit:
  - `addons/gdmaim/obfuscator/script/script_obfuscator.gd` (§1)
  - `addons/gdmaim/settings.gd` (§1 tooltip, §2)
  - `addons/gdmaim/export_plugin.gd` (§3)
  - `tests/e2e/xfail.txt`
  - `README.md`

## Tests to add

None new: phase 1's five checks are the tests. If one still fails for a reason this brief didn't
predict, fix the addon, not the check. Change a check only if it is provably wrong in the plain
build too, and explain that in the PR.

## Verification

1. **The suite passes.** Run `python tests/run_e2e.py`: exit 0, with 8 passed, 10 xfail, 0 failed
   (obfuscated), plus 18/18 plain.
2. **Obfuscation still happens.** `obfuscation_active` is among the passes.
3. **The fixes are what flipped the checks.** With `--keep`, run
   `grep -ac "@export_storage var e2e_secret" <tmp>/out/obfuscated.pck`, which prints ≥ 1; text
   scripts sit unencrypted in the fixture's PCK. Do the same for `@export var e2e_power`. Paste
   both counts. Don't grep the PCK for `keep.csv`: the path string shows up even when the file
   was dropped, so `keep_csv_exported` passing is the evidence.
4. **Scope.** `git diff --stat claude/gdmaim-p0-phase1-e2e-harness` touches only the five files
   above.
5. **CI.** The `e2e` job is green on the PR.

## Risks / open questions

- **Existing configs.** A project with an existing `res://.gdmaim/export.cfg` keeps its stored
  values (`settings.gd:186-188`), so the default flip only reaches fresh configs. That's
  intended; mention it in the README line.
- **`init_order` still fails.** If it fails with shuffle off, something else reorders members.
  Look at `script_obfuscator.gd:62-63` and the `@onready` handling before changing the fixture.
- **CSV import file.** `importer="keep"` may be written with spacing or quoting variants. Match
  on the parsed value: `ConfigFile.load(path + ".import")`, then
  `get_value("remap", "importer", "") == "keep"`.
