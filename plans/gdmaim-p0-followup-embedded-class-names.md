# Follow-up: `lock_class_names` misses embedded scripts

Found in phase 3 (keep class names). Out of its scope, because SEVER has no embedded script with a
`class_name`.

## What

`_parse_script` (`addons/gdmaim/export_plugin.gd`) has two paths:

- **A `.gd` file.** It parses the script, then records `obfuscator.get_class_symbol()` in
  `_class_symbols`.
- **A script embedded in a `.tscn`/`.scn`** (the `script/source = "…"` regex branch). It parses
  each source under `"<path>:<index>"` and returns early. It **never** records the class symbol.

`_export_begin` locks every key of `_class_symbols` when `settings.lock_class_names` is on. So a
`class_name Foo` inside an embedded script is still renamed. The class-cache rewrite (`Modify
class cache`) also skips it, though Godot only lists file scripts in that cache anyway.

Confirmed by reading the code on `claude/gdmaim-p0-phase3-keep-class-names`. It was not run
against a fixture.

## Fix

In the embedded branch, after `obfuscator.parse(...)`, record the class symbol the same way the
file branch does:

```gdscript
if obfuscator.get_class_symbol():
	_class_symbols[obfuscator.get_class_symbol().to_string()] = obfuscator.get_class_symbol()
```

Better still, move that block into a helper both branches call, so a third path can't miss it.

## Test

Add a fixture scene with a built-in script that declares a `class_name`, plus a check that
instantiates the scene and asserts `get_script().get_global_name()` on its root. First confirm
that Godot 4.7.1 lets a built-in script declare a `class_name` and reports it from
`get_global_name()`. If it doesn't, close this follow-up as moot.
