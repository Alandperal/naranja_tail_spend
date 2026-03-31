#!/usr/bin/env python3
"""
loader.py — Tail Spend Analytics | Proyecto: naranja-x-491820
=======================================================
Pipeline completo de ingesta y transformación:
  1. Crea los 4 datasets en BigQuery (idempotente)
  2. Carga los 5 CSVs → raw_procurement (esquema 100% STRING)
  3. Ejecuta staging SQL  → stg_procurement
  4. Ejecuta mart SQL     → mart_procurement
  5. Ejecuta audit SQL    → audit_procurement
  6. Ejecuta sourcing SQL → mart_procurement.sourcing_candidates

USO:
  pip install google-cloud-bigquery
  export GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/service-account.json
  python python/loader.py

ESTRUCTURA ESPERADA:
  nar/
  ├── data/raw/        ← proveedores.csv, facturas.csv, ipc.csv, tc.csv, savings_proy.csv
  ├── sql/             ← archivos SQL del pipeline
  └── python/loader.py ← este archivo
"""

import os
import sys
import time
from pathlib import Path

from google.cloud import bigquery
from google.cloud.bigquery import SchemaField, LoadJobConfig, SourceFormat, WriteDisposition

# ─────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────
PROJECT_ID   = "naranja-x-491820"
LOCATION     = "US"
RAW_DATA_DIR = Path(__file__).parent.parent / "data" / "raw"
SQL_DIR      = Path(__file__).parent.parent / "sql"

DATASETS = {
    "raw_procurement":   "Capa RAW — tablas fuente con esquema STRING sin parsear.",
    "stg_procurement":   "Capa Staging — tipos correctos, locale normalizado, FK validado.",
    "mart_procurement":  "Capa Mart — modelo dimensional, moneda homogénea, KPIs.",
    "audit_procurement": "Capa Audit — alertas compliance (split purchase, HHI, favoritism).",
}

# ─────────────────────────────────────────────────────────────
# ESQUEMAS RAW — todas las columnas como STRING
# Evita errores de locale (coma decimal, puntos de miles, fechas dd/m/yyyy)
# El parseo se hace 100% en la capa de staging (SQL BigQuery).
# ─────────────────────────────────────────────────────────────
RAW_SCHEMAS = {
    "proveedores": [
        SchemaField("id_proveedor", "STRING", description="PK — PROV-NNNN"),
        SchemaField("cuit",         "STRING", description="CUIT del proveedor. Formato XX-XXXXXXXX-X"),
        SchemaField("nombre",       "STRING", description="Razón social del proveedor"),
        SchemaField("provincia",    "STRING", description="Provincia de registro"),
        SchemaField("rubro",        "STRING", description="Categoría de negocio. 6 valores canónicos."),
    ],
    "facturas": [
        SchemaField("id_factura",   "STRING", description="PK — FAC-NNNNN"),
        SchemaField("id_proveedor", "STRING", description="FK → proveedores.id_proveedor"),
        SchemaField("monto_usd",    "STRING", description="Importe en USD. Comma decimal: '7345,04'"),
        SchemaField("area_interna", "STRING", description="Área interna compradora"),
        SchemaField("fecha",        "STRING", description="Fecha de factura. Formato dd/m/yyyy"),
        SchemaField("articulos",    "STRING", description="SKU(s) del ítem facturado"),
    ],
    "ipc": [
        SchemaField("periodo_ipc",   "STRING", description="PK — YYYYMM"),
        SchemaField("fecha_ipc",     "STRING", description="Fecha del período IPC. 'YYYY-MM-DD H:MM:SS'"),
        SchemaField("ipc",           "STRING", description="Índice IPC del período. Comma decimal."),
        SchemaField("ipc_fecha_max", "STRING", description="IPC en el período base (ref). Comma decimal."),
        SchemaField("fecha_ipc_max", "STRING", description="Fecha del período base. dd/m/yyyy"),
        SchemaField("coeficiente",   "STRING", description="Raw ambiguo — recomputado en staging como ipc_max/ipc"),
    ],
    "tc": [
        SchemaField("tipo_cambio", "STRING", description="TC ARS/USD. Mezcla formatos europeos."),
        SchemaField("periodo",     "STRING", description="PK — YYYYMM"),
    ],
    "savings_proy": [
        SchemaField("rubros",       "STRING", description="PK — Categoría de sourcing"),
        SchemaField("factibilidad", "STRING", description="Coeficiente de factibilidad. Comma decimal."),
        SchemaField("kpi_min",      "STRING", description="KPI mínimo de ahorro. '3,0%'"),
        SchemaField("kpi_max",      "STRING", description="KPI máximo de ahorro. '5,0%'"),
        SchemaField("variacion",    "STRING", description="Spread KPI (max-min). '2,0%'"),
    ],
}

# ─────────────────────────────────────────────────────────────
# PIPELINE SQL — orden de ejecución
# ─────────────────────────────────────────────────────────────
SQL_PIPELINE = [
    ("STAGING",  SQL_DIR / "ddl"        / "03_staging_tables.sql"),
    ("MART",     SQL_DIR / "ddl"        / "04_mart_tables.sql"),
    ("HOMOG",    SQL_DIR / "marts"      / "01_homogeneous_currency.sql"),
    ("AUDIT-SP", SQL_DIR / "audit"      / "01_split_purchase_alerts.sql"),
    ("AUDIT-HHI",SQL_DIR / "audit"      / "02_concentration_analysis.sql"),
    ("SOURCING", SQL_DIR / "sourcing"   / "01_sourcing_candidates.sql"),
]


# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────

def log(msg: str, level: str = "INFO"):
    prefix = {"INFO": "  ✓", "WARN": "  ⚠", "ERR": "  ✗", "HEAD": "\n══"}
    print(f"{prefix.get(level, '  ')} {msg}", flush=True)


def get_client() -> bigquery.Client:
    return bigquery.Client(project=PROJECT_ID)


def ensure_datasets(client: bigquery.Client):
    log("Creando datasets (idempotente)...", "HEAD")
    for ds_id, description in DATASETS.items():
        full_id = f"{PROJECT_ID}.{ds_id}"
        try:
            client.get_dataset(full_id)
            log(f"{ds_id} — ya existe, sin cambios.")
        except Exception:
            ds = bigquery.Dataset(full_id)
            ds.location    = LOCATION
            ds.description = description
            client.create_dataset(ds)
            log(f"{ds_id} — creado correctamente.")


def load_csv_to_raw(client: bigquery.Client, table_name: str):
    csv_path = RAW_DATA_DIR / f"{table_name}.csv"
    if not csv_path.exists():
        log(f"{table_name}.csv no encontrado en {RAW_DATA_DIR}", "WARN")
        return

    table_id = f"{PROJECT_ID}.raw_procurement.{table_name}"
    schema   = RAW_SCHEMAS[table_name]

    config = LoadJobConfig(
        schema                = schema,
        skip_leading_rows     = 1,
        source_format         = SourceFormat.CSV,
        write_disposition     = WriteDisposition.WRITE_TRUNCATE,
        allow_quoted_newlines = True,
        allow_jagged_rows     = False,
        encoding              = "UTF-8",
        field_delimiter       = ",",
    )

    t0 = time.time()
    with open(csv_path, "rb") as f:
        job = client.load_table_from_file(f, table_id, job_config=config)

    print(f"  → Cargando {table_name}.csv ... ", end="", flush=True)
    job.result()  # espera finalización
    table  = client.get_table(table_id)
    elapsed = time.time() - t0
    print(f"{table.num_rows:,} filas en {elapsed:.1f}s")


def run_sql_file(client: bigquery.Client, label: str, sql_path: Path):
    if not sql_path.exists():
        log(f"[{label}] Archivo no encontrado: {sql_path}", "WARN")
        return

    raw_sql = sql_path.read_text(encoding="utf-8")

    # Divide por ';' y para cada chunk:
    #   1. Elimina líneas que son sólo comentarios (--)
    #   2. Sólo ejecuta si queda contenido SQL real
    raw_chunks = raw_sql.split(";")
    statements = []
    for chunk in raw_chunks:
        clean = "\n".join(
            line for line in chunk.splitlines()
            if line.strip() and not line.strip().startswith("--")
        ).strip()
        if clean:
            statements.append(clean)

    log(f"[{label}] Ejecutando {len(statements)} statement(s)...", "HEAD")
    for i, clean in enumerate(statements, 1):
        print(f"  [{i}/{len(statements)}] ", end="", flush=True)
        t0 = time.time()
        try:
            job = client.query(clean)
            job.result()
            elapsed = time.time() - t0
            print(f"OK ({elapsed:.1f}s)")
        except Exception as e:
            print(f"ERROR")
            log(f"Statement {i} falló: {str(e)[:300]}", "ERR")
            continue


def run_validation(client: bigquery.Client):
    """Ejecuta un subset de checks críticos post-pipeline."""
    log("Validaciones post-pipeline...", "HEAD")

    checks = {
        "PK duplicados facturas": """
            SELECT COUNT(*) AS dups FROM (
              SELECT id_factura, COUNT(*) c
              FROM `naranja-x-491820.stg_procurement.stg_facturas`
              GROUP BY id_factura HAVING c > 1
            )""",
        "FK huérfanas facturas": """
            SELECT COUNT(*) AS orphans
            FROM `naranja-x-491820.stg_procurement.stg_facturas` f
            LEFT JOIN `naranja-x-491820.stg_procurement.stg_proveedores` p
              ON f.id_proveedor = p.id_proveedor
            WHERE p.id_proveedor IS NULL""",
        "Fechas no parseadas": """
            SELECT COUNTIF(fecha_parsed IS NULL) AS failed
            FROM `naranja-x-491820.stg_procurement.stg_facturas`""",
        "Filas fact_invoices": """
            SELECT COUNT(*) AS total
            FROM `naranja-x-491820.mart_procurement.fact_invoices`""",
        "Alertas split purchase": """
            SELECT COUNT(*) AS alerts
            FROM `naranja-x-491820.audit_procurement.split_purchase_alerts`""",
    }

    all_ok = True
    for check_name, query in checks.items():
        try:
            result = list(client.query(query).result())[0]
            val    = list(result.values())[0]
            if "duplicados" in check_name or "huérfanas" in check_name or "no parseadas" in check_name:
                status = "✓ OK" if val == 0 else f"⚠ ATENCIÓN: {val}"
                if val > 0:
                    all_ok = False
            else:
                status = f"✓ {val:,}"
            print(f"  {check_name:35s} → {status}")
        except Exception as e:
            print(f"  {check_name:35s} → ERROR: {str(e)[:80]}")
            all_ok = False

    return all_ok


# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  TAIL SPEND ANALYTICS — PIPELINE DE INGESTA")
    print(f"  Proyecto: {PROJECT_ID}")
    print("=" * 60)

    client = get_client()

    # ── 1. Datasets ───────────────────────────────────────────
    ensure_datasets(client)

    # ── 2. Carga RAW ─────────────────────────────────────────
    log("Cargando CSVs → raw_procurement...", "HEAD")
    for table_name in RAW_SCHEMAS.keys():
        load_csv_to_raw(client, table_name)

    # ── 3. Transformaciones SQL ───────────────────────────────
    for label, sql_path in SQL_PIPELINE:
        run_sql_file(client, label, sql_path)

    # ── 4. Validaciones ───────────────────────────────────────
    all_ok = run_validation(client)

    # ── Resumen final ─────────────────────────────────────────
    print("\n" + "=" * 60)
    if all_ok:
        print("  ✅ Pipeline completado sin errores.")
    else:
        print("  ⚠️  Pipeline completado con advertencias. Revisar log.")
    print("=" * 60)
    print(f"\n  Datasets disponibles en: {PROJECT_ID}")
    for ds in DATASETS:
        print(f"    • {PROJECT_ID}.{ds}")
    print()


if __name__ == "__main__":
    main()
