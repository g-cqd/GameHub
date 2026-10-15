import re,glob,collections,sys
outs={}; ins={}; types={}
for f in glob.glob("ll/*.ll"):
    s=open(f).read()
    for m in re.finditer(r"^define [^@]*@((?:gs|ps|ds)_\w+)\(",s,re.M):
        n=m.group(1)
        if n.startswith(("gs","ds")):
            outs[n]=dict(re.findall(r"air.mesh_vertex_data\", i32 \d+, !\"(user\(\w+\))\", !\"air.arg_type_name\", !\"(\w+)\"",s))
        else:
            ins[n]=dict(re.findall(r"air.fragment_input\", !\"(user\(\w+\))\"(?:, !\"[\w.]+\")*, !\"air.arg_type_name\", !\"(\w+)\"",s))
rows=collections.Counter()
for line in open(sys.argv[1]):
    m=re.match(r"(OK|FAIL)\s+(\S+) \+ (\S+) \+ (\S+)(?: : (.*))?",line.strip())
    if not m: continue
    st,o,g,p,err=m.groups()
    if err and "depth" in err: continue
    crash= st=="FAIL"
    mo,pi=outs[g],ins[p]
    missing=[k for k in pi if k not in mo]
    if not missing: continue
    typemis=[k for k in pi if k in mo and mo[k]!=pi[k]]
    regs_out={re.match(r"user\(reg(\d+)_",k).group(1) for k in mo}
    partial=[k for k in missing if re.match(r"user\(reg(\d+)_",k).group(1) in regs_out]
    rows[("CRASH" if crash else "ok", "nOut=%d"%len(mo), "nIn=%d"%len(pi), "nMiss=%d"%len(missing), "sameRegDiffComp=%d"%len(partial), "typeMismatch=%d"%len(typemis), "in>=out" if len(pi)>=len(mo) else "in<out")]+=1
for k,v in sorted(rows.items()): print(v,k)
