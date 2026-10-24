import re,glob,collections,sys
outs={}; ins={}
for f in glob.glob("ll/*.ll"):
    s=open(f).read()
    for m in re.finditer(r"^define [^@]*@((?:gs|ps|ds)_\w+)\(",s,re.M):
        n=m.group(1)
        if n.startswith(("gs","ds")):
            outs[n]=set(re.findall(r"air.mesh_vertex_data\", i32 \d+, !\"(user\(\w+\))",s))
        else:
            ins[n]=[(a,b) for a,b in re.findall(r"air.fragment_input\", !\"(user\(\w+\))\", ((?:!\"[\w.]+\", )*)!\"air.arg_type_name",s)]
rows=collections.Counter()
for line in open(sys.argv[1]):
    m=re.match(r"(OK|FAIL)\s+(\S+) \+ (\S+) \+ (\S+)(?: : (.*))?",line.strip())
    if not m: continue
    st,o,g,p,err=m.groups()
    if err and "depth" in err: continue
    miss=[q for k,q in ins[p] if k not in outs[g]]
    if not miss: continue
    quals=tuple(sorted(set(q.replace("!\"air.","").replace("\", "," ").strip() for q in miss)))
    rows[(st,quals)]+=1
for k,v in sorted(rows.items()): print(v,k)
