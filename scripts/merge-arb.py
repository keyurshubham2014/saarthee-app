#!/usr/bin/env python3
"""Integrator helper: during a conflicted merge, key-union both ARB files (ours order, then new keys from theirs)."""
import json, subprocess, collections
for f in ['apps/mobile/lib/core/l10n/app_en.arb', 'apps/mobile/lib/core/l10n/app_gu.arb']:
    o = json.loads(subprocess.check_output(['git', 'show', ':2:' + f]), object_pairs_hook=collections.OrderedDict)
    t = json.loads(subprocess.check_output(['git', 'show', ':3:' + f]), object_pairs_hook=collections.OrderedDict)
    n = 0
    for k, v in t.items():
        if k not in o:
            o[k] = v; n += 1
    open(f, 'w').write(json.dumps(o, ensure_ascii=False, indent=2) + '\n')
    print(f, '+', n)
