# Agent guide: GDMaim, moodster321 fork

A fork of [cherriesandmochi/gdmaim](https://github.com/cherriesandmochi/gdmaim), the GDScript
obfuscator. GDMaim runs as an `EditorExportPlugin` during a Godot export. This fork is maintained
for SEVER // ctrl, a large Godot 4.7.1 game. It deliberately changes upstream defaults to what is
safe for that game and is **not** kept upstreamable. The addon code lives in `addons/gdmaim/`.

## Rules

- **PRs go to `moodster321/gdmaim`, never upstream.** Pass `--repo moodster321/gdmaim` to every
  `gh pr …` call. In a fork, `gh` otherwise targets the parent repo.
- **Godot:** `$GODOT_BIN`, else `$GODOT_PATH` (stock 4.7.1). Always pass `--headless`. Launch
  Godot from the Bash tool, never PowerShell (a user-level hook runs it on a hidden desktop). On
  Windows, use the `…_console.exe` sibling when you need its stdout.
- **Never export the repo root.** An export writes into the project (`.gdmaim/`,
  `addons/gdmaim/export.cfg`, `source_maps/`, `backup/`). Export a temp copy, as the test runner
  does.
- **`.gitignore` hides project files.** It ignores `project.godot`, `export_presets.cfg`,
  `*.import`, `*.txt`, `*.uid` and `export.cfg` everywhere. Fixture files under `tests/` are
  re-included by `!` rules. Check that `git status` lists a new fixture file before you commit.
- **Match the addon's style:** tabs, `var x : Type` spacing, and static types where the
  surrounding code has them.
- **Comments carry no PR numbers.** Prefer the fix that makes a bad case impossible over a guard
  around the symptom.
- **Why the defaults differ from upstream:** `docs/fork-decisions.md`. Deferred work:
  `plans/followup-index.md`.

## Export pipeline invariants

- **Where locks go.** `_export_begin` (`export_plugin.gd`) runs in this order: it locks the
  builtins, the custom tokens and every ClassDB name; parses every `.gd`/`.tscn`/`.scn`; applies
  `lock_class_names`, then `lock_string_referenced_symbols`; then calls `resolve_symbol_paths()`
  and `obfuscate_symbols()`. **A new lock must run after the parse loop and before
  `resolve_symbol_paths()`.**
- **Names, not symbols.** Class-body names are global and keyed by name alone
  (`symbol_table.gd`). `lock_symbol_name` keeps a name for every global *and* local that shares
  it.
- **String tokens.** Strings tokenize as `STRING_LITERAL`/`STRING_MULTI_LINE` without their
  quotes, and `&"x"` is the operator `&` followed by the literal. To walk a parsed script's
  tokens: `tokenizer.reset()`, then `get_next()` until null, then `reset()` again (as
  `check_exclusion_source` does).
- **Settings.** Defaults are the var initializers in `settings.gd`, each registered with
  `add_entry`. A stored `res://.gdmaim/export.cfg` overrides them, which is why the fixture must
  never carry one (`.gitignore` blocks `tests/**/.gdmaim/`).
- **Export and run facts the tests rely on:**
  - `--export-pack` needs no export templates.
  - `godot --headless --main-pack x.pck` runs a PCK with the editor binary.
  - A preset with `custom_features="no_gdmaim"` exports with GDMaim off.
  - A text `.tres` with a wrong `script_class=` header still loads, binding by script path.

## Tests

```bash
python tests/run_e2e.py                  # the gate: exit 0 or it isn't done
E2E_VERBOSE=1 python tests/run_e2e.py    # stream every Godot log
python tests/run_e2e.py --only <id>      # judge one check (still exports and runs everything)
python tests/run_e2e.py --keep           # keep the temp project and PCKs, print the path
```

The runner copies `tests/e2e/fixture/` and the addon to a temp dir, then:

1. Imports it once, then exports it twice, as `Obfuscated` and as `Plain` (GDMaim off via the
   `no_gdmaim` feature).
2. Runs both PCKs headless (`--main-pack`), with `GDMAIM_E2E_BUILD=obfuscated|plain`.
3. Checks the fixture's `E2E <id> PASS|FAIL [reason]` lines and the closing `E2E_DONE <n>`.

Ids in `tests/e2e/xfail.txt` must fail in the obfuscated build; an XPASS is an error, and the fix
deletes the line. The plain build must pass everything. The last line is the verdict:
`E2E: <p> passed, <x> xfail, <f> failed (obfuscated) | <p2>/<n> plain`. Exit codes: 0 clean,
1 check failures, 2 harness error (no Godot, or a failed import or export, printed with the log
tail). A whole run takes about 15 s locally. CI (`.github/workflows/e2e.yml`) runs the same command
on GitHub-hosted Ubuntu for every PR.

**Add a check:** write `tests/e2e/fixture/checks/<id>.gd` (`extends RefCounted`,
`func run() -> String`, returning `""` on pass or a reason that shows the values it saw), then add
its path to `CHECKS` in `main.gd`. The classes it needs go in `lib/`, and its data in `data/`.

Traps:

- **An error is a failure, even when `run()` returns `""`.** A runtime error aborts `run()`, which
  then returns its type's default, `""`. That reads as a pass, so `main.gd` registers a `Logger`
  and fails any check that logs an error (warnings don't count). A passing check must log nothing.
- **Reference rule.** A name a check looks up by string (`&"e2e_call_target"`, the method in
  `refs.json`) may appear as a string only in the place that check exercises: not in another
  check, a comment or a failure message. Otherwise, once string-referenced names are auto-locked,
  a lock from elsewhere hides a regression. `obfuscation_active` builds its name at runtime, so no
  literal ever equals it.
- **Expected noise.** The import logs `Cannot open file 'res://data/strings.en.translation'`
  before the CSV is imported. Every Godot run also logs `Cannot get keys from nonexistent section
  "preset.N.options"`, plus GDMaim's invalid-UID, seed, `convert_text_resources_to_binary` and
  no-autoload warnings.
- **`.claude/hidden-run-patterns`** names `tests/run_e2e.py`, so the user-level hook runs it on
  the hidden desktop. Keep it when you rename the runner.

## Workstreams

`plans/` holds a workstream's overview, phase briefs and `*-stack.json` while it is in flight.
`/workstream-phase` (in `.claude/skills/`) executes one brief. A `/workstream-run` coordinator in
the SEVER repo drives the stack, running `tools/orchestrate.py` with its cwd set to this checkout.
When a workstream closes out:

1. Its invariants move here.
2. Its rationale moves to `docs/`.
3. Every leftover becomes a row in `plans/followup-index.md`.
4. Its overview, briefs and stack file are deleted.
