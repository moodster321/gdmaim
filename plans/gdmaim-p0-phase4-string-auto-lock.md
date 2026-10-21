# GDMaim P0 Phase 4 — auto-lock every name a string references

Part of the GDMaim P0 workstream. Read `plans/gdmaim-p0-overview.md` first for the user decisions
and the verified Godot facts. Branch: `claude/gdmaim-p0-phase4-string-auto-lock`, cut from
`claude/gdmaim-p0-phase3-keep-class-names`; open the PR with base
`claude/gdmaim-p0-phase3-keep-class-names` on `moodster321/gdmaim`. Predecessor:
`plans/gdmaim-p0-phase3-keep-class-names.md`. Successor: none (last phase). visual: no

## Context

GDMaim renames identifiers but never strings. The only protection is the per-line hints
`##OBFUSCATE_STRINGS` and `##OBFUSCATE_STRING_PARAMETERS`
(`obfuscator/script/script_obfuscator.gd:46-54, 131-227`). So `call(&"x")`, `has_method("x")`,
`Callable(obj, &"x")`, `get`/`set`/`connect` by name, and names in data files all break after
renaming.

SEVER reaches its own code by string about 1,700 times, including:

- 112 `call(&"…")`
- 142 `has_method`
- 22 `Callable(obj, &"…")`
- 94 event-bus `listen` method names
- 43 `get(&"template")`
- 13 `Story.*` calls in `.dialogue` files, written as bare identifiers, not strings

Phase 1 left eight checks under `# phase 4` in `tests/e2e/xfail.txt`: `has_method_literal`,
`call_literal`, `callable_literal`, `get_set_literal`, `connect_literal`, `dialogue_reference`,
`json_reference` and `tscn_reference`.

User decision (overview): **every matching literal** locks its name. Narrowing it to name-taking
calls was rejected.

## Design

### 1. Settings

Add these to `settings.gd` next to `lock_class_names`, each with `add_entry` in the `obfuscator`
category:

- `var lock_string_referenced_symbols : bool = true`. Visible name "Keep String-Referenced
  Names". Tooltip: "If true, any declared name that appears in a string literal, or in the
  listed data files, keeps its real name, so call/has_method/get/set/connect/Callable by name
  keep working. Names built at runtime are not detected. Fork default: on."
- `var string_reference_word_extensions : String = "dialogue"`. Visible name "Scan Every Word
  In". Every identifier-shaped word in these files counts. Dialogue lines call methods as bare
  identifiers.
- `var string_reference_quoted_extensions : String = "json,tscn,tres,cfg"`. Visible name "Scan
  Quoted Strings In". Only text inside `"…"` counts.

Both lists are comma-separated and split with `split(",", false)`, then `strip_edges()`. Register
them with `add_entry` like `symbol_prefix` (`settings.gd:117`), which already shows a `String`
entry as a line edit in the dock.

### 2. Candidate extraction (one rule everywhere)

A **reference string** is split on `[^A-Za-z0-9_]+`. Every piece that matches
`^[A-Za-z_][A-Za-z0-9_]*$` is a candidate. So `"Story.set_flag"`, `"node:prop"` and `"a/b"` all
yield their parts. Reference strings come from three places:

1. **`.gd` scripts, including scripts embedded in `.tscn`.** For each obfuscator in
   `_src_obfuscators`, walk its tokens the way `check_exclusion_source` does
   (`script_obfuscator.gd:458-467`): `tokenizer.reset()`, then `get_next()` until null, then
   `reset()`. Every token whose type is `Token.Type.STRING_LITERAL` or
   `Token.Type.STRING_MULTI_LINE` contributes its `get_value()`. That covers `"x"`, `&"x"` and
   `^"x"` (the tokenizer reads `&` as a separate operator: overview facts). Comments never count.
2. **Word files.** For each extension in `string_reference_word_extensions`, take
   `_get_files("res://", "." + ext)` (`export_plugin.gd:607`), which already skips dot-dirs,
   `.gdignore` dirs and the addon. The whole file text is one reference string.
3. **Quoted files.** For each extension in `string_reference_quoted_extensions`, the same file
   walk. Every match of `"((?:\\.|[^"\\])*)"` in the file text is one reference string.

### 3. Locking

New method `_lock_string_referenced_symbols() -> int` in `export_plugin.gd`. Call it in
`_export_begin` only when `settings.lock_string_referenced_symbols`. It runs after phase 3's class
lock and before `_symbols.resolve_symbol_paths()` (`:188`), so before `obfuscate_symbols()`
(`:192`).

For each unique candidate, if `_symbols.find_global_symbol(candidate)` is non-null, call
`_symbols.lock_symbol_name(candidate)` and record it.

- Undeclared candidates are ignored: they're engine names, already locked, or noise.
- The method returns the count of distinct names it locked.
- Use a `Dictionary` as the seen-set; SEVER has thousands of literals.

### 4. Report

After locking:

- Print `GDMaim - Kept <n> names referenced by strings.`
- Write the sorted names, one per line, to
  `settings.source_map_path.path_join(_source_map_filename.get_basename() + ".string_locks.txt")`.
  That directory is the gitignored `source_maps/`. Create it if it's missing.
- A write failure is a `push_warning`, never an abort.

### 5. Not detected (document, don't fix)

Names built at runtime (`"_on_" + x`, `"%s_changed" % f`, a method name stored in a variable
from code) are not detected. Write this under `### Changed defaults` in the README, together with
the fact that the lock can be audited through `*.string_locks.txt`.

### 6. xfail

Delete the eight ids and the `# phase 4` header. `tests/e2e/xfail.txt` keeps only its leading
comment and is otherwise empty. The runner must accept an empty list; fix it if it doesn't.

## Files to touch

- Edit: `addons/gdmaim/export_plugin.gd` (§2-§4), `addons/gdmaim/settings.gd` (§1),
  `tests/e2e/xfail.txt`, `README.md`.
- Fixture: only if a check is provably wrong in the plain build too; explain in the PR.

## Tests to add

- **`string_lock_report`** (new check, runner-side, not in the fixture). After the obfuscated
  export, `run_e2e.py` asserts that a `*.string_locks.txt` exists under
  `<tmp>/addons/gdmaim/source_maps/`. It must contain `e2e_literal_method`, `e2e_dialogue_target`,
  `e2e_json_target` and `e2e_tscn_target`. It must **not** contain `e2e_hidden_member`: that name
  is built at runtime only, and this proves the lock doesn't over-reach into the
  `obfuscation_active` guard.
- **Report it as a check.** Fold it into the verdict as one extra check, counted in the
  obfuscated totals.

## Verification

1. **The suite passes.** Run `python tests/run_e2e.py`: exit 0, with 19 passed, 0 xfail, 0 failed
   (obfuscated, counting `string_lock_report`), plus 18/18 plain. Add one each if phase 3
   added `class_cache_consistent`.
2. **Obfuscation still happens.** `obfuscation_active` passes, and the obfuscated
   `lib/e2e_target.gd` in a `--keep` run's PCK does **not** contain `e2e_hidden_member`. Check
   with `grep -ac e2e_hidden_member <tmp>/out/obfuscated.pck`, which prints 0. Paste it.
3. **The setting is the cause.** Flip `lock_string_referenced_symbols` to `false` locally: all
   eight phase-4 checks fail again. Paste that output, then restore the default.
4. **Scope.** `git diff --stat claude/gdmaim-p0-phase3-keep-class-names` touches only the files
   above and `tests/run_e2e.py`.
5. **CI.** The `e2e` job is green on the PR.

## Risks / open questions

- **Tokens after the parse.** `check_exclusion_source` runs right after `parse` and walks the
  tokenizer, so tokens are available at that point. If they're consumed by the time your method
  runs, collect the strings inside `_parse_script` instead, right after
  `check_exclusion_source` (`export_plugin.gd:499` and `:516`), into a member `PackedStringArray`.
  The lock itself must still run before `:188`.
- **Multi-line strings.** If `STRING_MULTI_LINE` tokens include their quote characters, the
  split in §2 drops them harmlessly.
- **Speed.** For a large project (SEVER: about 730 scripts, about 600 `.tres`/`.tscn`), keep the
  pass linear: one regex compile and one dictionary. Don't call `find_global_symbol` per
  occurrence; call it per unique candidate.
- **Over-locking is acceptable.** Each extra lock is a name left plain, never a break. The
  `obfuscation_active` guard and the report's negative assertion catch a lock that has gone
  global.
