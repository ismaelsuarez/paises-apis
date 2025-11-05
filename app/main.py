from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List
from pathlib import Path
import csv, json
import os

# Soporta tanto /data (servicio 8000) como /app/data (servicios 8010/8020)
# Verifica en tiempo de ejecución qué path existe
def get_data_dir():
    if Path("/app/data").exists():
        return Path("/app/data")
    return Path("/data")

DATA_DIR = get_data_dir()
# Detectar qué CSV usar según el directorio y archivos disponibles
# - /data (puerto 8000) → busca paises.csv
# - /app/data (puertos 8010/8020) → busca autos.csv o colegios.csv
CSV_PATH = None
CSV_TYPE = None  # "paises", "autos" o "colegios"

# Si estamos en /data (servicio 8000), priorizar paises.csv
if DATA_DIR == Path("/data"):
    search_order = ["paises.csv", "autos.csv", "colegios.csv"]
else:
    # Si estamos en /app/data (servicios 8010/8020), priorizar autos/colegios
    search_order = ["autos.csv", "colegios.csv", "paises.csv"]

for possible_file in search_order:
    candidate = DATA_DIR / possible_file
    if candidate.exists():
        CSV_PATH = candidate
        if "colegios" in possible_file.lower():
            CSV_TYPE = "colegios"
        elif "autos" in possible_file.lower():
            CSV_TYPE = "autos"
        elif "paises" in possible_file.lower():
            CSV_TYPE = "paises"
        break

if CSV_PATH is None:
    # Default según el directorio
    if DATA_DIR == Path("/data"):
        CSV_PATH = DATA_DIR / "paises.csv"
        CSV_TYPE = "paises"
    else:
        CSV_PATH = DATA_DIR / "autos.csv"
        CSV_TYPE = "autos"

JSON_PATH = DATA_DIR / f"{CSV_TYPE}.json"

# Variables de entorno para personalizar el título de la API
if CSV_TYPE == "colegios":
    _default_title = "Colegios API"
    _default_desc = "API de colegios (UTN)."
elif CSV_TYPE == "paises":
    _default_title = "Paises API"
    _default_desc = "API de países (UTN)."
else:
    _default_title = "Autos API"
    _default_desc = "API de autos (UTN)."
APP_NAME = os.getenv("APP_NAME", _default_title)
APP_DESCRIPTION = os.getenv("APP_DESCRIPTION", _default_desc)

app = FastAPI(title=APP_NAME, description=APP_DESCRIPTION, version="1.0.0")

# CORS abierto para que tu app consuma sin problemas
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"]
)

# --------- Modelos ----------
if CSV_TYPE == "colegios":
    class ItemIn(BaseModel):
        Provincia: str
        Colegio: str
        CantidadEstudiantes: int = Field(alias="Cantidad de Estudiantes")
        AñoCreacion: int = Field(alias="Año de Creación")
        
        class Config:
            populate_by_name = True
    
    class Item(ItemIn):
        id: int
    
    # Alias para compatibilidad de endpoints
    ColegioIn = ItemIn
    Colegio = Item
elif CSV_TYPE == "paises":
    class ItemIn(BaseModel):
        nombre: str
        continente: str
        capital: str
        poblacion: int
        superficie: int
        codigo: str
    
    class Item(ItemIn):
        id: int
    
    # Alias para compatibilidad de endpoints
    CountryIn = ItemIn
    Country = Item
else:  # autos
    class ItemIn(BaseModel):
        Marca: str
        Modelo: str
        Año: int
        TipoCombustible: str
        Transmisión: str
    
    class Item(ItemIn):
        id: int
    
    # Alias para compatibilidad de endpoints
    AutoIn = ItemIn
    Auto = Item

# --------- "DB" en memoria con persistencia JSON ----------
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
        # Lee CSV (soporta BOM) y lo pasa a JSON
        with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            # Limpiar encabezados por si vienen con espacios/BOM
            reader.fieldnames = [h.strip().lstrip("\ufeff") for h in reader.fieldnames]
            db = []
            for row in reader:
                # Manejo tolerante de columnas del CSV de autos
                def safe_int(key, default=0):
                    val = row.get(key, default)
                    if val is None or val == "":
                        return default
                    try:
                        return int(float(str(val).replace(".", "").replace(",", ".")))
                    except:
                        return default
                
                def safe_str(key, default=""):
                    val = row.get(key, default)
                    return str(val).strip() if val else default
                
                # Leer campos según el tipo de CSV
                if CSV_TYPE == "colegios":
                    item = {
                        "id": len(db) + 1,
                        "Provincia": safe_str("Provincia", ""),
                        "Colegio": safe_str("Colegio", ""),
                        "Cantidad de Estudiantes": safe_int("Cantidad de Estudiantes", 0),
                        "Año de Creación": safe_int("Año de Creación", 0),
                    }
                    # Validar que tenga datos mínimos
                    if item["Provincia"] and item["Colegio"]:
                        db.append(item)
                elif CSV_TYPE == "paises":
                    item = {
                        "id": len(db) + 1,
                        "nombre": safe_str("nombre", ""),
                        "continente": safe_str("continente", ""),
                        "capital": safe_str("capital", ""),
                        "poblacion": safe_int("poblacion", 0),
                        "superficie": safe_int("superficie", 0),
                        "codigo": safe_str("codigo", ""),
                    }
                    # Validar que tenga datos mínimos
                    if item["nombre"]:
                        db.append(item)
                else:  # autos
                    item = {
                        "id": len(db) + 1,
                        "Marca": safe_str("Marca", ""),
                        "Modelo": safe_str("Modelo", ""),
                        "Año": safe_int("Año", 0),
                        "TipoCombustible": safe_str("TipoCombustible", ""),
                        "Transmisión": safe_str("Transmisión", ""),
                    }
                    # Validar que tenga datos mínimos
                    if item["Marca"] and item["Modelo"]:
                        db.append(item)
        _save()
    else:
        db = []
    _next_id = (max((c.get("id", 0) for c in db), default=0) + 1)

_load()

def _find_index(cid: int) -> int:
    for i, c in enumerate(db):
        if c.get("id") == cid:
            return i
    return -1

# --------- Endpoints ----------
@app.get("/health")
def health():
    return {"status": "ok"}

def list_items(
    q: str | None = None,
    filter_field: str | None = None,
    filter_value: str | None = None,
    sort_by: str | None = None,
    desc: bool = False
):
    """Función genérica para listar items (países, autos o colegios)."""
    items = db.copy()
    if CSV_TYPE == "colegios":
        if q:
            ql = q.lower().strip()
            items = [
                c for c in items 
                if ql in c.get("Provincia", "").lower() or ql in c.get("Colegio", "").lower()
            ]
        if filter_field == "Provincia" and filter_value:
            items = [c for c in items if c.get("Provincia", "").lower() == filter_value.lower()]
        valid_sort = {"Provincia", "Colegio", "Cantidad de Estudiantes", "Año de Creación"}
        if sort_by in valid_sort:
            key = (lambda x: str(x.get(sort_by, "")).lower()) if sort_by in {"Provincia", "Colegio"} else (lambda x: x.get(sort_by, 0))
            items = sorted(items, key=key, reverse=desc)
    elif CSV_TYPE == "paises":
        if q:
            ql = q.lower().strip()
            items = [c for c in items if ql in c.get("nombre", "").lower()]
        if filter_field == "continente" and filter_value:
            items = [c for c in items if c.get("continente", "").lower() == filter_value.lower()]
        valid_sort = {"nombre", "poblacion", "superficie", "continente"}
        if sort_by in valid_sort:
            key = (lambda x: str(x.get(sort_by, "")).lower()) if sort_by in {"nombre", "continente"} else (lambda x: x.get(sort_by, 0))
            items = sorted(items, key=key, reverse=desc)
    else:  # autos
        if q:
            ql = q.lower().strip()
            items = [
                c for c in items 
                if ql in c.get("Marca", "").lower() or ql in c.get("Modelo", "").lower()
            ]
        if filter_field == "TipoCombustible" and filter_value:
            items = [c for c in items if c.get("TipoCombustible", "").lower() == filter_value.lower()]
        valid_sort = {"Marca", "Modelo", "Año", "TipoCombustible", "Transmisión"}
        if sort_by in valid_sort:
            key = (lambda x: str(x.get(sort_by, "")).lower()) if sort_by in {"Marca", "Modelo", "TipoCombustible", "Transmisión"} else (lambda x: x.get(sort_by, 0))
            items = sorted(items, key=key, reverse=desc)
    return items

@app.get("/autos", response_model=List[Item])
def list_autos(
    q: str | None = Query(default=None, description="Buscar por marca o modelo (contains)"),
    TipoCombustible: str | None = Query(default=None, description="Filtrar por tipo de combustible"),
    sort_by: str | None = Query(default=None, description="Marca|Modelo|Año|TipoCombustible|Transmisión"),
    desc: bool = Query(default=False)
):
    return list_items(q=q, filter_field="TipoCombustible", filter_value=TipoCombustible, sort_by=sort_by, desc=desc)

@app.get("/colegios", response_model=List[Item])
def list_colegios(
    q: str | None = Query(default=None, description="Buscar por provincia o colegio (contains)"),
    Provincia: str | None = Query(default=None, description="Filtrar por provincia"),
    sort_by: str | None = Query(default=None, description="Provincia|Colegio|Cantidad de Estudiantes|Año de Creación"),
    desc: bool = Query(default=False)
):
    return list_items(q=q, filter_field="Provincia", filter_value=Provincia, sort_by=sort_by, desc=desc)

@app.get("/autos/{cid}", response_model=Item)
def get_auto(cid: int):
    i = _find_index(cid)
    if i < 0: raise HTTPException(404, "No encontrado")
    return db[i]

@app.post("/autos", response_model=Item, status_code=201)
def create_auto(payload: ItemIn):
    global _next_id
    c = payload.dict()
    c["id"] = _next_id
    _next_id += 1
    db.append(c)
    _save()
    return c

@app.put("/autos/{cid}", response_model=Item)
def replace_auto(cid: int, payload: ItemIn):
    i = _find_index(cid)
    if i < 0: raise HTTPException(404, "No encontrado")
    newc = payload.dict() | {"id": cid}
    db[i] = newc
    _save()
    return newc

@app.patch("/autos/{cid}", response_model=Item)
def update_auto(cid: int, patch: dict):
    i = _find_index(cid)
    if i < 0: raise HTTPException(404, "No encontrado")
    if CSV_TYPE == "colegios":
        allowed = {"Provincia", "Colegio", "Cantidad de Estudiantes", "Año de Creación"}
    elif CSV_TYPE == "paises":
        allowed = {"nombre", "continente", "capital", "poblacion", "superficie", "codigo"}
    else:
        allowed = {"Marca", "Modelo", "Año", "TipoCombustible", "Transmisión"}
    for k in list(patch.keys()):
        if k not in allowed: patch.pop(k, None)
    db[i] |= patch
    _save()
    return db[i]

@app.delete("/autos/{cid}", status_code=204)
def delete_auto(cid: int):
    i = _find_index(cid)
    if i < 0: raise HTTPException(404, "No encontrado")
    db.pop(i)
    _save()
    return

# Endpoints para colegios
@app.get("/colegios/{cid}", response_model=Item)
def get_colegio(cid: int):
    return get_auto(cid)

@app.post("/colegios", response_model=Item, status_code=201)
def create_colegio(payload: ItemIn):
    return create_auto(payload)

@app.put("/colegios/{cid}", response_model=Item)
def replace_colegio(cid: int, payload: ItemIn):
    return replace_auto(cid, payload)

@app.patch("/colegios/{cid}", response_model=Item)
def update_colegio(cid: int, patch: dict):
    return update_auto(cid, patch)

@app.delete("/colegios/{cid}", status_code=204)
def delete_colegio(cid: int):
    return delete_auto(cid)

@app.post("/admin/reload-from-csv")
def reload_from_csv():
    """Vuelve a cargar desde el CSV (reemplaza todo)."""
    if not CSV_PATH.exists():
        raise HTTPException(404, f"No existe {CSV_PATH}")
    JSON_PATH.unlink(missing_ok=True)
    _load()
    return {"ok": True, "count": len(db), "type": CSV_TYPE, "csv": str(CSV_PATH)}

# Mantener compatibilidad con /countries para el servicio 8000 (opcional)
@app.get("/countries")
def list_countries(
    q: str | None = Query(default=None, description="Buscar por nombre (contains)"),
    continente: str | None = Query(default=None, description="Filtrar por continente"),
    sort_by: str | None = Query(default=None, description="nombre|poblacion|superficie|continente"),
    desc: bool = Query(default=False)
):
    """Endpoint para países - usa el esquema original si CSV_TYPE es 'paises'"""
    if CSV_TYPE == "paises":
        return list_items(q=q, filter_field="continente", filter_value=continente, sort_by=sort_by, desc=desc)
    # Si no es paises, redirige a /autos o /colegios según el tipo
    if CSV_TYPE == "colegios":
        return list_colegios()
    return list_autos()
