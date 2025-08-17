#!/usr/bin/env python3
import csv
from urllib.parse import quote_plus
from pathlib import Path

CSV_PATH = Path("assets/players.csv")

def make_avatar_url(name: str) -> str:
    q = quote_plus(name.strip())
    # Rounded, random bg, 256px PNG
    return f"https://ui-avatars.com/api/?name={q}&rounded=true&background=random&size=256&format=png"

def make_futbin_url(name: str) -> str:
    q = quote_plus(name.strip())
    return f"https://www.futbin.com/search?query={q}"

def main() -> None:
    if not CSV_PATH.exists():
        raise SystemExit(f"❌ CSV not found: {CSV_PATH}")

    # Read all rows
    with CSV_PATH.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        original_fields = list(reader.fieldnames or [])

    # Ensure base columns exist
    required = ["name", "rating", "position"]
    for col in required:
        if col not in original_fields:
            original_fields.append(col)

    # Ensure new columns exist
    out_fields = original_fields.copy()
    if "imageUrl" not in out_fields:
        out_fields.append("imageUrl")
    if "futbinUrl" not in out_fields:
        out_fields.append("futbinUrl")

    # Fill values
    for r in rows:
        name = (r.get("name") or "").strip()
        if name:
            if not r.get("imageUrl"):
                r["imageUrl"] = make_avatar_url(name)
            if not r.get("futbinUrl"):
                r["futbinUrl"] = make_futbin_url(name)
        else:
            # Try to be resilient if a row missed the header split
            # e.g. whole line came into 'name'
            raw = r.get(original_fields[0], "").strip()
            if raw and "," in raw:
                parts = [p.strip() for p in raw.split(",")]
                # map best we can: name,rating,position
                if len(parts) >= 3:
                    r["name"], r["rating"], r["position"] = parts[:3]
                    r["imageUrl"] = make_avatar_url(r["name"])
                    r["futbinUrl"] = make_futbin_url(r["name"])

    # Write back (overwrite) with all fields
    with CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=out_fields)
        writer.writeheader()
        for r in rows:
            writer.writerow({k: r.get(k, "") for k in out_fields})

    print(f"✅ Updated {CSV_PATH} with imageUrl and futbinUrl for {len(rows)} rows.")

if __name__ == "__main__":
    main()
