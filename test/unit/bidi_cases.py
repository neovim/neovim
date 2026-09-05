#!/usr/bin/env python3
"""Regenerate the case table in bidi_spec.lua from Unicode's conformance data.

    curl -O https://www.unicode.org/Public/UCD/latest/ucd/BidiCharacterTest.txt
    test/unit/bidi_cases.py BidiCharacterTest.txt

Cases using the explicit direction-marking characters are left out, since those
are not implemented, and so are cases with nonspacing marks: a mark travels in
the cell of the character it sits on and never reaches this code on its own.
"""

import random
import sys
import unicodedata

EXPLICIT = set(range(0x202A, 0x202F)) | set(range(0x2066, 0x206A)) | {0x200E, 0x200F, 0x061C}
COUNT = 220
MAX_LEN = 12


def eligible(codepoints):
    if len(codepoints) > MAX_LEN:
        return False
    if any(c in EXPLICIT for c in codepoints):
        return False
    return not any(unicodedata.category(chr(c)) == "Mn" for c in codepoints)


def main(path):
    cases = []
    for line in open(path):
        if line.startswith(("#", "@")) or not line.strip():
            continue
        fields = line.rstrip("\n").split(";")
        if len(fields) < 5:
            continue
        codepoints = [int(x, 16) for x in fields[0].split()]
        if not eligible(codepoints):
            continue
        cases.append((codepoints, int(fields[2]),
                      [int(x) for x in fields[3].split()],
                      [int(x) for x in fields[4].split()]))

    random.seed(7)
    random.shuffle(cases)
    # One case per line reads far better than what stylua does to a table of
    # numbers, and these lines are generated, not written.
    print("-- stylua: ignore")
    print("local cases = {")
    for codepoints, para_level, levels, order in cases[:COUNT]:
        print("  { { %s }, %d, { %s }, { %s } }," % (
            ", ".join("0x%04x" % c for c in codepoints),
            para_level,
            ", ".join(str(x) for x in levels),
            ", ".join(str(x) for x in order)))
    print("}")


if __name__ == "__main__":
    main(sys.argv[1])
