import subprocess, sys, json, re, shutil, os, tempfile
from concurrent.futures import ThreadPoolExecutor
SRC = "/tmp/iwmut"
muts = json.load(open(sys.argv[1]))
def run(m):
    mid, f, old, new = m
    d = tempfile.mkdtemp(prefix="iwm-"+mid+"-", dir="/tmp/mut")
    [shutil.copy(os.path.join(SRC,x), d) for x in os.listdir(SRC) if x.endswith(".el")]; shutil.copytree(os.path.join(SRC,"test"), os.path.join(d,"test"))
    p = os.path.join(d, f)
    s = open(p).read()
    n = s.count(old)
    if n != 1:
        return (mid, f"BADPATTERN count={n}", "")
    open(p, "w").write(s.replace(old, new))
    loads = []
    for t in sorted(os.listdir(os.path.join(d, "test"))):
        if t.endswith("-test.el"):
            loads += ["-l", "test/"+t]
    try:
        r = subprocess.run(["emacs","-Q","--batch","-L",".","-L","test","--eval","(setq load-prefer-newer t)"]+loads+["-f","ert-run-tests-batch-and-exit"],
                           cwd=d, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=180)
        out = r.stdout + r.stderr
        failed = re.findall(r"^\s+FAILED\s+\d+/\d+\s+(\S+)", out, re.M)
        summ = re.findall(r"^Ran \d+ tests.*$", out, re.M)
        status = "SURVIVED" if r.returncode == 0 else "KILLED"
        if r.returncode != 0 and not summ:
            status = "KILLED(load/crash)"
            failed = [out.strip().splitlines()[-1] if out.strip() else "?"]
    except subprocess.TimeoutExpired:
        status, failed = "KILLED(timeout)", []
    shutil.rmtree(d, ignore_errors=True)
    return (mid, status, " ".join(failed[:6]) + (f" (+{len(failed)-6})" if len(failed)>6 else ""))
with ThreadPoolExecutor(int(sys.argv[2]) if len(sys.argv)>2 else 6) as ex:
    for res in ex.map(run, muts):
        print("\t".join(res), flush=True)
