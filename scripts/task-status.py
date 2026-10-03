#!/usr/bin/env python3
"""task-status.py TASK-NN <Status> <progress%> "<progress row text>" <commit> [--tick-all | --tick N,N]"""
import re, sys
from pathlib import Path
tid, status, pct, row, commit = sys.argv[1:6]
f = next((Path(__file__).resolve().parent.parent / 'docs/tasks').glob(f'{tid}-*.md'))
s = f.read_text()
s = re.sub(r'^\| Status \| .* \|$', f'| Status | {status} |', s, count=1, flags=re.M)
s = re.sub(r'^\| Last Updated \| .* \|$', '| Last Updated | 2026-10-03 |', s, count=1, flags=re.M)
s = re.sub(r'^\*\*Current status:\*\* .*$', f'**Current status:** {status}', s, count=1, flags=re.M)
s = re.sub(r'^\*\*Progress:\*\* .*$', f'**Progress:** {pct}%', s, count=1, flags=re.M)
s = s.replace('| Date | Progress | Commit |\n|---|---|---|\n', f'| Date | Progress | Commit |\n|---|---|---|\n| 2026-10-03 | {row} | {commit} |\n', 1)
args = sys.argv[6:]
if args:
    head, _, tail = s.partition('## 14. Completion Checklist')
    lines = tail.split('\n'); idx = [i for i, l in enumerate(lines) if l.startswith('- [ ]') or l.startswith('- [x]')]
    pick = idx if args[0] == '--tick-all' else [idx[int(n) - 1] for n in args[1].split(',')]
    for i in pick: lines[i] = lines[i].replace('- [ ]', '- [x]', 1)
    s = head + '## 14. Completion Checklist' + '\n'.join(lines)
f.write_text(s)
print('ok', f.name)
