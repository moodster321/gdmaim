---
name: workstream-phase
description: Execute one approved phase brief of this fork end to end — implement it exactly, get tests/run_e2e.py green, open the PR on moodster321/gdmaim on the base the brief names, and report PHASE <N> DONE <pr-url> or PHASE <N> BLOCKED <reason>. Invoke it when a launch prompt names it or the user types `/workstream-phase <brief>`.
user-invocable: true
argument-hint: "plans/<slug>-phase<N>-<name>.md"
---

# /workstream-phase — implement one phase (GDMaim fork)

You are a **phase session**. A coordinator prepared your worktree, branch and brief. Your job is
one brief, start to finish, ending in an open PR with green CI. You do not merge, and you do not
touch other phases.

`$ARGUMENTS` is the brief path. If it's empty, look for `plans/*-phase*.md` whose name matches
this branch; if more than one matches, ask.

**Do not enter plan mode.** The user already approved the brief, and its overview's *Decisions
made with the user* are settled. Execute it.

## 1. Read

Read in this order:

1. `CLAUDE.md`
2. The overview (`plans/<slug>-overview.md`). It carries the user's decisions and the Godot
   facts verified during planning. Trust them; don't re-derive them.
3. Your brief.
4. Your row in `plans/<slug>-stack.json`: the PR `base`, the exact `pr_title`, and the
   `evidence` the PR body must carry. The stack's `label` is your workstream label.

If the brief contradicts the code, implement the brief's intent and say so in the PR body. Don't
silently substitute your own design.

## 2. Implement exactly the brief's scope

Anything **out of scope** goes into `plans/<slug>-followup-<topic>.md` on your branch, with
enough detail to pick it up cold: a real bug, a missing test, an adjacent cleanup. Don't fix it
inline. Code and tests never cite a `plans/` file.

## 3. Gate

```bash
python tests/run_e2e.py
```

It must exit 0. Exit 1 means check failures, which it names; exit 2 means a harness or export
error, which it prints with the log tail. Rerun with `E2E_VERBOSE=1` for full Godot logs. If a
failure looks pre-existing, prove it on the base commit before spending time on it. Phase 1
builds this runner: until it exists, its brief's Verification section is your gate.

## 4. Commit and push

Commit with a descriptive message ending in the `Co-Authored-By` trailer your session's
attribution instructions give. Then run `git push -u origin <your branch>`. `claude/*` branches push without asking.

## 5. Open the PR on the fork, on the right base

```bash
gh pr create --repo moodster321/gdmaim --base <brief's base> --title "<stack pr_title>" \
  --label "<stack label>" --body-file <file>
```

The body carries your brief's **Verification** results, meaning the actual output, not a claim
that you ran them. It also carries whatever the stack row's `evidence` names, and it ends with:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Then **immediately check what you got**:

```bash
gh pr view <n> --repo moodster321/gdmaim --json baseRefName,title,labels,url
```

If the base, title or label is wrong, fix it with `gh pr edit <n> --repo moodster321/gdmaim …`
before anything else. Watch for a PR that landed on upstream `cherriesandmochi/gdmaim`, or with
base `main`. If it landed upstream, close it at once (`gh pr close <n> --repo
cherriesandmochi/gdmaim`), open it again correctly, and mention it in your report.

## 6. Wait for CI

```bash
gh pr checks <n> --repo moodster321/gdmaim --watch
```

Fix red CI on your own branch until it's green. The `e2e` job takes a few minutes; a cold
Godot download adds about one more.

## 7. Report and stop

- Green: reply exactly `PHASE <N> DONE <pr-url>` and stop.
- Stuck: reply exactly `PHASE <N> BLOCKED <reason>`, in one line: what you tried and what you
  need.

**Never merge your PR.** The next phase branches from yours, and a human reviews the whole stack
at the end. Leave the session open, since the coordinator or the user may send a follow-up.
