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

## Tests

`python tests/run_e2e.py` copies `tests/e2e/fixture/` and the addon to a temp dir, then:

1. Exports it twice, as `Obfuscated` and as `Plain` (GDMaim off via the `no_gdmaim` feature).
2. Runs both PCKs headless.
3. Checks the fixture's `E2E <id> PASS|FAIL` lines.

Ids in `tests/e2e/xfail.txt` must fail in the obfuscated build; an XPASS is an error. The plain
build must pass everything. Exit codes: 0 clean, 1 check failures, 2 harness error.
`E2E_VERBOSE=1` streams the Godot logs. CI (`.github/workflows/e2e.yml`) runs the same command on
GitHub-hosted Ubuntu.

*(Phase 1 of the `gdmaim-p0` workstream creates the runner. Until it lands, this section is the
spec it implements.)*

## Workstreams

`plans/` holds a workstream's overview, phase briefs and `*-stack.json` while it is in flight.
`/workstream-phase` (in `.claude/skills/`) executes one brief. A `/workstream-run` coordinator in
the SEVER repo drives the stack, running `tools/orchestrate.py` with its cwd set to this checkout.
The plans are deleted when the workstream closes out.
