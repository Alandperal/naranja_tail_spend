#!/usr/bin/env python3
# =============================================================================
# FILE: load_csvs_to_bigquery.py
# PROJECT: Tail Spend Analytics — Procurement Intelligence Platform
# PURPOSE: Load the 5 source CSV files into BigQuery raw_procurement dataset
#          with all columns as STRING to preserve raw locale formatting.
#          Then trigger the staging transformation via BigQuery queries.
# =============================================================================
# DEPENDENCIES:
#   pip install google-cloud-bigquery pandas pyarrow
#
# USAGE:
#   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
#   python load_csvs_to_bigquery.py --project YOUR_PROJECT_ID
#
# NOTE: Run from the repository root directory.
#       Assumes CSV files are in ./data/raw/
# =============================================================================

import argparse
import os
import sys
from pathlib import Path

from google.cloud import bigquery
from google.cloud.bigquery import LoadJobConfig, SchemaField

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
RAW_DATA_DIR   = Path(__file__).parent.parent / "data" / "raw"
DATASET_RAW    = "raw_procurement"
DATASET_STG    = "stg_procurement"
DATASET_MART   = "mart_procurement"
DATASET_AUDIT  = "audit_procurement"

# All fields loaded as STRING to preserve locale formatting.
# Type casting happens in the staging SQL layer.
TABLE_SCHEMAS = {
    "proveedores": [
        SchemaField("id_proveedor", "STRING"),
        SchemaField("cuit",         "STRING"),
        SchemaField("nombre",       "STRING"),
        SchemaField("provincia",    "STRING"),
        SchemaField("rubro",        "STRING"),
    ],
    "facturas": [
        SchemaField("id_factura",   "STRING"),
        SchemaField("id_proveedor", "STRING"),
        SchemaField("monto_usd",    "STRING"),
        SchemaField("area_interna", "STRING"),
        SchemaField("fecha",        "STRING"),
        SchemaField("articulos",    "STRING"),
    ],
    "ipc": [
        SchemaField("periodo_ipc",   "STRING"),
        SchemaField("fecha_ipc",     "STRING"),
        SchemaField("ipc",           "STRING"),
        SchemaField("ipc_fecha_max", "STRING"),
        SchemaField("fecha_ipc_max", "STRING"),
        SchemaField("coeficiente",   "STRING"),
    ],
    "tc": [
        SchemaField("tipo_cambio", "STRING"),
        SchemaField("periodo",     "STRING"),
    ],
    "savings_proy": [
        SchemaField("rubros",       "STRING"),
        SchemaField("factibilidad", "STRING"),
        SchemaField("kpi_min",      "STRING"),
        SchemaField("kpi_max",      "STRING"),
        SchemaField("variacion",    "STRING"),
    ],
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def get_client(project: str) -> bigquery.Client:
    return bigquery.Client(project=project)


def ensure_dataset(client: bigquery.Client, project: str, dataset_id: str, description: str):
    """Create dataset if it doesn't exist."""
    full_id = f"{project}.{dataset_id}"
    try:
        client.get_dataset(full_id)
        print(f"  [OK] Dataset {full_id} already exists.")
    except Exception:
        dataset = bigquery.Dataset(full_id)
        dataset.location = "US"
        dataset.description = description
        client.create_dataset(dataset)
        print(f"  [CREATED] Dataset {full_id} created.")


def load_csv(client: bigquery.Client, project: str, table_name: str, csv_path: Path):
    """Load a single CSV into raw_procurement dataset with STRING schema."""
    table_id = f"{project}.{DATASET_RAW}.{table_name}"
    schema   = TABLE_SCHEMAS[table_name]

    job_config = LoadJobConfig(
        schema                = schema,
        skip_leading_rows     = 1,         # Skip CSV header
        source_format         = bigquery.SourceFormat.CSV,
        write_disposition     = bigquery.WriteDisposition.WRITE_TRUNCATE,
        allow_quoted_newlines = True,
        allow_jagged_rows     = False,
        encoding              = "UTF-8",
    )

    with open(csv_path, "rb") as f:
        job = client.load_table_from_file(f, table_id, job_config=job_config)

    print(f"  Loading {csv_path.name} → {table_id} ...", end="", flush=True)
    job.result()  # Wait for completion
    table = client.get_table(table_id)
    print(f" {table.num_rows:,} rows loaded.")


def run_sql_file(client: bigquery.Client, sql_path: Path, project: str):
    """Execute a SQL file, replacing <project_id> placeholder."""
    sql = sql_path.read_text(encoding="utf-8")
    sql = sql.replace("<project_id>", project)

    # Split on semicolons and run each statement
    statements = [s.strip() for s in sql.split(";") if s.strip()]
    for i, stmt in enumerate(statements, 1):
        if not stmt or stmt.startswith("--"):
            continue
        print(f"  Running statement {i}/{len(statements)} ...", end="", flush=True)
        try:
            job = client.query(stmt)
            job.result()
            print(" OK")
        except Exception as e:
            print(f" ERROR: {e}")
            raise


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Load procurement CSVs to BigQuery and run staging transformations."
    )
    parser.add_argument("--project", required=True, help="GCP Project ID")
    parser.add_argument(
        "--skip-staging", action="store_true",
        help="Skip staging SQL execution (load raw only)"
    )
    args = parser.parse_args()

    project = args.project
    client  = get_client(project)

    print("\n=== STEP 1: Create Datasets ===")
    ensure_dataset(client, project, DATASET_RAW,   "RAW: canonical source tables from CSV")
    ensure_dataset(client, project, DATASET_STG,   "STG: parsed, typed, deduplicated")
    ensure_dataset(client, project, DATASET_MART,  "MART: dimensional model and KPI marts")
    ensure_dataset(client, project, DATASET_AUDIT, "AUDIT: compliance and anomaly outputs")

    print("\n=== STEP 2: Load CSV Files → raw_procurement ===")
    for table_name in TABLE_SCHEMAS.keys():
        csv_path = RAW_DATA_DIR / f"{table_name}.csv"
        if not csv_path.exists():
            print(f"  [SKIP] {csv_path} not found.")
            continue
        load_csv(client, project, table_name, csv_path)

    if args.skip_staging:
        print("\n[INFO] --skip-staging flag set. Stopping after raw load.")
        return

    print("\n=== STEP 3: Run Staging Transformations ===")
    sql_base = Path(__file__).parent.parent / "sql"

    staging_files = [
        sql_base / "ddl" / "03_staging_tables.sql",
    ]
    for sql_file in staging_files:
        if sql_file.exists():
            print(f"\n  Running: {sql_file.name}")
            run_sql_file(client, sql_file, project)

    print("\n=== STEP 4: Build Mart Layer ===")
    mart_files = [
        sql_base / "ddl" / "04_mart_tables.sql",
    ]
    for sql_file in mart_files:
        if sql_file.exists():
            print(f"\n  Running: {sql_file.name}")
            run_sql_file(client, sql_file, project)

    print("\n=== STEP 5: Run Audit Layer ===")
    audit_files = [
        sql_base / "audit" / "01_split_purchase_alerts.sql",
        sql_base / "audit" / "02_concentration_analysis.sql",
    ]
    for sql_file in audit_files:
        if sql_file.exists():
            print(f"\n  Running: {sql_file.name}")
            run_sql_file(client, sql_file, project)

    print("\n=== STEP 6: Build Sourcing Candidates ===")
    sourcing_files = [
        sql_base / "sourcing" / "01_sourcing_candidates.sql",
    ]
    for sql_file in sourcing_files:
        if sql_file.exists():
            print(f"\n  Running: {sql_file.name}")
            run_sql_file(client, sql_file, project)

    print("\n✅ Pipeline complete. All layers loaded and transformed.")
    print(f"\nDatasets available in project: {project}")
    print(f"  • {project}.{DATASET_RAW}   → source tables")
    print(f"  • {project}.{DATASET_STG}   → parsed staging")
    print(f"  • {project}.{DATASET_MART}  → analytics mart")
    print(f"  • {project}.{DATASET_AUDIT} → compliance outputs")


if __name__ == "__main__":
    main()
