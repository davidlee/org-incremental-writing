import json, subprocess, shutil, os, tempfile, re, sys
SRC="/tmp/iwmut"
allm = {x[0]:x for f in ("m1.json","m2.json") for x in json.load(open(f))}
for mid in ["HEAD"]+sys.argv[1:]:
    d = tempfile.mkdtemp(dir="/tmp/mut")
    [shutil.copy(os.path.join(SRC,x), d) for x in os.listdir(SRC) if x.endswith(".el")]
    shutil.copytree(os.path.join(SRC,"test"), os.path.join(d,"test"))
    shutil.copy("probe/org-iw-probe-test.el", os.path.join(d,"test"))
    if mid!="HEAD":
        _,f,old,new = allm[mid]; p=os.path.join(d,f); s=open(p).read(); assert s.count(old)==1; open(p,"w").write(s.replace(old,new))
    r = subprocess.run(["emacs","-Q","--batch","-L",".","-L","test","-l","test/org-iw-probe-test.el","--eval","(ert-run-tests-batch-and-exit \"^probe\")"],cwd=d,stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=120)
    out=r.stdout+r.stderr
    print(mid, "FAILED:", re.findall(r"FAILED\s+\d+/\d+\s+(\S+)", out), re.findall(r"^Ran.*", out, re.M))
    shutil.rmtree(d)
