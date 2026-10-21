# GDMaim P0 Phase 1 — end-to-end export harness, every P0 check, CI

Part of the GDMaim P0 workstream. Read `plans/gdmaim-p0-overview.md` first for the user decisions
and the verified Godot facts. Branch: `claude/gdmaim-p0-phase1-e2e-harness`, cut from
`gdmaim-p0`; open the PR with base `gdmaim-p0` on `moodster321/gdmaim`. Predecessor: none.
Successor: `plans/gdmaim-p0-phase2-keep-data.md`, which branches from this PR's branch and
consumes the check ids and the xfail mechanism defined here. visual: no

## Context

The fork has no tests, no Godot project and no CI. The repo root holds only `addons/gdmaim/`
(about 5.4k lines), `docs/`, the README and the license. Everything GDMaim does happens inside an
editor export, so the only trustworthy test is a real export:

1. Export a fixture project twice, once obfuscated and once with GDMaim off.
2. Run both PCKs.
3. Compare what the fixture's checks report.

The planning spike proved this works headless on 4.7.1 without export templates (overview,
facts).

This phase writes **every** P0 check now, so the contract for phases 2-4 is fixed up front. Checks
that fail on today's addon are listed in `tests/e2e/xfail.txt`, and each later phase deletes its
lines. **This phase makes no change under `addons/gdmaim/`.**

## Design

### 1. Layout

```
tests/run_e2e.py                 runner (Python 3, stdlib only)
tests/e2e/xfail.txt              ids expected to FAIL in the obfuscated build
tests/e2e/fixture/project.godot  plugin enabled, main scene, translations
tests/e2e/fixture/export_presets.cfg
tests/e2e/fixture/main.tscn + main.gd      runs every check, prints results
tests/e2e/fixture/checks/<id>.gd           one check per file
tests/e2e/fixture/lib/*.gd                 classes the checks use
tests/e2e/fixture/data/*                   item.tres, legacy_save.txt, keep.csv(+.import),
                                           strings.csv, refs.json, refs.dialogue, tscn_ref.tscn
.github/workflows/e2e.yml
.claude/hidden-run-patterns      one line: tests[\\/]run_e2e\.py
```

Add `.gitignore` negations for the fixture: `!tests/**/project.godot`,
`!tests/**/export_presets.cfg`, `!tests/**/*.import`, `!tests/**/*.txt`. Never commit
`.godot/`, `*.uid` or a `.gdmaim/` directory under the fixture: the tests must see the addon's
defaults.

### 2. Fixture project

- **`project.godot`:**
  - `config/name="gdmaim_e2e"`
  - `run/main_scene="res://main.tscn"`
  - `config/features=PackedStringArray("4.7")`
  - `[editor_plugins] enabled=PackedStringArray("res://addons/gdmaim/plugin.cfg")`
  - `[internationalization] locale/translations=PackedStringArray("res://data/strings.en.translation")`
- **`export_presets.cfg`:** two presets, both `platform="Windows Desktop"`,
  `export_filter="all_resources"`, `include_filter="*.csv,*.txt,*.json,*.dialogue"`,
  `script_export_mode=0` and `encrypt_pck=false`, each with an empty `[preset.N.options]`.
  - `preset.0` is `name="Obfuscated"`, `custom_features=""`.
  - `preset.1` is `name="Plain"`, `custom_features="no_gdmaim"`.
- **`main.gd`:**
  - Holds `const CHECKS: Array[String]`, the `res://checks/<id>.gd` paths in the table order
    below.
  - For each path it `load`s the script. A null load prints `E2E <id> FAIL script did not load`.
  - Otherwise it runs `var err: String = script.new().run()` and prints
    `E2E <id> PASS` when `err == ""`, else `E2E <id> FAIL <err>`. The id is the file's basename.
  - After the loop it prints `E2E_DONE <count>` and quits.
- **Each check:** `extends RefCounted` with `func run() -> String`, returning `""` on pass or a
  short reason that includes the values it saw.
- **Reference rule.** Each name that a phase-4 check looks up by string must appear only in
  the place that check exercises, and nowhere else in the fixture. Otherwise an earlier lock hides
  a regression.
- **Build kind.** Read with `OS.get_environment("GDMAIM_E2E_BUILD")` (`obfuscated` or `plain`).
- **`user://` files.** Name them per build kind, e.g. `user://e2e_<build>_roundtrip.tres`.

### 3. Classes (`lib/`)

- **`E2EBase`** (`class_name E2EBase extends Resource`): no members.
- **`E2EItem`** (`class_name E2EItem extends E2EBase`): `@export var e2e_power: int = 0` and
  `@export_storage var e2e_secret: String = ""`.
- **`E2ETarget`** (`class_name E2ETarget extends RefCounted`):
  - `signal e2e_ping`
  - `var e2e_counter: int = 0`, `var e2e_typed_value: int = 3`, `var e2e_hidden_member: int = 1`
  - `func e2e_typed_method() -> String`, which returns `"typed-ok"`
  - a method for each by-string check, returning `"<id>-ok"`: `e2e_literal_method`,
    `e2e_call_target`, `e2e_callable_target`, `e2e_json_target`, `e2e_tscn_target`
- **`E2EStory`** (`class_name E2EStory extends RefCounted`): `func e2e_dialogue_target() -> String`.
- **`E2EHolder`** (`class_name E2EHolder extends Node`): `@export var e2e_callback_name: String = ""`.
- **`E2EChain`** (`class_name E2EChain extends RefCounted`): twelve chained typed members,
  `var e2e_c0: int = 1`, `var e2e_c1: int = e2e_c0 + 1`, up to `e2e_c11`.

### 4. Checks

Each row gives the expected result on today's addon, and which phase must flip it to PASS in the
obfuscated build. Every check must PASS in the plain build.

| id | what it asserts | today (obf.) | flips in |
|---|---|---|---|
| `obfuscation_active` | name built at runtime `"e2e_hidden" + "_member"` is **absent** from `E2ETarget.new().get_property_list()` in the obfuscated build and present in the plain build | PASS | guard, never xfail |
| `typed_access` | `E2ETarget.new().e2e_typed_value == 3` and `e2e_typed_method() == "typed-ok"` | PASS | guard |
| `translation_csv` | `TranslationServer.set_locale("en")`, then `tr("E2E_HELLO") == "Hello e2e"` (row in `data/strings.csv`) | PASS expected | guard |
| `export_duplicate` | `load("res://data/item.tres") as E2EItem` is 7/"abc"; its `.duplicate()` is too | FAIL | 2 |
| `export_save_roundtrip` | `ResourceSaver.save` of that item to `user://`, then a `CACHE_MODE_IGNORE` load, is still 7/"abc" | FAIL | 2 |
| `legacy_save_load` | copy `data/legacy_save.txt` (a `.tres` body with **real** names, `e2e_power = 11`, `e2e_secret = "old"`, script by path `res://lib/e2e_item.gd`) to `user://`, load it typed, get 11/"old" | FAIL | 2 |
| `keep_csv_exported` | `res://data/keep.csv` (`.import` says `importer="keep"`) exists and its first line is `a,b` | FAIL | 2 |
| `init_order` | `E2EChain.new().e2e_c11 == 12` | FAIL (shuffle) | 2 |
| `class_identity` | `load("res://lib/e2e_item.gd").get_global_name() == &"E2EItem"` | FAIL | 3 |
| `script_extends_class` | walking `get_base_script()` from `e2e_item.gd` finds `get_global_name() == &"E2EBase"` (SEVER's `Utils.scriptExtendsClass`) | FAIL | 3 |
| `has_method_literal` | `E2ETarget.new().has_method(&"e2e_literal_method")` | FAIL | 4 |
| `call_literal` | `.call(&"e2e_call_target") == "call_literal-ok"` | FAIL | 4 |
| `callable_literal` | `Callable(t, &"e2e_callable_target").call() == "callable_literal-ok"` | FAIL | 4 |
| `get_set_literal` | `t.set(&"e2e_counter", 5)`, then `t.get(&"e2e_counter") == 5` **and** typed `t.e2e_counter == 5` | FAIL | 4 |
| `connect_literal` | `t.connect(&"e2e_ping", <lambda that sets a flag in an Array>)`, typed `t.e2e_ping.emit()`, flag set | FAIL | 4 |
| `dialogue_reference` | read `res://data/refs.dialogue` (one line, `do E2EStory.e2e_dialogue_target()`), regex out the method name, then `has_method` + `call` on `E2EStory.new()` returns `"dialogue_reference-ok"` | FAIL | 4 |
| `json_reference` | `JSON.parse_string` of `res://data/refs.json` (`{"method": "e2e_json_target"}`), then `call` returns `"json_reference-ok"` | FAIL | 4 |
| `tscn_reference` | instantiate `res://data/tscn_ref.tscn` (an `E2EHolder` with `e2e_callback_name = "e2e_tscn_target"`), read it typed, `call` that name on `E2ETarget.new()`, get `"tscn_reference-ok"`, free the node | FAIL | 4 |

**Expected failures.** `xfail.txt` starts with exactly the FAIL ids above, grouped under
`# phase 2`, `# phase 3` and `# phase 4` comment headers.

**A guard that fails today.** If a guard or a `PASS expected` row fails on today's addon, it is
a newly found P0. Add it to `xfail.txt` under `# found in phase 1`, describe it in the PR body,
and do not fix it.

**A FAIL row that passes today.** Investigate before you weaken it. For `init_order`, lengthen
the chain until shuffle reorders it.

### 5. Runner `tests/run_e2e.py`

Usage: `python tests/run_e2e.py [--keep] [--only <id>]`.

1. **Find Godot:** `$GODOT_BIN`, else `$GODOT_PATH`, else `godot` on `PATH`. On Windows, if the
   path ends in `.exe` and `<stem>_console.exe` exists beside it, use the console exe. With no
   Godot, exit 2.
2. **Make a temp copy:** `tempfile.mkdtemp()`, then `copytree` the fixture into it. Copy the
   repo's `addons/gdmaim` to `<tmp>/addons/gdmaim`, ignoring `source_maps`, `backup` and
   `export.cfg`. Create `<tmp>/out` and `<tmp>/run`.
3. **Import:** `<godot> --headless --path <tmp> --import` (timeout 300 s).
4. **Export:** for each preset, `<godot> --headless --path <tmp> --export-pack "<preset>"
   <tmp>/out/<obfuscated|plain>.pck` (timeout 600 s). A non-zero exit or a missing PCK exits 2,
   printing the log tail.
5. **Run:** `<godot> --headless --main-pack <pck>` with cwd `<tmp>/run`, env
   `GDMAIM_E2E_BUILD=<kind>` and a 120 s timeout. Parse lines matching
   `^E2E (\S+) (PASS|FAIL)(?: (.*))?$` and `^E2E_DONE (\d+)$`.
6. **Verdict:**
   - Plain build: every check must PASS.
   - Obfuscated build: a check not in `xfail.txt` must PASS. One in `xfail.txt` must FAIL;
     passing is XPASS, a failure that says "remove `<id>` from `xfail.txt`".
   - A missing `E2E_DONE`, or a check id missing from the output, is a failure that prints the
     run log's last 40 lines.
   - `--only <id>` filters the verdict, not the export.
7. **Output:** quiet by default. Print each failure, then one line:
   `E2E: <p> passed, <x> xfail, <f> failed (obfuscated) | <p2>/<n> plain`.
   `E2E_VERBOSE=1` streams every Godot log.
   - Exit codes: 0 = clean, 1 = check failures, 2 = harness error.
   - The temp dir is deleted unless `--keep`, which prints its path.

### 6. CI `.github/workflows/e2e.yml`

- **Triggers:** `on: pull_request` (any base) and `push` to `main` and `gdmaim-p0`.
- **Job:** one job, `e2e`, on `ubuntu-latest` with `timeout-minutes: 20`.
- **Steps:**
  1. `actions/checkout@v4`.
  2. `actions/cache@v4` on `~/godot`, key `godot-4.7.1-stable-linux`.
  3. On a cache miss, `curl -fsSL` the URL from the overview and `unzip` it into `~/godot`, then
     `mv` the binary to `~/godot/godot`.
  4. `GODOT_BIN="$HOME/godot/godot" python3 tests/run_e2e.py`, with the env set inside `run:`,
     because `~` is not expanded in `env:`.

### 7. Docs

- **README:** add a section `## About this fork (moodster321)`. Say why the fork exists, how to
  run `python tests/run_e2e.py`, and include a `### Changed defaults` list, empty for now, that
  phases 2-4 append to.
- **`CLAUDE.md`:** fill in its *Tests* section with the real commands, and add the trap list from
  your Risks if any bit you.

## Files to touch

- New: `tests/run_e2e.py`, `tests/e2e/xfail.txt`, the whole `tests/e2e/fixture/` tree from the
  layout above, `.github/workflows/e2e.yml` and `.claude/hidden-run-patterns`.
- Edit: `.gitignore` (the negations), `README.md` (the fork section) and `CLAUDE.md` (its *Tests*
  section).

## Tests to add

The checks in Design §4 are the tests.

- **No string references by accident.** A check script must not mention another check's
  by-string name in a string, comment or docstring (the reference rule in §2).
- **Typing.** Use typed GDScript and `as` casts. A failed cast returns null, so check for null
  before reading fields, and return a reason instead of crashing.
- **Lambdas.** A lambda can't reassign captured locals; mutate an `Array` instead
  (`connect_literal`).
- **Free nodes.** Free the instantiated node in `tscn_reference`, so the run doesn't print a
  leak warning.

## Verification

1. **The suite passes.** Run `python tests/run_e2e.py`: exit 0, and the verdict shows 3 passed,
   15 xfail, 0 failed (obfuscated), plus 18/18 plain. Adjust the numbers if §4's
   found-in-phase-1 rule moved a row, and say so in the PR.
2. **The harness catches failures.** Delete the `class_identity` line from `xfail.txt` locally:
   exit 1, with `class_identity` reported. Restore it. Then add `obfuscation_active` to
   `xfail.txt`: exit 1, with XPASS reported. Restore it. Paste both outputs into the PR body.
3. **Git sees the fixture.** `git status --porcelain` lists `tests/e2e/fixture/project.godot`,
   `export_presets.cfg`, `data/keep.csv.import` and `data/legacy_save.txt` as added. Nothing
   under `.godot/` and no `*.uid` is tracked.
4. **No addon change.** `git diff --stat gdmaim-p0 -- addons/` prints nothing.
5. **CI runs.** The `e2e` job runs on the PR and is green. Its log shows the same verdict line.

## Risks / open questions

- **Windows preset on Linux.** The `Windows Desktop` preset was proven on Windows only. If the
  Linux CI editor won't `--export-pack` it, you may switch both presets to `platform="Linux"`;
  say so in the PR.
- **Export paths.** Passing an absolute `--export-pack` path is unverified; the spike used a
  relative path with cwd set to the project. If the absolute path fails, run the export with
  `cwd=<tmp>` and a relative `out/<kind>.pck`.
- **Translation file name.** If the `.translation` name differs from `strings.en.translation`,
  read the generated name after `--import` and use it in `project.godot`. That counts as fixing
  the fixture, not GDMaim.
- **Startup print.** GDMaim injects a source-map print into the first autoload. The fixture has
  no autoload, so expect the `No valid autoload found!` warning. Don't add an autoload.
- **First CI run.** If the fork's first Actions run needs a manual "enable workflows" click, say
  `PHASE 1 BLOCKED Actions disabled on fork` and stop. That is the user's click.
