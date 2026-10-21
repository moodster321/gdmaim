# Follow-up: the quoted scan keeps every name an embedded script mentions

Found in phase 4 (string auto-lock). Out of its scope: the brief scans every quoted string in the
`string_reference_quoted_extensions` files, and over-locking is accepted there.

## What

A script built into a scene is saved in the `.tscn` as one quoted property value:

```
script/source = "extends Node

func _on_hit():
	emit_signal(\"died\")
"
```

`_lock_string_referenced_symbols` (`addons/gdmaim/export_plugin.gd`) runs `"((?:\\.|[^"\\])*)"` over
each `.tscn`, so that whole source is one reference string. Every identifier in the embedded
script, code and comments alike, becomes a candidate, and every one that a script declares is
locked project-wide. The script's real string literals (`"died"`) are already covered by the token
walk over `_src_obfuscators`, which includes embedded scripts as `<path>:<index>`.

Effect: a project with embedded scripts gets those scripts' names, and the same names in every
other script, left plain. Nothing breaks, but less is obfuscated. Confirmed by reading the code;
the fixture has no embedded script, so it was not run.

## Fix

Drop the embedded sources before the quoted scan, so only the token walk sees them. The pattern
`_parse_script` uses to find them is `script\/source\s*=\s*"((?:\\.|[^"\\])*)\n"`. Share it
as a constant (today it is built lazily into `_rgx`, which the lock can't rely on) and `sub()` it
out of `.tscn`/`.scn` text before `quoted_rgx.search_all`.

## Test

Add `data/embedded.tscn` with a built-in script that declares and calls a method no string names,
plus a check that instantiates it. Then extend `string_lock_report` in `tests/run_e2e.py` to
assert that method is **not** in the report. Prove the assertion bites by reverting the fix.
