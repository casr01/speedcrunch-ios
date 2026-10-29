#!/usr/bin/env python3
"""Smoke test for the C bridge through sc-cli.

Runs expressions in one session (so variables and settings carry over) and
checks the JSON the bridge returns. Usage:  python3 smoke_test.py path/to/sc-cli
"""
import json
import os
import subprocess
import sys
import tempfile

# (expression, expected first result line, or ("error", substring), or None for no result)
CASES = [
    ("2+2", "= 4"),
    ("sqrt(2)", "= 1.4142135623730950488"),
    ("1/3", "= 0.33333333333333333333"),
    ("x = 5", "= 5"),
    ("x^2 + ans", "= 30"),
    ("f(a;b) = a*b+1", None),
    ("f(3;4)", "= 13"),
    ("sin(pi/2)", "= 1"),
    ("100!", "= 9.33262154439441526817 × 10¹⁵⁷"),
    ("0x1F + 1", "= 32"),
    ("10[metre] -> [foot]", "= 32.8083989501312335958\u00a0ft"),  # NBSP before unit
    ("50[yard] + 2[foot] in [cm]", "= 4632.96\u00a0cm"),
    ("2*(", ("error", "syntax error")),
    ("foo + 1", ("error", "foo: unknown function or variable")),
    ("2+2 ? suma", "= 4"),
    ('@set {"angleUnit":"d"}', None),
    ("sin(90)", "= 1"),
    ("arcsin(1)", "= 90"),
    ('@set {"angleUnit":"r","complexNumbers":true}', None),
    ("e^(i*pi)", "= −1"),
    ("(1+2i)*(3-i)", "= 5 + 5i"),
    ('@set {"complexNumbers":false,"resultFormat":"h"}', None),
    ("255", "= 0xFF"),
    ('@set {"resultFormat":"f","precision":4}', None),
    ("pi", "= 3.1416"),
    ('@set {"resultFormat":"g","precision":-1,"decimalSeparator":",","digitGrouping":true}', None),
    ("1234567,891", "= 1.234.567,891"),
    ("max(1,5; 2)", "= 2"),
]


def main() -> int:
    cli = sys.argv[1]
    failures = 0
    with tempfile.TemporaryDirectory() as data_dir:
        env = dict(os.environ, SC_DATA_DIR=data_dir)
        lines = [(":set " + expr[5:]) if expr.startswith("@set ") else expr for expr, _ in CASES]
        out = subprocess.run([cli], input="\n".join(lines) + "\n", capture_output=True,
                             text=True, env=env, check=True).stdout.splitlines()

        results = iter(line for line in out if line.startswith("  result  ") or line.startswith("settings "))
        for expr, expected in CASES:
            line = next(results)
            if expr.startswith("@set "):
                continue
            payload = json.loads(line[len("  result  "):])
            if expected is None:
                ok = payload["ok"] and not payload.get("lines")
            elif isinstance(expected, tuple):
                ok = not payload["ok"] and expected[1] in payload.get("error", "")
            else:
                ok = payload["ok"] and payload.get("lines", [None])[0] == expected
            status = "ok  " if ok else "FAIL"
            if not ok:
                failures += 1
            print(f"{status} {expr!r:45} -> {json.dumps(payload, ensure_ascii=False)}")

        # Persistence: a new engine on the same data dir must see x and the history.
        again = subprocess.run([cli, "x + 1"], capture_output=True, text=True, env=env,
                               check=True).stdout
        persisted = '"= 6"' in again
        print(("ok  " if persisted else "FAIL") + " session persists across launches (x + 1 = 6)")
        failures += 0 if persisted else 1

    print(f"\n{len(CASES) + 1 - failures} passed, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
