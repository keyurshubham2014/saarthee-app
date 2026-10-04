#!/usr/bin/env python3
"""Integrator helper: three-way ARB merge during a conflicted merge.
Keeps ours; adds keys new in theirs; takes theirs' edits where ours is unchanged;
never re-adds keys that ours deleted since the merge base."""
import json, subprocess, collections
for f in ['apps/mobile/lib/core/l10n/app_en.arb', 'apps/mobile/lib/core/l10n/app_gu.arb']:
    g = lambda st: json.loads(subprocess.check_output(['git', 'show', f':{st}:' + f]), object_pairs_hook=collections.OrderedDict)
    b, o, t = g(1), g(2), g(3)
    added = [k for k in t if k not in o and k not in b]
    edited = [k for k in t if k in o and k in b and t[k] != b[k] and o[k] == b[k]]
    for k in added + edited: o[k] = t[k]
    open(f, 'w').write(json.dumps(o, ensure_ascii=False, indent=2) + '\n')
    print(f, '+', len(added), 'edited', len(edited))
