#!/usr/bin/env python3
"""End-to-end export tests for GDMaim.

Copies tests/e2e/fixture and addons/gdmaim to a temp dir, exports the fixture twice (preset
"Obfuscated", and preset "Plain", which turns GDMaim off through the no_gdmaim feature), runs
both PCKs headless and judges the fixture's "E2E <id> PASS|FAIL [reason]" lines:

- the plain build must pass every check;
- the obfuscated build must pass every check except the ids in tests/e2e/xfail.txt, which must
  fail (a listed id that passes is an XPASS error).

Usage: python tests/run_e2e.py [--keep] [--only <id>]

Godot comes from $GODOT_BIN, else $GODOT_PATH, else `godot` on PATH. E2E_VERBOSE=1 streams
every Godot log. Exit codes: 0 clean, 1 check failures, 2 harness error.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
E2E_DIR = REPO / "tests" / "e2e"
FIXTURE = E2E_DIR / "fixture"
XFAIL_FILE = E2E_DIR / "xfail.txt"
ADDON = REPO / "addons" / "gdmaim"

# (build kind, export preset name). The kind names the PCK and is passed to the game as
# GDMAIM_E2E_BUILD.
BUILDS = [("obfuscated", "Obfuscated"), ("plain", "Plain")]

IMPORT_TIMEOUT = 300
EXPORT_TIMEOUT = 600
RUN_TIMEOUT = 120
TAIL_LINES = 40

CHECK_LINE = re.compile(r"^E2E (\S+) (PASS|FAIL)(?: (.*))?$")
DONE_LINE = re.compile(r"^E2E_DONE (\d+)$")

VERBOSE = os.environ.get("E2E_VERBOSE") == "1"


class HarnessError(Exception):
    """The harness itself failed (no Godot, failed import or export): exit code 2."""


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        # Godot logs can hold characters a Windows console code page can't print.
        sys.stdout.reconfigure(errors="replace")
        sys.stderr.reconfigure(errors="replace")

    parser = argparse.ArgumentParser(description="Export the e2e fixture with and without GDMaim and check both builds.")
    parser.add_argument("--keep", action="store_true", help="keep the temp project and print its path")
    parser.add_argument("--only", metavar="ID", help="judge only this check id (everything is still exported and run)")
    args = parser.parse_args()

    try:
        return run(args)
    except HarnessError as err:
        print(f"E2E harness error: {err}", file=sys.stderr)
        return 2


def run(args: argparse.Namespace) -> int:
    check_ids = sorted(path.stem for path in (FIXTURE / "checks").glob("*.gd"))
    if not check_ids:
        raise HarnessError(f"no checks found in {FIXTURE / 'checks'}")
    xfail = read_xfail()
    unknown = sorted(xfail - set(check_ids))
    if unknown:
        raise HarnessError(f"{XFAIL_FILE.name} lists ids that are not checks: {', '.join(unknown)}")
    judged = check_ids
    if args.only:
        if args.only not in check_ids:
            raise HarnessError(f"--only {args.only}: no such check (have {', '.join(check_ids)})")
        judged = [args.only]

    godot = find_godot()
    tmp = Path(tempfile.mkdtemp(prefix="gdmaim_e2e_"))
    try:
        make_project(tmp)
        import_project(godot, tmp)
        pcks = {kind: export_pack(godot, tmp, kind, preset) for kind, preset in BUILDS}

        failures: list[str] = []
        counts: dict[str, tuple[int, int, int]] = {}
        for kind, _preset in BUILDS:
            code, lines = run_pack(godot, tmp, kind, pcks[kind])
            counts[kind] = judge(kind, code, lines, check_ids, judged, xfail, failures)
    finally:
        if args.keep:
            print(f"E2E: kept the temp project at {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)

    for failure in failures:
        print(failure)
    passed, xfailed, failed = counts["obfuscated"]
    plain_passed = counts["plain"][0]
    print(f"E2E: {passed} passed, {xfailed} xfail, {failed} failed (obfuscated) | {plain_passed}/{len(judged)} plain")
    return 1 if failures else 0


def read_xfail() -> set[str]:
    ids: set[str] = set()
    for raw in XFAIL_FILE.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            ids.add(line)
    return ids


def find_godot() -> str:
    path = os.environ.get("GODOT_BIN") or os.environ.get("GODOT_PATH") or shutil.which("godot")
    if not path:
        raise HarnessError("no Godot found: set GODOT_BIN or GODOT_PATH, or put godot on PATH")
    binary = Path(path)
    if not binary.is_file():
        raise HarnessError(f"Godot binary does not exist: {path}")
    if os.name == "nt" and binary.suffix.lower() == ".exe":
        # The GUI exe's stdout can't be captured; its _console sibling's can.
        console = binary.with_name(binary.stem + "_console.exe")
        if console.is_file():
            return str(console)
    return str(binary)


def make_project(tmp: Path) -> None:
    # The fixture never carries editor state or GDMaim settings, so the export sees the addon's
    # defaults even if someone opened the fixture in the editor.
    shutil.copytree(FIXTURE, tmp, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".godot", ".gdmaim"))
    shutil.copytree(ADDON, tmp / "addons" / "gdmaim", ignore=shutil.ignore_patterns("source_maps", "backup", "export.cfg"))
    for name in ("out", "run"):
        (tmp / name).mkdir()
        # Keep the editor's file scan (and GDMaim's) out of the build output.
        (tmp / name / ".gdignore").write_text("", encoding="utf-8")


def import_project(godot: str, tmp: Path) -> None:
    code, lines = run_godot(godot, ["--headless", "--path", str(tmp), "--import"], cwd=tmp, timeout=IMPORT_TIMEOUT, label="import")
    if code != 0:
        raise HarnessError(f"import {exit_text(code)}\n{tail(lines)}")


def export_pack(godot: str, tmp: Path, kind: str, preset: str) -> Path:
    # A relative output path with cwd set to the project resolves the same whether Godot reads it
    # relative to the cwd or to the project.
    relative = f"out/{kind}.pck"
    args = ["--headless", "--path", str(tmp), "--export-pack", preset, relative]
    code, lines = run_godot(godot, args, cwd=tmp, timeout=EXPORT_TIMEOUT, label=f"export {kind}")
    pck = tmp / relative
    if code != 0:
        raise HarnessError(f"export of preset {preset!r} {exit_text(code)}\n{tail(lines)}")
    if not pck.is_file():
        raise HarnessError(f"export of preset {preset!r} wrote no {relative}\n{tail(lines)}")
    return pck


def run_pack(godot: str, tmp: Path, kind: str, pck: Path) -> tuple[int | None, list[str]]:
    env = dict(os.environ, GDMAIM_E2E_BUILD=kind)
    args = ["--headless", "--main-pack", str(pck)]
    return run_godot(godot, args, cwd=tmp / "run", timeout=RUN_TIMEOUT, label=f"run {kind}", env=env)


def judge(kind: str, code: int | None, lines: list[str], check_ids: list[str], judged: list[str], xfail: set[str], failures: list[str]) -> tuple[int, int, int]:
    """Adds this build's failures to `failures` and returns (passed, xfailed, failed)."""
    results: dict[str, tuple[str, str]] = {}
    done: int | None = None
    for line in lines:
        line = line.strip()
        match = CHECK_LINE.match(line)
        if match:
            results[match.group(1)] = (match.group(2), match.group(3) or "")
            continue
        match = DONE_LINE.match(line)
        if match:
            done = int(match.group(1))

    passed = xfailed = failed = 0
    incomplete = False
    for check_id in judged:
        if check_id not in results:
            failures.append(f"{kind}: {check_id} is missing from the output")
            failed += 1
            incomplete = True
            continue
        status, reason = results[check_id]
        if kind == "obfuscated" and check_id in xfail:
            if status == "FAIL":
                xfailed += 1
            else:
                failures.append(f"{kind}: {check_id} XPASS: it passes now, so remove {check_id} from tests/e2e/xfail.txt")
                failed += 1
        elif status == "PASS":
            passed += 1
        else:
            failures.append(f"{kind}: {check_id} FAIL {reason}")
            failed += 1

    if done is None:
        failures.append(f"{kind}: the run printed no E2E_DONE line ({exit_text(code)})")
        incomplete = True
    elif done != len(check_ids):
        failures.append(f"{kind}: E2E_DONE reports {done} checks, but the fixture has {len(check_ids)}")
    if incomplete:
        failures.append(f"{kind}: last {TAIL_LINES} lines of the run log:\n{tail(lines)}")
    return passed, xfailed, failed


def run_godot(godot: str, args: list[str], *, cwd: Path, timeout: int, label: str, env: dict[str, str] | None = None) -> tuple[int | None, list[str]]:
    """Runs Godot with stdout and stderr merged. Returns (exit code, or None on timeout; log lines)."""
    if VERBOSE:
        print(f"--- {label}: {godot} {' '.join(args)}", flush=True)
    proc = subprocess.Popen(
        [godot, *args],
        cwd=cwd,
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    lines: list[str] = []

    def pump() -> None:
        for line in proc.stdout:
            line = line.rstrip("\r\n")
            lines.append(line)
            if VERBOSE:
                print(f"[{label}] {line}", flush=True)

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()
    try:
        code: int | None = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
        code = None
        lines.append(f"(killed after {timeout} s)")
    reader.join(timeout=10)
    return code, lines


def exit_text(code: int | None) -> str:
    return "timed out" if code is None else f"exited with code {code}"


def tail(lines: list[str]) -> str:
    return "\n".join(lines[-TAIL_LINES:])


if __name__ == "__main__":
    sys.exit(main())
