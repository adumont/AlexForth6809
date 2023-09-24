import sys
from pyparsing import *

def strtoint(s):
    if s is None:
        return 0
    elif s[0] == "$":
        return int(s[1:],16)
    elif s[0:2] == "0x":
        return int(s[2:],16)
    elif s[0] == "%":
        return int(s[1:],2)
    else:
        return int(s)

def parse_line(line):
    # label, name, flags = None, None, None
    flags_pattern = Or([
        common.integer,
        Combine("$" + Word(alphanums)),
        Combine("0x" + Word(alphanums)),
        Combine("%" +OneOrMore(one_of("0 1"))),
    ])
    pattern = "defword" + quoted_string + Opt(","+Opt(quoted_string, default=None)+Opt(","+Opt(flags_pattern,default=None),default=","))
    res = pattern.parse_string(line)

    label=res[1][1:-1] if len(res)>=2 else None
    name=res[3][1:-1]  if len(res)>=4 else label
    flags = res[5]     if len(res)>=6 else None

    return label, name, strtoint(flags)

def name_to_bytes(name):
    a = [ c for c in bytearray(name, 'utf-8') ]
    return ', '.join([ "$%X" % c for c in a ])

def process_defword(line):
    global prev_label

    label, name, flags = parse_line( line )

    print(f"""; defword "{label}", "{name}", {flags}
h_{label}
    FDB {prev_label} ; link
    FCB {len(name) | flags} ; len | flags
    FCB {name_to_bytes(name)} ; "{name}"
do_{label}""")

    prev_label = f"h_{label}"

prev_label = 0

while True:
    line = sys.stdin.readline()
    if not line:
        break

    if line.startswith("defword"):
        process_defword(line)
    elif line.startswith("p_LATEST"):
        print(f"p_LATEST    EQU    {prev_label}")
    else:
        print(line,end="")
