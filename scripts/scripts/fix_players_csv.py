#!/usr/bin/env python3
import csv, os
from urllib.parse import quote_plus

CSV_PATH = "assets/players.csv"

def make_avatar_url(name: str) -> str:
    # UI Avatars – encodes spaces and accents automatically
    n = quote_plus(name.strip())
    return f"https://ui-avatars.com/api/?name={n}&background=0D8ABC&color=fff&bold=true"

def make_futbin_url(name: str) -> str:
    # Futbin search URL (safe generic link)
    q = quote_plus(name.strip())
    return f"https://www.futbin.com/players?q={q}"

def main():
    if not os.path.exists(CSV_PATH):
        raise SystemExit(f"Not found: {CSV_PATH}")

    # Read
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))

    if not rows:
        raise SystemExit("CSV is empty")

    header = [h.strip() for h in rows[0]]
    # Normalize the header to exactly these 5 columns
    expected = ["name", "rating", "position", "imageUrl", "futbinUrl"]

    # If header is missing the new columns, extend it
    if header[:3] == ["name", "rating", "position"]:
        header = expected
    else:
        # Force to expected header anyway to fix typos like "hame"
        header = expected

    fixed = [header]

    for r in rows[1:]:
        # pad/truncate to 5 columns
        r = (r + ["", "", "", "", ""])[:5]

        name = (r[0] or "").strip()
        rating = (r[1] or "").strip()
        position = (r[2] or "").strip()

        # Only fill imageUrl/futbinUrl if empty
        imageUrl = r[3].strip() or make_avatar_url(name) if name else ""
        futbinUrl = r[4].strip() or make_futbin_url(name) if name else ""

        fixed.append([name, rating, position, imageUrl, futbinUrl])

    # Write back
    with open(CSV_PATH, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerows(fixed)

    print(f"Fixed and saved {CSV_PATH} with {len(fixed)-1} players.")

if __name__ == "__main__":
    main()
