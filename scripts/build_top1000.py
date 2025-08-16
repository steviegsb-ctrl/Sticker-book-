import csv, pathlib, sys

RAW_URL = "https://raw.githubusercontent.com/prashantghimire/sofifa-web-scraper/main/output/player-data-full.csv"
SRC = pathlib.Path("data/players_raw.csv")
OUT = pathlib.Path("assets/players.csv")
OUT.parent.mkdir(parents=True, exist_ok=True)
SRC.parent.mkdir(parents=True, exist_ok=True)

# Column keys commonly found in SoFIFA-style dumps
NAME_KEYS   = ["short_name","name","player_name","long_name"]
RATING_KEYS = ["overall","overall_rating","rating","ovr"]
POS_KEYS    = ["player_positions","positions","best_position","position"]

def pick(row, keys, default=""):
    for k in keys:
        if k in row and str(row[k]).strip():
            return str(row[k]).strip()
    return default

def first_pos(s):
    s = (s or "").strip()
    return s.split(",")[0].strip() if "," in s else s

def to_int(s, default=-1):
    try:
        return int(float(str(s).strip()))
    except:
        return default

def download_raw():
    try:
        import urllib.request
        print("Downloading raw player CSV…")
        urllib.request.urlretrieve(RAW_URL, SRC.as_posix())
        return True
    except Exception as e:
        print("Download warning:", e)
        return False

if not SRC.exists():
    ok = download_raw()
    if not ok and not SRC.exists():
        print("Error: could not download dataset and no local data/players_raw.csv present.")
        sys.exit(1)

rows = []
with SRC.open("r", encoding="utf-8", newline="") as f:
    r = csv.DictReader(f)
    for row in r:
        name = pick(row, NAME_KEYS)
        rating = to_int(pick(row, RATING_KEYS))
        pos = first_pos(pick(row, POS_KEYS))
        if not name:
            continue
        rows.append((name, rating, pos))

# Dedup by name, keep highest rating
best = {}
for n, ra, po in rows:
    if n not in best or ra > best[n][0]:
        best[n] = (ra, po)

# Top 1000 by rating desc, then name asc
top = sorted(best.items(), key=lambda kv: (-kv[1][0], kv[0]))[:1000]

with OUT.open("w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["name","rating","position"])
    for name, (ra, po) in top:
        w.writerow([name, ra if ra >= 0 else "", po])

print(f"Wrote {OUT} with {len(top)} players")
