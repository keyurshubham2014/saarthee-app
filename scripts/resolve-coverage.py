#!/usr/bin/env python3
"""Integrator helper: resolve git conflicts in docs/tasks-v2/coverage-verification.md row by row.
Rows are keyed by requirement id; for each id keep the side with more evidence (a non-'Not Verified'
status wins, then the longer evidence cell). Usage: python3 scripts/resolve-coverage.py [file]"""
import re, sys
p = sys.argv[1] if len(sys.argv) > 1 else 'docs/tasks-v2/coverage-verification.md'
s = open(p).read()
def score(row):
    cells = [c.strip() for c in row.split('|')]
    status = cells[4] if len(cells) > 4 else ''
    return (status not in ('Not Verified', ''), len(row))
def resolve(m):
    ours, theirs = m.group(1).splitlines(), m.group(2).splitlines()
    key = lambda r: r.split('|')[1].strip() if r.startswith('|') else r
    rows, order = {}, []
    for r in ours + theirs:
        k = key(r)
        if k not in rows: order.append(k); rows[k] = r
        elif score(r) > score(rows[k]): rows[k] = r
    return '\n'.join(rows[k] for k in order) + '\n'
s2 = re.sub(r'<<<<<<< [^\n]*\n(.*?)\n=======\n(.*?)\n>>>>>>> [^\n]*\n', resolve, s, flags=re.S)
open(p, 'w').write(s2)
print('conflict blocks left:', s2.count('<<<<<<<'))
