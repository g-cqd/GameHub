import re,glob,collections,sys
outs={}; ins={}; sysin={}
for f in glob.glob("ll/*.ll"):
    s=open(f).read()
    for m in re.finditer(r"^define [^@]*@((?:gs|ps|ds)_\w+)\(",s,re.M):
        n=m.group(1)
        if n.startswith(("gs","ds")):
            outs[n]=set(re.findall(r"air.mesh_vertex_data\", i32 \d+, !\"(user\(\w+\))",s))
        else:
            ins[n]=set(re.findall(r"air.fragment_input\", !\"(user\(\w+\))",s))
            sysin[n]=set(re.findall(r"!\"(air\.(?:primitive_id|front_facing|sample_id|render_target_array_index|viewport_array_index))\"",s))
tab=collections.Counter(); ex={}
for line in open(sys.argv[1]):
    m=re.match(r"(OK|FAIL)\s+(\S+) \+ (\S+) \+ (\S+)(?: : (.*))?",line.strip())
    if not m: continue
    st,o,g,p,err=m.groups()
    if err and "depth" in err: continue
    crash= st=="FAIL" and "XPC" in (err or "")
    if st=="FAIL" and not crash: tab["otherfail"]+=1; ex.setdefault("other",err); continue
    missing=bool(ins[p]-outs[g])
    k=("missing_varying" if missing else "all_varyings_written", "CRASH" if crash else "ok")
    tab[k]+=1
    ex.setdefault(k,(g,p,sorted(ins[p]-outs[g]),sorted(sysin[p])))
for k,v in sorted(tab.items(),key=str): print(k,v)
for k,v in ex.items(): print(k,v)
