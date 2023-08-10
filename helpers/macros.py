import sys

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
    # returns: label, name, flags
    cleaned_args = []

    line = line.replace("defword ", "")

    for s in line.split(','):
        s = s.strip()
        if len(s)==0:
            s = None
        elif len(s)>=2:
            if s[0] == s[-1] == '"' or s[0] == s[-1] == '"' :
                s=s[1:-1]
        cleaned_args.append(s)

    cleaned_args.append(None)
    cleaned_args.append(None)

    if cleaned_args[1] is None:
        cleaned_args[1] = cleaned_args[0]

    cleaned_args[2] = strtoint(cleaned_args[2])

    return cleaned_args[0:3]

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
