# GDMaim P0 fixes — overview and shared decisions

This fork of GDMaim (cherriesandmochi/gdmaim, a GDScript obfuscator that runs as an
EditorExportPlugin) is being made safe for SEVER // ctrl, a large Godot 4.7.1 game. When the
workstream is done, an obfuscated export of a project no longer loses data or breaks name lookups.
Exported fields survive `duplicate()` and `ResourceSaver`. Saves written by builds without
obfuscation still load. `importer="keep"` CSVs ship. Member initializers keep their order.
`class_name` names stay real, so `get_global_name()` checks still work. Every name the project
mentions in a string literal (`call(&"x")`, `has_method("x")`, `Callable(obj, &"x")`, the `.dialogue`
`Story.*` calls, JSON or scene strings) keeps its real name, so lookup by name keeps working. Names
that nothing references by string are still obfuscated. Every behaviour is proven by an end-to-end
export test that runs in CI on every fork PR.

Branching: integration branch **`gdmaim-p0`** (cut from fork `main` at `cdb18dc`, holds these
briefs) is the base. Each phase lives on its own branch, **stacked** on the previous phase's
branch, and opens a PR whose base is that previous branch, **on `moodster321/gdmaim`**. Do not merge
your own PR; when the PR is open and CI is green, report `PHASE <N> DONE <pr-url>` and stop.

| # | Brief | Branch (PR base) | Delivers | Mergeable alone? |
|---|---|---|---|---|
| 1 | `plans/gdmaim-p0-phase1-e2e-harness.md` | `claude/gdmaim-p0-phase1-e2e-harness` (base `gdmaim-p0`) | Fixture project, `tests/run_e2e.py`, every P0 check (failing ones listed in `tests/e2e/xfail.txt`), GitHub Actions job, README fork section | Yes — test-only, no addon change |
| 2 | `plans/gdmaim-p0-phase2-keep-data.md` | `claude/gdmaim-p0-phase2-keep-data` (base phase 1) | `@export*` never stripped; keep-CSVs pass through; defaults `obfuscate_export_vars=false`, `shuffle_top_level=false` | Yes — removes its five xfail lines |
| 3 | `plans/gdmaim-p0-phase3-keep-class-names.md` | `claude/gdmaim-p0-phase3-keep-class-names` (base phase 2) | `lock_class_names` setting, default on | Yes — removes its two xfail lines |
| 4 | `plans/gdmaim-p0-phase4-string-auto-lock.md` | `claude/gdmaim-p0-phase4-string-auto-lock` (base phase 3) | String-referenced names auto-locked (`.gd` literals, `.dialogue` words, quoted strings in `.json/.tscn/.tres/.cfg`), report file | Yes — empties `xfail.txt` |

## Decisions made with the user (do not re-open)

- **The workstream lives in the fork.** The briefs, a fork version of the `/workstream-phase`
  skill and a short `CLAUDE.md` sit on the integration branch in `moodster321/gdmaim`. Phase PRs
  open on the fork, and `/workstream-run` drives them in sub-sessions.
- **Fork-only, safe defaults.** Change the fork's defaults to what the game needs: keep class
  names, auto-lock on, exported vars not renamed. The fixes are **not** shaped for upstream, and
  the fork is allowed to drift from upstream behaviour.
- **Auto-lock breadth: every matching literal.** Any `"x"` or `&"x"` in `.gd`, plus strings in
  `.dialogue`/`.json`/`.tscn`/`.tres`, that equals a declared name keeps that name. This is
  simple and can't miss a wrapper. Narrowing it to name-taking calls was rejected.
- **CI: GitHub Actions.** GitHub-hosted Ubuntu runs the end-to-end export tests on every fork PR
  with Godot 4.7.1 headless. It never uses the game's self-hosted runner.
- **Done means the fork's tests are green.** Every P0 behaviour is proven by the end-to-end export
  tests in CI. Exporting SEVER itself with the fork is the **next** workstream, not this one,
  because P1 issues would still break a real game export.
- **Shuffle off by default**, folded into the defaults phase (phase 2) with an init-order test.
- **Four phases:** harness + CI + CLAUDE.md, then keep data, then keep class names, then string
  auto-lock. One PR per P0 item was rejected.

## Godot / repo facts every phase relies on (verified during planning)

Checked on 2026-10-21 with stock Godot 4.7.1 (`…_console.exe`) and a scratch fixture project.

- **GDMaim runs in a CLI export.** `godot --headless --path <proj> --export-pack "<preset>" out.pck`
  exits 0 and logs `GDMaim - Exporting scripts as plain text.` It needs the plugin enabled in
  `project.godot` (`[editor_plugins] enabled=PackedStringArray("res://addons/gdmaim/plugin.cfg")`),
  `script_export_mode=0` in the preset, and one `--headless --import` first.
- **No export templates are needed.** `--export-pack` with a `platform="Windows Desktop"` preset
  writes the PCK without them, and `godot --headless --main-pack out.pck` runs it with the editor
  binary.
- **The plain baseline.** A preset with `custom_features="no_gdmaim"` exports with GDMaim
  disabled (`addons/gdmaim/export_plugin.gd:74`). Same project, same run.
- **What upstream `cdb18dc` does today** (obfuscated build next to the plain build):
  - `get_script().get_global_name()` returns `__xJN6…`, not the class name.
  - `has_method(&"name")` is false.
  - `get("exported_var")` is null, because exported names are renamed.
  - A typed `.duplicate()`, and a `ResourceSaver.save` then load, both come back `0`/`""` for
    `@export` and `@export_storage` fields; the plain build keeps 7/"abc".
  - An `importer="keep"` CSV is missing from the PCK, though the plain build ships it.
  - A translation CSV still yields `*.translation` in the PCK.
- **Loading old `.tres` files.** A text `.tres` with a **wrong** `script_class=` header loads
  fine and binds by script path, and `ResourceLoader.load(path, "<bad hint>")` still loads. So
  old saves don't depend on class names.
- **Settings.** Defaults are the var initializers at `addons/gdmaim/settings.gd:13-40`, each
  registered with `add_entry` (`settings.gd:93-130`). They are saved to `res://.gdmaim/export.cfg`
  and `addons/gdmaim/export.cfg` (`settings.gd:156-171`), and a stored value overrides the default
  (`settings.gd:186-188`). The fixture must never commit a `.gdmaim/export.cfg`, so the tests see
  the fork's defaults.
- **Export flow.** `_export_begin` (`export_plugin.gd:63`) runs in this order:
  1. Locks the builtins (`:117-130`), custom tokens (`:132-155`) and every ClassDB name
     (`:158-160`).
  2. Parses every `.gd`/`.tscn`/`.scn` (`:163-165`).
  3. Resolves (`:188`), then obfuscates (`:192`).

  **Every new lock must run between `:165` and `:188`.** `_export_file` (`:355`) then rewrites
  file by file. `_get_files` (`:607`) skips dot-dirs, `.gdignore` dirs and the addon itself.
- **Symbols.** Class-body names are global and keyed by name alone (`obfuscator/symbol_table.gd:43-66`).
  `lock_symbol_name` (`:29`) keeps a name for both globals and locals (`:142-150`). The parser
  records each `class_name` in `_class_symbols` (`export_plugin.gd:518-519`), which is **never
  cleared** between exports.
- **String tokens.** Strings tokenize as `STRING_LITERAL`/`STRING_MULTI_LINE` without their
  quotes. `&"x"` is the operator `&` followed by `STRING_LITERAL x`
  (`obfuscator/script/tokenizer/tokenizer.gd:440-452, 670`). To walk a parsed script's tokens:
  `tokenizer.reset()`, then `tokenizer.get_next()` until null, then `reset()` again
  (`obfuscator/script/script_obfuscator.gd:458-467`).
- **`.gitignore` trap.** The fork's `.gitignore` ignores `project.godot`, `export_presets.cfg`,
  `*.import`, `*.txt`, `*.uid` and `export.cfg` **everywhere**. Fixture files need `!` negations,
  and `git status` must show them before you commit.
- **Side effects.** An export writes into the project: `res://.gdmaim/`,
  `addons/gdmaim/export.cfg`, `addons/gdmaim/source_maps/`, `addons/gdmaim/backup/` and
  `addons/gdmaim/.gitignore`. Always export from a temp copy.
- **Harmless export noise:**
  - `Cannot get keys from nonexistent section "preset.N.options"`
  - invalid-UID warnings for GDMaim's own `.tscn` files
  - `seed is still set to the default value of 0`
  - `convert_text_resources_to_binary … will be ignored`
  - `No valid autoload found!`
- **Godot binary.** `$GODOT_PATH` here is the GUI exe
  (`C:/Users/mdsoo/Downloads/Godot_v4.7.1-stable_win64/Godot_v4.7.1-stable_win64.exe`). Its
  sibling `…_console.exe` is the one whose stdout can be captured. CI uses
  `https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip`.
  Always pass `--headless`, and launch Godot from Bash, never PowerShell.
- **GitHub.** The fork is public and Actions are enabled (API). `gh repo set-default` was pointed
  at `moodster321/gdmaim` during planning. Even so, **always pass `--repo moodster321/gdmaim`** to
  `gh pr create`/`view`/`edit`/`checks`, because `gh` in a fork otherwise targets the upstream
  parent.
- **Coordinator.** `tools/orchestrate.py` lives in the game repo, resolves the repo from its
  **cwd** (`git rev-parse --git-common-dir`, orchestrate.py:77-80) and reads CI with
  `gh pr checks --repo <stack repo>` (orchestrate.py:175-187). The coordinator therefore runs it
  with cwd set to `M:/Godot Projects/GDMaim`, and worktrees land in
  `M:/Godot Projects/GDMaim/.claude/worktrees/`.

## Follow-ups (out of scope for all 4 phases)

- **Integrating with the game.** Re-vendor the fork into SEVER and commit its
  `.gdmaim/export.cfg` with a real seed. Wire `release.yml`, and reconcile with SEVER PR #954,
  whose `script_export_mode=2` makes GDMaim see zero scripts. Rewrite the "do not re-add" note in
  SEVER's `.claude/rules/release-security.md`.
- **SEVER names built at runtime.** About 16 event-bus `listen`/`ignore` calls take a variable
  method name, and there are `callv` sites such as `SceneRouter.gd:344`. Convert them to
  Callables, and add a lint rule.
- **Fail the export on parse errors.** Today they are only logged (`parser.gd:269`,
  `tokenizer.gd:341`). Expression parsing is still a TODO (`parser.gd:285-290`).
- **Dictionary dot access.** `Dictionary[K,V]` misses the dictionary exception
  (`symbol_table.gd:118`, `parser.gd:221-235`), so `d.key` is renamed.
- **Excluded files aren't left alone.** They are still shuffled and stripped, and `addons/`
  should be left untouched byte for byte.
- **Early return skips the restore.** On zero scripts, `_export_end` returns early
  (`export_plugin.gd:237`) and skips `_godot_files.restore()` (`:298`).
- **Name stability.** Whether a member's new name collides with a local depends on processing
  order (`symbol_table.gd:197-208`). Fold the name map into SEVER's `compute_build_hash`.
- **Source maps.** Line numbers drift (`tokenizer.gd:648`), and maps should be archived per
  release.
- **Stale builtins list.** `builtins.gd` is a hand-written 4.2 list from Jan 2024; generate it
  from ClassDB/Variant at export time.
- **Lost settings.** The custom-tokens path is inside the addon folder (`settings.gd:45`), so an
  upgrade wipes it.
- **`gdbc` and #954.** `gdbc` is ported from the 4.5 tokenizer and untested on 4.7, and binary
  output (`.gdc`/`.res`/`.scn`) needs matching encryption filters.
