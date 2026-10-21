# Follow-up: string lock report rotation and the stale README caveat

Found in phase 4 (string auto-lock). Neither was in its brief.

## 1. Reports are never pruned

Each export writes `<export><timestamp>.gd.string_locks.txt` into `settings.source_map_path`.
`_export_end` (`addons/gdmaim/export_plugin.gd`) prunes that folder down to
`source_map_max_files`, but it only counts files whose name is exactly as long as the `.gd.map`
name, so the reports are never counted or deleted. They pile up, one per export.

Fix: prune each report together with its map. For example, after deleting a map `X.gd.map`, also
delete `X.gd.string_locks.txt` if it exists. Test it in `tests/run_e2e.py` by exporting with
`source_map_max_files` low enough to prune, or settle for a code read if a third export costs too
much.

## 2. README "String identifiers" caveat is out of date

`README.md` → *Limitations and caveats* → *String identifiers* still says lookups by string name
"will not work without workarounds" and recommends `##OBFUSCATE_STRINGS`. With
`lock_string_referenced_symbols` on (the fork default), literal names work as they are. The
section should say so, keep the workarounds for names built at runtime, and point to
*Changed defaults*.
