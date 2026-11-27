#!/usr/bin/env python3
"""Run every GDScript smoke test and print a compact coverage matrix."""
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = ROOT / "tools" / "godot" / "godot"


def check_web_contract():
    proc = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_web_shell.py")],
        capture_output=True, text=True, cwd=ROOT,
    )
    ok = proc.returncode == 0
    print(f"{'web_shell_contract':38} {'PASS' if ok else 'FAIL':12} checks=9")
    if not ok:
        print("   ", proc.stdout.strip().replace("\n", " "))
    return ok


def main():
    tests = sorted((ROOT / "tests").glob("*_smoke.gd"))
    failed = []
    started = time.time()
    if not check_web_contract():
        failed.append("web_shell_contract")
    for test in tests:
        proc = subprocess.run(
            [str(GODOT), "--headless", "--path", str(ROOT),
             "--script", f"res://tests/{test.name}"],
            capture_output=True, text=True, timeout=180,
        )
        out = proc.stdout + proc.stderr
        results = re.findall(r"RESULT: (PASS|FAIL[^\n]*)", out)
        status = results[-1] if results else (
            "OK" if proc.returncode == 0 else f"EXIT {proc.returncode}")
        checks = len(re.findall(r"\[ok\]", out))
        explicit = re.findall(r"CHECKS: (\d+)", out)
        if explicit:
            checks = int(explicit[-1])
        print(f"{test.name:38} {status:12} checks={checks}")
        if status != "PASS" and status != "OK":
            failed.append(test.name)
            for line in out.splitlines():
                if "[fail]" in line or "SCRIPT ERROR" in line:
                    print("   ", line.strip())
    elapsed = time.time() - started
    print(f"\n{len(tests) + 1 - len(failed)}/{len(tests) + 1} passed in {elapsed:.1f}s")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
