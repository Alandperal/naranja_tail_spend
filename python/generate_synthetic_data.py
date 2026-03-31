#!/usr/bin/env python3
# =============================================================================
# FILE: generate_synthetic_data.py
# PURPOSE: Generate realistic synthetic CSVs for testing the full pipeline.
#          Intentionally injects split-purchase anomalies and concentration patterns.
# SEED: 42 (deterministic)
# =============================================================================
# pip install pandas numpy faker
# python generate_synthetic_data.py --output ./data/raw/
# =============================================================================

import argparse
import random
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

random.seed(42)
np.random.seed(42)
fake = Faker("es_AR")
fake.seed_instance(42)

# ─── CONFIG ──────────────────────────────────────────────────
N_SUPPLIERS  = 999
N_INVOICES   = 9999
START_DATE   = "2025-01-01"
END_DATE     = "2026-02-28"

RUBROS = ["Hardware", "Consultoría", "Limpieza", "Catering", "Mantenimiento", "Librería"]
RUBRO_WEIGHTS = [0.17, 0.20, 0.17, 0.15, 0.17, 0.14]  # Consultoría slightly more

AREAS = ["Finanzas", "RRHH", "IT", "Operaciones", "Legal", "Marketing", "Logística"]
PROVINCES = ["Buenos Aires", "Córdoba", "Santa Fe", "Mendoza", "Neuquén",
             "Rosario", "San Luis", "Tucumán", "Salta", "Chaco"]

# ─── IUCSC ANOMALY TARGETS ───────────────────────────────────
# Inject 40 supplier-area pairs that will trigger split-purchase alerts
SPLIT_ANOMALY_PAIRS = 40
# Inject 3 areas with extreme concentration (HHI > 2500)
CONCENTRATION_AREAS = {"IT": "PROV-0001", "Legal": "PROV-0002", "Marketing": "PROV-0003"}


def fmt_ars_num(value: float) -> str:
    """Format float as Argentine locale string (dot=thousands, comma=decimal)."""
    s = f"{value:,.2f}"          # e.g. "1,420.31"
    s = s.replace(",", "X").replace(".", ",").replace("X", ".")
    return s                     # → "1.420,31"


def fmt_pct(value: float) -> str:
    return f"{value*100:.1f}%".replace(".", ",")


# ─── 1. PROVEEDORES ──────────────────────────────────────────
def gen_proveedores():
    rows = []
    for i in range(1, N_SUPPLIERS + 1):
        pid  = f"PROV-{i:04d}"
        rubro = np.random.choice(RUBROS, p=RUBRO_WEIGHTS)
        # Force concentration targets to Hardware/Consultoría
        if i in [1, 2, 3]:
            rubro = ["Hardware", "Consultoría", "Catering"][i-1]
        cuit_body = str(random.randint(20000000, 99999999))
        cuit = f"30-{cuit_body}-{random.randint(0,9)}"
        rows.append({
            "id_proveedor": pid,
            "cuit":         cuit,
            "nombre":       f"Empresa {pid}",
            "provincia":    random.choice(PROVINCES),
            "rubro":        rubro,
        })
    return pd.DataFrame(rows)


# ─── 2. FACTURAS ─────────────────────────────────────────────
def gen_facturas(proveedores_df: pd.DataFrame):
    dates = pd.date_range(START_DATE, END_DATE, freq="D")
    area_list = AREAS.copy()

    # Build supplier pool by rubro for dispersion
    sup_by_rubro = proveedores_df.groupby("rubro")["id_proveedor"].apply(list).to_dict()

    rows = []
    fac_ids = random.sample(range(1, 99999), N_INVOICES)
    fac_ids.sort()

    # Track anomaly injection state
    split_pairs_injected = 0
    anomaly_pairs = []
    for area in ["Finanzas", "RRHH", "IT"]:
        for sup_id in list(sup_by_rubro.get("Hardware", []))[:3]:
            anomaly_pairs.append((sup_id, area))

    for idx, fac_num in enumerate(fac_ids):
        fac_id = f"FAC-{fac_num:05d}"
        date   = random.choice(dates)
        area   = random.choice(area_list)

        # Concentration injection: IT always uses PROV-0001
        if area == "IT" and random.random() < 0.65:
            sup_id = "PROV-0001"
        elif area == "Legal" and random.random() < 0.55:
            sup_id = "PROV-0002"
        else:
            # Normal random supplier
            rubro  = random.choices(RUBROS, weights=RUBRO_WEIGHTS)[0]
            pool   = sup_by_rubro.get(rubro, proveedores_df["id_proveedor"].tolist())
            sup_id = random.choice(pool)

        # Normal amount: USD 500 – 18000, skewed below threshold
        if random.random() < 0.85:
            amount = round(random.uniform(500, 14800), 2)
        else:
            amount = round(random.uniform(5000, 20000), 2)

        # SPLIT PURCHASE INJECTION: create clusters of ~3 invoices
        # from same supplier+area within 7 days that sum > 15k
        if split_pairs_injected < SPLIT_ANOMALY_PAIRS and idx % 250 == 0:
            pair = random.choice(anomaly_pairs)
            sup_id = pair[0]
            area   = pair[1]
            # Three invoices of ~5500 USD each → total ~16.5k in same 7-day window
            base_date = date
            for k in range(3):
                sub_amount = round(random.uniform(4800, 5400), 2)
                sub_date   = base_date + pd.Timedelta(days=k * 2)
                sub_date   = min(sub_date, dates[-1])
                rows.append({
                    "id_factura":  f"FAC-SP{split_pairs_injected:03d}{k}",
                    "id_proveedor": sup_id,
                    "monto_usd":   str(sub_amount).replace(".", ","),
                    "area_interna": area,
                    "fecha":        f"{sub_date.day}/{sub_date.month}/{sub_date.year}",
                    "articulos":   f"SKU-{random.randint(1000,9999)}",
                })
            split_pairs_injected += 1
            continue  # skip normal row for this slot

        # Normal row
        rows.append({
            "id_factura":  fac_id,
            "id_proveedor": sup_id,
            "monto_usd":   str(amount).replace(".", ","),
            "area_interna": area,
            "fecha":        f"{date.day}/{date.month}/{date.year}",
            "articulos":   f"SKU-{random.randint(1000,9999)}",
        })

    return pd.DataFrame(rows)


# ─── 3. IPC (static — matches provided sample) ───────────────
IPC_DATA = [
    ("202602","2026-02-28 0:00:00","10714,6255","10714,6255","28/2/2026","1"),
    ("202601","2026-01-31 0:00:00","10413,0309","10714,6255","28/2/2026","1,028963191"),
    ("202512","2025-12-31 0:00:00","10121,3715","10714,6255","28/2/2026","1,058613993"),
    ("202511","2025-11-30 0:00:00","9841,3581", "10714,6255","28/2/2026","1,088734440"),
    ("202510","2025-10-31 0:00:00","9603,8623", "10714,6255","28/2/2026","1,115657968"),
    ("202509","2025-09-30 0:00:00","9384,0922", "10714,6255","28/2/2026","1,141786043"),
    ("202508","2025-08-01 0:00:00","9193,2441", "10714,6255","28/2/2026","1,165489068"),
    ("202507","2025-07-01 0:00:00","9023,9730", "10714,6255","28/2/2026","1,187351237"),
    ("202506","2025-06-01 0:00:00","8855,5681", "10714,6255","28/2/2026","1,209930902"),
    ("202505","2025-05-01 0:00:00","8714,4871", "10714,6255","28/2/2026","1,229518775"),
    ("202504","2025-04-01 0:00:00","8585,6078", "10714,6255","28/2/2026","1,247975187"),
    ("202503","2025-03-01 0:00:00","8353,3158", "10714,6255","28/2/2026","1,282679328"),
    ("202502","2025-02-01 0:00:00","8052,9927", "10714,6255","28/2/2026","1,330514741"),
    ("202501","2025-01-01 0:00:00","7864,1257", "10714,6255","28/2/2026","1,362468748"),
]

def gen_ipc():
    return pd.DataFrame(IPC_DATA, columns=["periodo_ipc","fecha_ipc","ipc","ipc_fecha_max","fecha_ipc_max","coeficiente"])


# ─── 4. TC (static — matches provided sample) ────────────────
TC_DATA = [
    ("1.420,31","202603"),("1.430,00","202602"),("1.472,00","202601"),
    ("1.471,00","202512"),("1.454,00","202511"),("1.456,00","202510"),
    ("1.416,00","202509"),("1.340,00","202508"),("1.279,00","202507"),
    ("1.195,00","202506"),("1.164,00","202505"),("1.138,00","202504"),
    ("1.087,00","202503"),("1.077,00","202502"),("1.061,00","202501"),
]

def gen_tc():
    return pd.DataFrame(TC_DATA, columns=["tipo_cambio","periodo"])


# ─── 5. SAVINGS_PROY (static) ─────────────────────────────────
SAVINGS_DATA = [
    ("Librería","0,8","3,0%","5,0%","2,0%"),
    ("Hardware","0,5","3,0%","4,0%","1,0%"),
    ("Limpieza","0,3","1,0%","2,0%","1,0%"),
    ("Consultoría","0,8","4,0%","5,0%","1,0%"),
    ("Mantenimiento","0,5","3,5%","4,0%","0,5%"),
    ("Catering","0,7","5,0%","6,0%","1,0%"),
]

def gen_savings():
    return pd.DataFrame(SAVINGS_DATA, columns=["rubros","factibilidad","kpi_min","kpi_max","variacion"])


# ─── MAIN ─────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="./data/raw/", help="Output directory for CSVs")
    args = parser.parse_args()

    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)

    print("Generating proveedores.csv ...")
    prov = gen_proveedores()
    prov.to_csv(out / "proveedores.csv", index=False, encoding="utf-8")
    print(f"  → {len(prov):,} rows")

    print("Generating facturas.csv ...")
    fact = gen_facturas(prov)
    fact.to_csv(out / "facturas.csv", index=False, encoding="utf-8")
    print(f"  → {len(fact):,} rows  (incl. {SPLIT_ANOMALY_PAIRS*3} split-purchase injections)")

    print("Generating ipc.csv ...")
    gen_ipc().to_csv(out / "ipc.csv", index=False, encoding="utf-8")

    print("Generating tc.csv ...")
    gen_tc().to_csv(out / "tc.csv", index=False, encoding="utf-8")

    print("Generating savings_proy.csv ...")
    gen_savings().to_csv(out / "savings_proy.csv", index=False, encoding="utf-8")

    print("\n✅ All CSVs generated in:", out.resolve())


if __name__ == "__main__":
    main()
