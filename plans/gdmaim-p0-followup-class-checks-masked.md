# Follow-up: phase 4's auto-lock will hide a `lock_class_names` regression

Found in phase 3 (keep class names). It only bites once phase 4 (string auto-lock) lands.

## What

Phase 3's three class checks each compare against a class-name literal:

| Check | Literal |
|---|---|
| `class_identity` | `&"E2EItem"` |
| `script_extends_class` | `&"E2EBase"` |
| `class_cache_consistent` | `&"E2EChain"` |

`data/item.tres` also carries `script_class="E2EItem"`.

Phase 4 auto-locks every declared name that equals a string literal in a `.gd` file or a quoted
string in a `.tres`. Once it lands, all three class names are locked by those literals, whatever
`lock_class_names` says. If `lock_class_names` broke (the setting was ignored, or `_class_symbols`
went empty), all three checks would still pass. With phase 3 alone, flipping the default off fails
all three (see the phase 3 PR).

## Options

1. **Build the expected names at runtime**, the way `obfuscation_active` does, so no literal
   equals a class name. For example, derive the expected name from the script's file name, or
   join two fragments. This keeps one export per build.
2. **A third export** with `lock_string_referenced_symbols=false` and `lock_class_names=true`,
   running only the class checks. This is stronger but costs about 5 s more per run.

Option 1 is cheaper. Whichever lands, prove it the way phase 3 did: flip `lock_class_names` to
`false` with phase 4 merged, and all three class checks must fail.
