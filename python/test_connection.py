#!/usr/bin/env python3
"""
test_connection.py — Verificación de conexión BigQuery naranja-x-491820
Ejecutar: python3 python/test_connection.py
"""
from google.cloud import bigquery
from google.api_core.exceptions import Forbidden, NotFound

PROJECT = "naranja-x-491820"

def test():
    print(f"\n🔍 Testeando conexión a BigQuery — {PROJECT}\n")
    try:
        client = bigquery.Client(project=PROJECT)
        print(f"  ✅ Auth OK — proyecto: {client.project}")
    except Exception as e:
        print(f"  ❌ Auth FALLÓ: {e}")
        print("\n  → Verificá GOOGLE_APPLICATION_CREDENTIALS")
        return

    # Chequear si los datasets existen
    datasets = ["raw_procurement", "stg_procurement", "mart_procurement", "audit_procurement"]
    print()
    for ds in datasets:
        try:
            client.get_dataset(f"{PROJECT}.{ds}")
            print(f"  ✅ Dataset {ds} — existe")
        except NotFound:
            print(f"  ⚠️  Dataset {ds} — NO existe aún (normal si no corriste el loader)")
        except Forbidden:
            print(f"  ❌ Dataset {ds} — SIN PERMISOS (revisá el rol del Service Account)")

    # Chequear si fact_invoices existe
    print()
    try:
        tbl = client.get_table(f"{PROJECT}.mart_procurement.fact_invoices")
        print(f"  ✅ fact_invoices — {tbl.num_rows:,} filas")
    except NotFound:
        print(f"  ⚠️  fact_invoices — no existe aún (corrés el loader primero)")
    except Exception as e:
        print(f"  ❌ fact_invoices — {e}")

    print("\n  Listo. Si todos los datasets muestran ⚠️ 'NO existe', corré:")
    print("  python3 python/loader.py\n")

if __name__ == "__main__":
    test()
