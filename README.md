# Tail Spend Analytics — Procurement Intelligence Platform

> **Stack:** BigQuery · Looker (LookML) · Python · GitHub  
> **Scope:** Detección de Tail Spend fragmentado, auditoría de compliance y estrategia de sourcing centralizado.

---

## Estructura del Repositorio

```
nar/
├── data/
│   └── raw/                    ← CSVs fuente (proveedores, facturas, ipc, tc, savings_proy)
├── sql/
│   ├── ddl/                    ← DDL: datasets, source tables, staging, marts
│   ├── marts/                  ← Transformaciones core (moneda homogénea, KPIs)
│   ├── audit/                  ← Lógica de compliance (split purchase, HHI)
│   ├── sourcing/               ← Candidatos a acuerdo marco y savings
│   └── validation/             ← Framework de calidad de datos (20 checks)
├── lookml/
│   ├── models/                 ← tail_spend.model.lkml
│   └── views/                  ← fact_invoices, dim_*, audit_views
├── python/
│   ├── load_csvs_to_bigquery.py ← Pipeline loader (raw → staging → mart → audit)
│   └── generate_synthetic_data.py ← Generador de datos sintéticos con anomalías
└── docs/
    └── solucion_tecnica.md     ← Documento técnico completo en español
```

---

## Quick Start

### 1. Instalar dependencias

```bash
pip install google-cloud-bigquery pandas pyarrow faker numpy
```

### 2. Autenticar con GCP

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

### 3. Cargar datos reales al pipeline

```bash
python python/load_csvs_to_bigquery.py --project YOUR_PROJECT_ID
```

Esto ejecuta en orden:
1. Crea los 4 datasets en BigQuery
2. Carga los 5 CSVs en `raw_procurement`
3. Ejecuta el staging (parseo locale, tipos, deduplicación)
4. Construye el mart layer (fact, dims, moneda homogénea)
5. Ejecuta auditoría (split purchase, concentración HHI)
6. Genera candidatos a acuerdo marco

### 4. (Opcional) Generar datos sintéticos de prueba

```bash
python python/generate_synthetic_data.py --output ./data/raw/
```

---

## Capas del Modelo de Datos

| Layer | Dataset BQ | Propósito |
|-------|-----------|-----------|
| **Raw** | `raw_procurement` | Tablas fuente, strings sin parsear |
| **Staging** | `stg_procurement` | Tipos correctos, locale normalizado, FK validado |
| **Mart** | `mart_procurement` | Modelo dimensional, moneda homogénea, KPIs |
| **Audit** | `audit_procurement` | Alertas split purchase, HHI, favoritismo |

---

## Metodología de Moneda Homogénea

**Fórmula (3 pasos):**
1. `monto_ars_nominal = monto_usd × tc_periodo` — Re-expresión en ARS al TC vigente
2. `monto_ars_constante = monto_ars_nominal × (ipc_base / ipc_periodo)` — Deflactado con IPC
3. `monto_homogeneo_usd = monto_ars_constante / tc_base` — Vuelta a USD constante

**Período base:** Febrero 2026 (ipc = 10.714,63 · tc = 1.430 ARS/USD)

> El umbral de USD 15.000 para compra directa se evalúa siempre en `monto_usd` nominal.

---

## Lógica de Auditoría

### Split Purchase (Desdoblamiento)
- Alerta cuando: mismo proveedor + misma área > USD 15.000 acumulado en ventana móvil de 7 días
- Severidades: MEDIO (>15k), ALTO (>30k), CRÍTICO (>50k)
- Tabla resultado: `audit_procurement.split_purchase_alerts`

### Concentración (HHI)
- HHI = Σ(share_proveedor²) × 10.000
- <1.500 = Competitivo | 1.500-2.500 = Moderado | >2.500 = Concentrado
- Tabla resultado: `audit_procurement.hhi_by_area`

---

## Estrategia de Sourcing

**Criterios de elegibilidad:**
- Frecuencia alta de facturas (peso 40%)
- >20 proveedores distintos (peso 30%)
- Savings potenciales estimados (peso 30%)

**Fórmula savings:**
- `base_savings = gasto_homogeneo × factibilidad × ((kpi_min + kpi_max) / 2)`

---

## Validaciones de Calidad

Ejecutar `sql/validation/01_data_quality_checks.sql` — contiene 20 checks:
- PK uniqueness (5 tablas)
- FK integrity (2 relaciones)
- Null checks, domain checks, date parse checks
- Cobertura IPC/TC por período
- Sanidad de moneda homogénea
- Consistencia savings_proy

---

## Looker

**Archivos generados:**
- `lookml/models/tail_spend.model.lkml` — 5 explores
- `lookml/views/fact_invoices.view.lkml` — Vista de facturas (medidas homogéneas)
- `lookml/views/dimensions.view.lkml` — dim_suppliers, dim_categories, dim_areas, dim_time
- `lookml/views/audit_views.view.lkml` — Alertas, HHI, concentración, sourcing

**Reemplaza `<project_id>` por tu GCP Project ID en todos los archivos LookML.**

---

## Variables de Entorno Requeridas

| Variable | Valor |
|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Path al service account JSON |
| `GCP_PROJECT_ID` | ID del proyecto GCP |

---

## PKs y FKs del Modelo

| Tabla | PK | FK |
|-------|----|----|
| `proveedores` | `id_proveedor` | — |
| `facturas` | `id_factura` | `id_proveedor → proveedores.id_proveedor` |
| `ipc` | `periodo_ipc` | — |
| `tc` | `periodo` | — |
| `savings_proy` | `rubros` | `rubros ~ proveedores.rubro` |

---

## Convenciones de Naming

- **Tablas raw:** snake_case, sin prefijo (ej: `proveedores`)
- **Tablas staging:** prefijo `stg_` (ej: `stg_facturas`)
- **Tablas mart:** prefijo `dim_` / `fact_` / `mart_` (ej: `fact_invoices`)
- **Tablas audit:** sin prefijo, nombre descriptivo (ej: `split_purchase_alerts`)
- **Campos:** snake_case en inglés para SQL/LookML, español en Looker labels
- **Períodos:** `INT64` formato `YYYYMM`

---

*Documento técnico completo en español: [`docs/solucion_tecnica.md`](docs/solucion_tecnica.md)*
