from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from pathlib import Path
import csv, json

DATA_DIR = Path("/data")
CSV_PATH = DATA_DIR / "paises.csv"
JSON_PATH = DATA_DIR / "paises.json"

app = FastAPI(title="Paises API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class CountryIn(BaseModel):
    nombre: str
    poblacion: int
    superficie: int
    continente: str
    flag_emoji: Optional[str] = ""

class Country(CountryIn):
    id: int

db: list[dict] = []
_next_id: int = 1

def _save():
    JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(db, ensure_ascii=False, indent=2), encoding="utf-8")

def _load():
    global db, _next_id
    if JSON_PATH.exists():
        db = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    elif CSV_PATH.exists():
        with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            reader.fieldnames = [h.strip().lstrip("\ufeff") for h in reader.fieldnames]
            db = []
            for row in reader:
                db.append({
                    "id": len(db) + 1,
                    "nombre": row["nombre"].strip(),
                    "poblacion": int(float(row["poblacion"])),
                    "superficie": int(float(row["superficie"])),
                    "continente": row["continente"].strip(),
                    "flag_emoji": row.get("flag_emoji", "").strip()
                })
        _save()
    else:
        db = []
    _next_id = (max((c["id"] for c in db), default=0) + 1)

_load()

def _find_index(cid: int) -> int:
    for i, c in enumerate(db):
        if c["id"] == cid:
            return i
    return -1

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/countries", response_model=List[Country])
def list_countries(
    q: str | None = Query(default=None, description="Buscar por nombre (contains)"),
    continente: str | None = Query(default=None),
    sort_by: str | None = Query(default=None, description="nombre|poblacion|superficie|continente"),
    desc: bool = Query(default=False)
):
    items = db
    if q:
        ql = q.lower().strip()
        items = [c for c in items if ql in c["nombre"].lower()]
    if continente:
        items = [c for c in items if c["continente"].lower() == continente.lower()]
    if sort_by in {"nombre", "poblacion", "superficie", "continente"}:
        key = (lambda x: x[sort_by].lower()) if sort_by in {"nombre", "continente"} else (lambda x: x[sort_by])
        items = sorted(items, key=key, reverse=desc)
    return items

@app.get("/countries/{cid}", response_model=Country)
def get_country(cid: int):
    i = _find_index(cid)
    if i < 0:
        raise HTTPException(404, "No encontrado")
    return db[i]

@app.post("/countries", response_model=Country, status_code=201)
def create_country(payload: CountryIn):
    global _next_id
    c = payload.dict()
    c["id"] = _next_id
    _next_id += 1
    db.append(c)
    _save()
    return c

@app.put("/countries/{cid}", response_model=Country)
def replace_country(cid: int, payload: CountryIn):
    i = _find_index(cid)
    if i < 0:
        raise HTTPException(404, "No encontrado")
    newc = payload.dict() | {"id": cid}
    db[i] = newc
    _save()
    return newc

@app.patch("/countries/{cid}", response_model=Country)
def update_country(cid: int, patch: dict):
    i = _find_index(cid)
    if i < 0:
        raise HTTPException(404, "No encontrado")
    allowed = {"nombre","poblacion","superficie","continente","flag_emoji"}
    for k in list(patch.keys()):
        if k not in allowed:
            patch.pop(k, None)
    db[i] |= patch
    _save()
    return db[i]

@app.delete("/countries/{cid}", status_code=204)
def delete_country(cid: int):
    i = _find_index(cid)
    if i < 0:
        raise HTTPException(404, "No encontrado")
    db.pop(i)
    _save()
    return

@app.post("/admin/reload-from-csv")
def reload_from_csv():
    if not CSV_PATH.exists():
        raise HTTPException(404, "No existe /data/paises.csv")
    JSON_PATH.unlink(missing_ok=True)
    _load()
    return {"ok": True, "count": len(db)}
