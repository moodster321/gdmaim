# Follow-up backlog: index

Every deferred follow-up in this fork, in one ranked list. It was created when the `gdmaim-p0`
workstream closed out (PRs #1–#4). Rows date from that pass.

This index is the one permanent file in `plans/`. Everything else in `plans/` is either work in
flight or a brief behind one of the rows below. When a workstream finishes, its close-out PR does
four things: moves invariants into `CLAUDE.md`, moves rationale into `docs/`, adds a row here for
each leftover, and deletes the workstream's plans. Nothing outside `plans/` cites a plan; cite
the PR instead. Done means merged to `main`. A row of "row" in the Brief column means the item
has no brief, and the row is the brief.

## Priority

| Tier | Means |
|---|---|
| **P0** | Wrong today, data loss or security, for a project exporting with the fork |
| **P1** | Blocks using the fork on SEVER, or silently breaks a real game export |
| **P2** | Latent correctness, and test/CI reliability (false passes, flakes) |
| **P3** | Polish, unreached cases, open decisions |
| **P4** | Debt, performance, tooling |

Sizes: XS is under an hour, S a sitting, M a day or two, L more.

## P1: Blocks SEVER, or breaks a real export

| Item | Brief | Size |
|---|---|---|
| **Integrate the fork into SEVER.** Re-vendor `addons/gdmaim/` and commit SEVER's `.gdmaim/export.cfg` with a real seed. Wire `release.yml`. Rewrite the "do not re-add" rule in SEVER's `.claude/rules/release-security.md`. Reconcile with SEVER PR #954: its `script_export_mode=2` makes GDMaim see zero scripts, because GDMaim needs mode 0 and makes binary tokens itself. | row | L |
| **SEVER names built at runtime are not auto-locked.** About 16 event-bus `listen`/`ignore` calls take a variable method name, and there are `callv` sites such as SEVER `SceneRouter.gd:344`. Convert them to Callables in SEVER, and add a lint rule there. | row | M |
| **Dictionary dot access breaks.** `x.foo` is renamed whenever any script declares `foo` (`symbol_table.gd:105-121`). A typed `Dictionary[K,V]` is recorded as `"Dictionary.K.V"` (`parser.gd:221-235`), so it misses the `"Dictionary"` exception at `symbol_table.gd:118`. As a result, `d.key` on JSON or dictionary data is renamed. | row | M |

## P2: Latent correctness, test and CI reliability

| Item | Brief | Size |
|---|---|---|
| The string auto-lock hides a broken class-name lock: the class checks compare against class-name literals, which phase 4 locks anyway. | [gdmaim-p0-followup-class-checks-masked](gdmaim-p0-followup-class-checks-masked.md) | S |
| Parse errors don't fail the export. Tokenizer and parser errors are only logged (`parser.gd:269`, `tokenizer.gd:341`) and the export carries on. Expression parsing is an empty TODO (`parser.gd:285-290`). | row | M |
| Excluded files are still shuffled and stripped. `addons/` should be left byte-for-byte unchanged. Excluding a file also locks every name it mentions (`script_obfuscator.gd:458-467`). | row | M |
| On zero exported scripts, `_export_end` returns early (`export_plugin.gd:237`) and skips `_godot_files.restore()`. That leaves `.godot/global_script_class_cache.cfg` rewritten on disk. | row | S |
| Names aren't stable across patches. If a member's generated name collides with a local's, the member gets a longer name, depending on processing order (`symbol_table.gd:197-208`). A patch can therefore rename a member. Fold the name map into SEVER's `compute_build_hash`, so mismatched online peers are refused. | row | M |
| `builtins.gd` is a hand-written Godot 4.2 list from Jan 2024. Generate it from ClassDB and Variant at export time, the way engine classes already are (`export_plugin.gd:158`). | row | M |
| `gdbc` is a port of the 4.5 tokenizer and is unverified on 4.7. Its binary output (`.gdc`, `.res`, `.scn`) also needs matching encryption filters. | row | M |

## P3: Polish, unreached cases, decisions

| Item | Brief | Size |
|---|---|---|
| `lock_class_names` misses a `class_name` declared in a script embedded in a `.tscn`. SEVER has none. | [gdmaim-p0-followup-embedded-class-names](gdmaim-p0-followup-embedded-class-names.md) | S |
| Source map line numbers drift, because `token.line` counts output lines (`tokenizer.gd:648`). Archive each release's map so Sentry stack traces can be mapped back. | row | M |

## P4: Debt, performance, tooling

| Item | Brief | Size |
|---|---|---|
| The quoted-string scan treats a scene's whole `script/source = "…"` as one string, so every name an embedded script mentions is over-locked. That costs obfuscation, but nothing breaks. | [gdmaim-p0-followup-string-lock-embedded-sources](gdmaim-p0-followup-string-lock-embedded-sources.md) | S |
| `*.string_locks.txt` reports are never pruned. The README's *String identifiers* caveat is also stale. | [gdmaim-p0-followup-string-lock-report-housekeeping](gdmaim-p0-followup-string-lock-report-housekeeping.md) | XS |
| The custom-tokens file path is inside the addon folder (`settings.gd:45`), so upgrading the addon wipes it. | row | S |
