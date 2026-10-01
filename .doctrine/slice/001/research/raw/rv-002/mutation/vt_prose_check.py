# List VT keywords that match only comment/docstring/backquoted-prose lines (or <=2 hits).
# Run from the repo root.
import tomllib
p = tomllib.load(open(".doctrine/slice/001/plan.toml", "rb"))
for ph in p["phase"]:
    for v in ph.get("verification", []):
        if "keywords" not in v:
            continue
        lines = open(v["test_file"]).read().splitlines()
        for k in v["keywords"]:
            hits = [(i + 1, l.strip()) for i, l in enumerate(lines) if k in l]
            code = [h for h in hits if not h[1].startswith(";")
                    and not h[1].startswith('"') and "`" + k not in h[1]]
            if not code or len(hits) <= 2:
                print(ph["id"], v["id"], repr(k), len(hits), "hits;", hits[:3])
