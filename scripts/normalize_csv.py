# scripts/normalize_csv.py
import csv, json, sys, pathlib, re

SRC = pathlib.Path(sys.argv[1])       # p.ej. datasets/g2/raw.csv
MAP = pathlib.Path(sys.argv[2])       # p.ej. datasets/g2/columns.map.json
DST = pathlib.Path(sys.argv[3])       # p.ej. datasets/g2/paises.csv

# Esquema canónico esperado por la API de paises
CANON = ["nombre", "continente", "capital", "poblacion", "superficie", "codigo"]

def sluggify(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "").strip())

def to_int(val: str) -> int:
    if val is None:
        return 0
    v = str(val).strip().replace(".", "").replace(",", ".")
    try:
        return int(float(v))
    except:
        return 0

m = json.loads(MAP.read_text(encoding="utf-8-sig"))

# Normaliza headers: lower + elimina espacios duplicados
def norm(s): return sluggify(s).lower()

with SRC.open("r", encoding="utf-8-sig", newline="") as f:
    # Autodetecta el dialecto
    sample = f.read(4096)
    f.seek(0)
    try:
        dialect = csv.Sniffer().sniff(sample)
    except Exception:
        dialect = csv.excel
    reader = csv.reader(f, dialect)
    headers = next(reader)
    hmap = {norm(h): i for i, h in enumerate(headers)}

    out_rows = []
    for row in reader:
        out = {}
        for key in CANON:
            candidates = [norm(c) for c in m.get(key, [])]
            val = ""
            for c in candidates:
                if c in hmap:
                    idx = hmap[c]
                    if idx < len(row):
                        val = str(row[idx]).strip()
                        break
            if key in ("poblacion", "superficie"):
                out[key] = to_int(val)
            else:
                out[key] = sluggify(val)
        out_rows.append(out)

DST.parent.mkdir(parents=True, exist_ok=True)
with DST.open("w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=CANON)
    w.writeheader()
    w.writerows(out_rows)

print(f"[OK] {SRC} -> {DST} ({len(out_rows)} filas)")
