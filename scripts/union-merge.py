#!/usr/bin/env python3
"""Integrator helper: resolve append-only git conflicts by keeping both sides (ours, then theirs)."""
import re, sys
for p in sys.argv[1:]:
    s = open(p).read()
    s2, n = re.subn(r'<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n', lambda m: m.group(1) + m.group(2), s, flags=re.S)
    open(p, 'w').write(s2)
    print(f'{p}: {n} block(s) unioned')
