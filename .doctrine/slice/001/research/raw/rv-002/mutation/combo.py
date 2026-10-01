import json, subprocess, shutil, os, tempfile, re
SRC="/tmp/iwmut"
allm = {x[0]:x for f in ("m1.json","m2.json") for x in json.load(open(f))}
V1=("V1","org-iw.el","    (goto-char marker)\n    (org-fold-reveal)","    (goto-char marker)\n    (set-buffer-modified-p t)\n    (org-fold-reveal)")
V2=("V2","org-iw.el","    (goto-char marker)\n    (org-fold-reveal)","    (goto-char marker)\n    (save-excursion (goto-char (point-max)) (insert \" \"))\n    (org-fold-reveal)")
for combo in [[V1],[V1,allm["H4"]],[V2],[V2,allm["H4"]],[V2,allm["H1"]]]:
    d = tempfile.mkdtemp(dir="/tmp/mut")
    [shutil.copy(os.path.join(SRC,x), d) for x in os.listdir(SRC) if x.endswith(".el")]
    shutil.copytree(os.path.join(SRC,"test"), os.path.join(d,"test"))
    for _,f,old,new in combo:
        p=os.path.join(d,f); s=open(p).read(); assert s.count(old)==1,(f,old); open(p,"w").write(s.replace(old,new))
    loads=sum([["-l","test/"+t] for t in sorted(os.listdir(d+"/test")) if t.endswith("-test.el")],[])
    r=subprocess.run(["emacs","-Q","--batch","-L",".","-L","test"]+loads+["-f","ert-run-tests-batch-and-exit"],cwd=d,stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=180)
    out=r.stdout+r.stderr
    print("+".join(c[0] for c in combo), re.findall(r"FAILED\s+\d+/\d+\s+(\S+)", out))
    shutil.rmtree(d)
