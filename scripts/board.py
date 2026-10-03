#!/usr/bin/env python3
"""board.py TASK-NN <Status> <pct>  — update a row on the summary status board."""
import re, sys
from pathlib import Path
f = Path(__file__).resolve().parent.parent / 'docs/tasks/00-task-summary.md'
tid, status, pct = sys.argv[1:4]
s = f.read_text()
def fix(m):
    cells = [c.strip() for c in m.group(0).strip().strip('|').split('|')]
    cells[2], cells[6] = status, f'{pct}%'
    return '| ' + ' | '.join(cells) + ' |'
s = re.sub(rf'^\| {tid} \|.*\|$', fix, s, count=1, flags=re.M)
done = len(re.findall(r'^\| TASK-\d\d \|[^|]*\| Complete \|', s, flags=re.M))
s = re.sub(r'^\*\*Overall Progress:\*\* .*$', f'**Overall Progress:** {done} / 10 tasks complete ({done*10}%)', s, count=1, flags=re.M)
f.write_text(s)
print('ok')
