#!/usr/bin/env python3
"""Validate a generated task plan.

Checks structure, status vocabulary, dependency integrity, requirement coverage in both
directions, agreement between the summary board and the task files, and completion
consistency.

Usage:
    python3 validate_tasks.py docs/tasks/
    python3 validate_tasks.py docs/tasks/ --json

Exit codes: 0 = no errors (warnings allowed), 1 = errors found, 2 = bad invocation.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

VALID_STATUSES = ["Not Started", "In Progress", "Blocked", "In Review", "Complete"]
REQUIRED_SECTIONS = {
    1: "Objective",
    2: "Scope",
    3: "Prerequisites",
    4: "Dependencies",
    5: "Technical Context",
    6: "Implementation Steps",
    7: "Acceptance Criteria",
    8: "Validation & Testing",
    9: "Deliverables",
    10: "Files Expected to Change",
    11: "Related Documentation",
    12: "Risks & Considerations",
    13: "Progress Status",
    14: "Completion Checklist",
}
REQUIRED_META_KEYS = [
    "Task ID",
    "Status",
    "Priority",
    "Size",
    "Depends On",
    "Blocks",
    "Requirement IDs",
]

TASK_ID_RE = re.compile(r"TASK-\d{2,}")
REQ_ID_RE = re.compile(r"REQ-[A-Z]-\d{3,}")
TASK_FILE_RE = re.compile(r"^TASK-(\d{2,})-.+\.md$")
AC_RE = re.compile(r"\*\*AC-(\d+)\*\*")
CHECKBOX_RE = re.compile(r"^\s*[-*]\s*\[( |x|X)\]")
SUMMARY_FILE = "00-task-summary.md"
REGISTRY_FILE = "requirements-registry.md"


@dataclass
class Findings:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def error(self, where: str, message: str) -> None:
        self.errors.append(f"{where}: {message}")

    def warn(self, where: str, message: str) -> None:
        self.warnings.append(f"{where}: {message}")


@dataclass
class Task:
    task_id: str
    path: Path
    meta: dict[str, str]
    sections: dict[int, str]
    body: str

    @property
    def status(self) -> str:
        return self.meta.get("Status", "").strip()

    @property
    def depends_on(self) -> list[str]:
        return parse_id_list(self.meta.get("Depends On", ""), TASK_ID_RE)

    @property
    def blocks(self) -> list[str]:
        return parse_id_list(self.meta.get("Blocks", ""), TASK_ID_RE)

    @property
    def requirement_ids(self) -> list[str]:
        return parse_id_list(self.meta.get("Requirement IDs", ""), REQ_ID_RE)


def parse_id_list(value: str, pattern: re.Pattern[str]) -> list[str]:
    if not value or value.strip().lower() in {"none", "n/a", "-", "—"}:
        return []
    return pattern.findall(value)


def parse_meta_table(text: str) -> dict[str, str]:
    """Read `| Key | Value |` rows from the leading metadata table."""
    meta: dict[str, str] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            if meta:
                break  # metadata table ended
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) != 2:
            continue
        key, value = cells
        if set(key) <= set("-: ") or key.lower() == "field":
            continue
        meta[key] = value
    return meta


def split_sections(text: str) -> dict[int, str]:
    """Return {section_number: section_body} for `## <n>. <title>` headings."""
    sections: dict[int, str] = {}
    current: int | None = None
    buffer: list[str] = []
    for line in text.splitlines():
        match = re.match(r"^##\s+(\d+)\.\s", line)
        if match:
            if current is not None:
                sections[current] = "\n".join(buffer)
            current = int(match.group(1))
            buffer = []
        elif current is not None:
            buffer.append(line)
    if current is not None:
        sections[current] = "\n".join(buffer)
    return sections


def load_tasks(directory: Path, findings: Findings) -> dict[str, Task]:
    tasks: dict[str, Task] = {}
    for path in sorted(directory.glob("*.md")):
        match = TASK_FILE_RE.match(path.name)
        if not match:
            continue
        text = path.read_text(encoding="utf-8")
        meta = parse_meta_table(text)
        derived_id = f"TASK-{match.group(1)}"
        declared_id = meta.get("Task ID", "").strip()
        if declared_id and declared_id != derived_id:
            findings.error(
                path.name, f"metadata Task ID '{declared_id}' does not match filename '{derived_id}'"
            )
        tasks[derived_id] = Task(
            task_id=derived_id,
            path=path,
            meta=meta,
            sections=split_sections(text),
            body=text,
        )
    return tasks


def check_structure(task: Task, findings: Findings) -> None:
    where = task.path.name

    for key in REQUIRED_META_KEYS:
        if key not in task.meta:
            findings.error(where, f"metadata table is missing '{key}'")
    if "Last Updated" not in task.meta:
        findings.warn(where, "metadata table is missing 'Last Updated'")

    if task.status and task.status not in VALID_STATUSES:
        findings.error(
            where, f"status '{task.status}' is not one of: {', '.join(VALID_STATUSES)}"
        )

    missing = [f"{n}. {title}" for n, title in REQUIRED_SECTIONS.items() if n not in task.sections]
    if missing:
        findings.error(where, "missing required sections: " + "; ".join(missing))

    for number, body in task.sections.items():
        if number in REQUIRED_SECTIONS and not body.strip():
            findings.error(where, f"section {number} ({REQUIRED_SECTIONS[number]}) is empty")

    if not task.requirement_ids:
        findings.error(where, "covers no requirement IDs — every task must trace to the registry")


def check_acceptance_criteria(task: Task, findings: Findings) -> None:
    where = task.path.name
    ac_section = task.sections.get(7, "")
    ac_ids = AC_RE.findall(ac_section)

    if not ac_ids:
        findings.error(where, "has no behavioral acceptance criteria (expected **AC-1**, **AC-2**, …)")
    if len(ac_ids) != len(set(ac_ids)):
        findings.error(where, "duplicate acceptance criterion IDs in section 7")

    blocks = re.split(r"\*\*AC-\d+\*\*", ac_section)[1:]
    for ac_id, block in zip(ac_ids, blocks):
        lowered = block.lower()
        missing = [kw for kw in ("given", "when", "then") if kw not in lowered]
        if missing:
            findings.error(where, f"AC-{ac_id} is missing: {', '.join(missing)}")

    if not CHECKBOX_RE.search(ac_section.replace("\r", "")) and not any(
        CHECKBOX_RE.match(line) for line in ac_section.splitlines()
    ):
        findings.warn(where, "section 7 has no non-functional checklist items")


def check_completion(task: Task, findings: Findings) -> None:
    where = task.path.name
    checklist = task.sections.get(14, "")
    boxes = [line for line in checklist.splitlines() if CHECKBOX_RE.match(line)]
    if not boxes:
        findings.error(where, "completion checklist has no items")
        return
    unticked = [b.strip() for b in boxes if not re.match(r"^\s*[-*]\s*\[[xX]\]", b)]
    if task.status == "Complete" and unticked:
        findings.error(
            where,
            f"status is Complete but {len(unticked)} completion checklist item(s) are unticked",
        )
    if task.status == "Not Started" and len(unticked) < len(boxes):
        findings.warn(where, "status is Not Started but some completion items are ticked")


def check_dependencies(tasks: dict[str, Task], findings: Findings) -> None:
    for task_id, task in tasks.items():
        where = task.path.name
        for dep in task.depends_on:
            if dep not in tasks:
                findings.error(where, f"depends on '{dep}', which does not exist")
            elif dep == task_id:
                findings.error(where, "depends on itself")
        for blocked in task.blocks:
            if blocked not in tasks:
                findings.error(where, f"claims to block '{blocked}', which does not exist")
            elif task_id not in tasks[blocked].depends_on:
                findings.warn(
                    where,
                    f"claims to block {blocked}, but {blocked} does not list {task_id} in Depends On",
                )
        for dep in task.depends_on:
            if dep in tasks and task_id not in tasks[dep].blocks:
                findings.warn(
                    where, f"depends on {dep}, but {dep} does not list {task_id} in Blocks"
                )
        for dep in task.depends_on:
            if dep in tasks and dep > task_id:
                findings.warn(
                    where, f"depends on {dep}, which is numbered later — check the execution order"
                )

    # cycle detection
    colour: dict[str, int] = {tid: 0 for tid in tasks}
    stack: list[str] = []

    def visit(node: str) -> None:
        colour[node] = 1
        stack.append(node)
        for dep in tasks[node].depends_on:
            if dep not in tasks:
                continue
            if colour[dep] == 0:
                visit(dep)
            elif colour[dep] == 1:
                cycle = stack[stack.index(dep):] + [dep]
                findings.error("dependencies", "cycle detected: " + " → ".join(cycle))
        colour[node] = 2
        stack.pop()

    for tid in sorted(tasks):
        if colour[tid] == 0:
            visit(tid)


def parse_registry(path: Path, findings: Findings) -> dict[str, dict]:
    """Return {req_id: {"covered_by": [...], "deferred": bool, "line": str}}."""
    entries: dict[str, dict] = {}
    deferred_section = False
    for line in path.read_text(encoding="utf-8").splitlines():
        heading = re.match(r"^#{2,}\s*(.+)$", line.strip())
        if heading:
            deferred_section = "deferred" in heading.group(1).lower() or "out of scope" in heading.group(1).lower()
            continue
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not cells:
            continue
        req_match = REQ_ID_RE.fullmatch(cells[0])
        if not req_match:
            continue
        req_id = cells[0]
        covered_by = TASK_ID_RE.findall(cells[-1]) if len(cells) > 1 else []
        if req_id in entries:
            findings.error(REGISTRY_FILE, f"{req_id} appears more than once")
        entries[req_id] = {
            "covered_by": covered_by,
            "deferred": deferred_section,
            "line": line.strip(),
        }
    return entries


def check_coverage(
    tasks: dict[str, Task], registry: dict[str, dict], findings: Findings
) -> dict:
    claimed: dict[str, list[str]] = {}
    for task_id, task in tasks.items():
        for req in task.requirement_ids:
            claimed.setdefault(req, []).append(task_id)

    active = {r: v for r, v in registry.items() if not v["deferred"]}

    for req, info in active.items():
        if not info["covered_by"]:
            findings.error(REGISTRY_FILE, f"{req} has no covering task")
            continue
        for task_id in info["covered_by"]:
            if task_id not in tasks:
                findings.error(REGISTRY_FILE, f"{req} is covered by '{task_id}', which does not exist")
            elif req not in tasks[task_id].requirement_ids:
                findings.error(
                    REGISTRY_FILE,
                    f"{req} claims coverage by {task_id}, but that task does not list {req}",
                )

    for req, task_ids in claimed.items():
        if req not in registry:
            findings.error(
                ", ".join(sorted(task_ids)), f"references {req}, which is not in the registry"
            )
        elif registry[req]["deferred"]:
            findings.warn(
                ", ".join(sorted(task_ids)), f"references {req}, which is marked deferred"
            )

    covered = sum(1 for r, v in active.items() if v["covered_by"])
    return {
        "total_requirements": len(registry),
        "active_requirements": len(active),
        "covered": covered,
        "uncovered": sorted(r for r, v in active.items() if not v["covered_by"]),
        "deferred": sorted(r for r, v in registry.items() if v["deferred"]),
    }


def check_summary(path: Path, tasks: dict[str, Task], findings: Findings) -> None:
    text = path.read_text(encoding="utf-8")
    board: dict[str, str] = {}
    for line in text.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3 or not TASK_ID_RE.fullmatch(cells[0]):
            continue
        status = next((c for c in cells[1:] if c in VALID_STATUSES), None)
        if status:
            board[cells[0]] = status

    for task_id, task in tasks.items():
        if task_id not in board:
            findings.error(SUMMARY_FILE, f"{task_id} is missing from the status board")
        elif board[task_id] != task.status:
            findings.error(
                SUMMARY_FILE,
                f"{task_id} is '{board[task_id]}' here but '{task.status}' in {task.path.name}",
            )
    for task_id in board:
        if task_id not in tasks:
            findings.error(SUMMARY_FILE, f"status board lists {task_id}, which has no task file")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a generated task plan.")
    parser.add_argument("directory", help="path to docs/tasks/")
    parser.add_argument("--json", action="store_true", help="emit machine-readable output")
    args = parser.parse_args()

    directory = Path(args.directory)
    if not directory.is_dir():
        print(f"Not a directory: {directory}", file=sys.stderr)
        return 2

    findings = Findings()
    tasks = load_tasks(directory, findings)
    if not tasks:
        print(f"No TASK-NN-*.md files found in {directory}", file=sys.stderr)
        return 2

    for task in tasks.values():
        check_structure(task, findings)
        check_acceptance_criteria(task, findings)
        check_completion(task, findings)
    check_dependencies(tasks, findings)

    coverage: dict = {}
    registry_path = directory / REGISTRY_FILE
    if registry_path.exists():
        registry = parse_registry(registry_path, findings)
        if not registry:
            findings.error(REGISTRY_FILE, "no requirement rows found")
        coverage = check_coverage(tasks, registry, findings)
    else:
        findings.error(REGISTRY_FILE, "file not found — coverage cannot be verified")

    summary_path = directory / SUMMARY_FILE
    if summary_path.exists():
        check_summary(summary_path, tasks, findings)
    else:
        findings.error(SUMMARY_FILE, "file not found")

    complete = sum(1 for t in tasks.values() if t.status == "Complete")
    result = {
        "tasks": len(tasks),
        "complete": complete,
        "progress_percent": round(complete / len(tasks) * 100),
        "coverage": coverage,
        "errors": findings.errors,
        "warnings": findings.warnings,
    }

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Tasks: {len(tasks)}  ·  Complete: {complete} ({result['progress_percent']}%)")
        if coverage:
            print(
                f"Requirements: {coverage['covered']}/{coverage['active_requirements']} covered"
                + (f"  ·  {len(coverage['deferred'])} deferred" if coverage["deferred"] else "")
            )
        if findings.errors:
            print(f"\nERRORS ({len(findings.errors)})")
            for item in findings.errors:
                print(f"  ✗ {item}")
        if findings.warnings:
            print(f"\nWARNINGS ({len(findings.warnings)})")
            for item in findings.warnings:
                print(f"  ! {item}")
        if not findings.errors and not findings.warnings:
            print("\nAll checks passed.")
        elif not findings.errors:
            print("\nNo errors.")

    return 1 if findings.errors else 0


if __name__ == "__main__":
    sys.exit(main())
