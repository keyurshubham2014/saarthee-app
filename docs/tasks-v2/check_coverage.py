#!/usr/bin/env python3
"""Feature-coverage verification layer for the Saarthee task plan.

Compares every active requirement in requirements-registry.md with the verification
matrix in coverage-verification.md and reports which requirements have not been
verified against the running system.

Usage:
    python3 docs/tasks/check_coverage.py              # report
    python3 docs/tasks/check_coverage.py --sync       # add missing registry rows to the matrix
    python3 docs/tasks/check_coverage.py --task TASK-04   # only rows owned by one task

Matrix statuses:
    Not Verified  - nothing checked yet (default)
    Pass          - verified in the running system; Evidence column says how
    Fixed         - a gap was found and fixed; Evidence names the commit
    Fail          - verified and broken; must be fixed before TASK-10 closes
    Deferred      - consciously not delivered; Evidence names who decided and when

Exit codes: 0 = every active requirement is Pass/Fixed/Deferred, 1 = gaps remain, 2 = bad files.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REGISTRY = HERE / "requirements-registry.md"
MATRIX = HERE / "coverage-verification.md"
REQ_ROW = re.compile(r"^\|\s*(REQ-[A-Z]-\d{3})\s*\|(.*)\|\s*$")
TASK_ID = re.compile(r"TASK-\d{2}")
DONE = {"Pass", "Fixed", "Deferred"}
STATUSES = {"Not Verified", "Pass", "Fixed", "Fail", "Deferred"}


def read_registry() -> dict[str, dict]:
    if not REGISTRY.exists():
        sys.exit(f"missing {REGISTRY}")
    active: dict[str, dict] = {}
    deferred = False
    for line in REGISTRY.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            deferred = "deferred" in line.lower()
            continue
        m = REQ_ROW.match(line.strip())
        if not m or deferred:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        active[cells[0]] = {
            "text": cells[1],
            "owner": (TASK_ID.findall(cells[-1]) or ["?"])[0],
        }
    return active


def read_matrix() -> dict[str, dict]:
    rows: dict[str, dict] = {}
    if not MATRIX.exists():
        return rows
    for line in MATRIX.read_text(encoding="utf-8").splitlines():
        m = REQ_ROW.match(line.strip())
        if not m:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        # | Req ID | Requirement | Owner | Status | Evidence | Verified On |
        if len(cells) < 6:
            continue
        rows[cells[0]] = {"owner": cells[2], "status": cells[3], "evidence": cells[4], "date": cells[5]}
    return rows


def sync(active: dict[str, dict], matrix: dict[str, dict]) -> int:
    missing = [r for r in active if r not in matrix]
    if not missing:
        return 0
    lines = MATRIX.read_text(encoding="utf-8").rstrip("\n").splitlines()
    for req in missing:
        text = active[req]["text"].replace("|", "/")
        if len(text) > 110:
            text = text[:107] + "..."
        lines.append(f"| {req} | {text} | {active[req]['owner']} | Not Verified | — | — |")
    MATRIX.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(missing)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sync", action="store_true", help="append registry rows missing from the matrix")
    parser.add_argument("--task", help="limit the report to one owning task, e.g. TASK-04")
    args = parser.parse_args()

    active = read_registry()
    if not MATRIX.exists():
        print(f"missing {MATRIX}", file=sys.stderr)
        return 2
    matrix = read_matrix()

    if args.sync:
        added = sync(active, matrix)
        print(f"Added {added} missing row(s) to {MATRIX.name}")
        matrix = read_matrix()

    problems: list[str] = []
    for req, row in matrix.items():
        if req not in active:
            problems.append(f"{req} is in the matrix but not active in the registry (deferred or removed?)")
        if row["status"] not in STATUSES:
            problems.append(f"{req} has unknown status '{row['status']}'")
        if row["status"] in {"Pass", "Fixed", "Deferred"} and row["evidence"] in {"", "—", "-"}:
            problems.append(f"{req} is '{row['status']}' but has no evidence")

    scope = {r: v for r, v in active.items() if not args.task or v["owner"] == args.task}
    by_status: dict[str, list[str]] = {s: [] for s in STATUSES}
    by_status["Missing"] = []
    for req in scope:
        status = matrix.get(req, {}).get("status", "Missing")
        by_status.setdefault(status, []).append(req)

    done = sum(len(by_status[s]) for s in DONE)
    total = len(scope)
    pct = round(done / total * 100) if total else 100
    label = f" for {args.task}" if args.task else ""
    print(f"Coverage verification{label}: {done}/{total} verified ({pct}%)")
    for status in ["Pass", "Fixed", "Deferred", "Fail", "Not Verified", "Missing"]:
        if by_status.get(status):
            print(f"  {status:<13} {len(by_status[status])}")

    gaps = by_status["Fail"] + by_status["Not Verified"] + by_status["Missing"]
    if gaps:
        print("\nUnverified or failing:")
        for req in sorted(gaps):
            status = matrix.get(req, {}).get("status", "Missing")
            print(f"  ✗ {req} [{scope[req]['owner']}] {status} — {scope[req]['text'][:90]}")
    if problems:
        print("\nMatrix problems:")
        for p in problems:
            print(f"  ! {p}")

    if problems:
        return 2
    return 1 if gaps else 0


if __name__ == "__main__":
    sys.exit(main())
