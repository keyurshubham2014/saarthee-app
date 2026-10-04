"""Gives every Gujarati language system the script's full default features.

Upstream Mukta Vaani's `GUJ ` LangSys (under `gjr2` and `gujr`) lists 12 GSUB
features where the script default lists 22, leaving out the conjunct features
(half, rphf, blwf, pres, ...). Shapers pick `GUJ ` when the text language is
Gujarati, which is how the app runs, so conjuncts fell apart: "પ્ર" drew as
"પ્‌ર", "વોર્ડ" lost its reph. Making each LangSys use the default feature
list restores normal shaping for Gujarati text.

Usage: python3 tool/fonts/fix_langsys.py FONT.ttf [...]   (edits in place)
       python3 tool/fonts/fix_langsys.py --check FONT.ttf [...]
"""
import sys

from fontTools.ttLib import TTFont

SCRIPTS = {"gjr2", "gujr"}


def mismatches(font):
    out = []
    for tag in ("GSUB", "GPOS"):
        if tag not in font:
            continue
        for sr in font[tag].table.ScriptList.ScriptRecord:
            if sr.ScriptTag not in SCRIPTS or sr.Script.DefaultLangSys is None:
                continue
            want = sorted(sr.Script.DefaultLangSys.FeatureIndex)
            for lr in sr.Script.LangSysRecord:
                if sorted(lr.LangSys.FeatureIndex) != want:
                    out.append((tag, sr.ScriptTag, lr.LangSysTag, lr))
    return out


def main(argv):
    check = argv[:1] == ["--check"]
    files = argv[1:] if check else argv
    bad = 0
    for path in files:
        font = TTFont(path)
        found = mismatches(font)
        for tag, script, lang, lr in found:
            print(f"{path}: {tag} {script}/{lang.strip()} differs from the default")
        if check:
            bad += len(found)
            continue
        if found:
            for tag in ("GSUB", "GPOS"):
                if tag not in font:
                    continue
                for sr in font[tag].table.ScriptList.ScriptRecord:
                    if sr.ScriptTag in SCRIPTS and sr.Script.DefaultLangSys is not None:
                        dflt = sr.Script.DefaultLangSys
                        for lr in sr.Script.LangSysRecord:
                            lr.LangSys.FeatureIndex = list(dflt.FeatureIndex)
                            lr.LangSys.FeatureCount = len(dflt.FeatureIndex)
                            lr.LangSys.ReqFeatureIndex = dflt.ReqFeatureIndex
            font.save(path)
            print(f"{path}: fixed")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
