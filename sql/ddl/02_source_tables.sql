-- =============================================================================
-- FILE: 02_source_tables.sql
-- PROJECT: Tail Spend Analytics — Procurement Intelligence Platform
-- LAYER: raw_procurement (Source / Canonical Schema)
-- =============================================================================
-- DESCRIPTION:
--   Creates the five canonical source tables exactly as defined in the spec.
--   ALL column names and table names are lowercase snake_case.
--   PK/FK relationships are documented as comments (BigQuery does not enforce them).
--   Locale-formatted strings (monto_usd, ipc, coeficiente, etc.) are stored
--   as STRING in raw layer to preserve fidelity before parsing.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: proveedores
-- Grain: one row per supplier
-- PK: id_proveedor (STRING, pattern PROV-NNNN)
-- Candidate Key: cuit (assumed unique, validated in stg layer)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.raw_procurement.proveedores` (
  id_proveedor  STRING    NOT NULL  OPTIONS(description = "PK — Surrogate supplier identifier. Pattern: PROV-NNNN."),
  cuit          STRING              OPTIONS(description = "Candidate key — Argentine tax ID. Format: XX-XXXXXXXX-X. Uniqueness validated in staging."),
  nombre        STRING              OPTIONS(description = "Supplier legal name."),
  provincia     STRING              OPTIONS(description = "Argentine province of registration."),
  rubro         STRING              OPTIONS(description = "Business category assigned to supplier. Used for sourcing strategy. Values: Hardware, Consultoría, Limpieza, Catering, Mantenimiento, Librería.")
)
OPTIONS (
  description = "RAW source: suppliers master table. PK=id_proveedor. No transformations applied.",
  require_partition_filter = false
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: facturas
-- Grain: one row per invoice
-- PK: id_factura (STRING, pattern FAC-NNNNN)
-- FK: id_proveedor -> proveedores.id_proveedor
-- PARSING NOTES:
--   monto_usd: stored as STRING because source uses comma decimal (e.g. "7345,04")
--   fecha: stored as STRING because source uses dd/m/yyyy format
--   articulos: stored as STRING; assumption = single SKU per invoice row.
--              If multi-SKU pipe-delimited, parsing is deferred to stg layer.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.raw_procurement.facturas` (
  id_factura    STRING    NOT NULL  OPTIONS(description = "PK — Invoice identifier. Pattern: FAC-NNNNN."),
  id_proveedor  STRING              OPTIONS(description = "FK -> proveedores.id_proveedor. Supplier reference."),
  monto_usd     STRING              OPTIONS(description = "Invoice amount in USD. Raw string: may use comma as decimal separator (e.g. '7345,04')."),
  area_interna  STRING              OPTIONS(description = "Internal company area/department that generated the purchase."),
  fecha         STRING              OPTIONS(description = "Invoice date. Raw string: dd/m/yyyy or dd/mm/yyyy format."),
  articulos     STRING              OPTIONS(description = "SKU or item reference. Assumption: single SKU per row. Multi-SKU pipe-delimited is handled in staging.")
)
OPTIONS (
  description   = "RAW source: invoices/purchases table. PK=id_factura. FK=id_proveedor->proveedores. monto_usd and fecha stored as strings pending locale normalization.",
  require_partition_filter = false
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: ipc
-- Grain: one row per month (period)
-- PK: periodo_ipc (INT64, format YYYYMM)
-- PARSING NOTES:
--   ipc, ipc_fecha_max: comma decimal separator strings
--   coeficiente: CRITICAL AMBIGUITY — raw values appear as "1.028.963.191"
--     Interpretation: this is a European-style thousands separator number.
--     "1.028.963.191" is interpreted as 1028963191? That cannot be right for a
--     ratio coefficient. DECISION: coeficiente = ipc_fecha_max / ipc (computed
--     in staging). The raw string column is preserved for audit. See stg layer.
--   fecha_ipc: stored as STRING (format: "YYYY-MM-DD H:MM:SS")
--   fecha_ipc_max: stored as STRING (format: dd/m/yyyy)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.raw_procurement.ipc` (
  periodo_ipc    STRING    NOT NULL  OPTIONS(description = "PK — Period identifier. Format YYYYMM as string in raw layer."),
  fecha_ipc      STRING              OPTIONS(description = "Date of this IPC measurement. Format: YYYY-MM-DD H:MM:SS."),
  ipc            STRING              OPTIONS(description = "IPC index value for this period. Comma decimal. E.g. '10413,0309'."),
  ipc_fecha_max  STRING              OPTIONS(description = "IPC index value at reference date (deflation base). Comma decimal."),
  fecha_ipc_max  STRING              OPTIONS(description = "Reference date for IPC max. Format: dd/m/yyyy."),
  coeficiente    STRING              OPTIONS(description = "Deflation coefficient as raw string. AMBIGUOUS: interpreted as ipc_fecha_max/ipc ratio, recomputed in staging. Raw preserved here.")
)
OPTIONS (
  description = "RAW source: IPC (CPI) inflation index table. PK=periodo_ipc. coeficiente is ambiguous and recomputed in staging as ipc_fecha_max/ipc.",
  require_partition_filter = false
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: tc
-- Grain: one row per month (period)
-- PK: periodo (INT64, format YYYYMM)
-- PARSING NOTES:
--   tipo_cambio: may use European notation "1.420,31" = 1420.31 ARS/USD
--   Some rows appear clean (e.g. "1430") without separators.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.raw_procurement.tc` (
  tipo_cambio  STRING    NOT NULL  OPTIONS(description = "Exchange rate ARS/USD for this period. Raw string — may use European thousands/decimal format."),
  periodo      STRING    NOT NULL  OPTIONS(description = "PK — Period identifier. Format YYYYMM as string.")
)
OPTIONS (
  description = "RAW source: exchange rate table (ARS/USD). PK=periodo. tipo_cambio stored as string pending locale normalization.",
  require_partition_filter = false
);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE: savings_proy
-- Grain: one row per sourcing category (rubro)
-- PK / Candidate PK: rubros
-- PARSING NOTES:
--   factibilidad: comma decimal string "0,8" → 0.8 NUMERIC
--   kpi_min, kpi_max, variacion: percentage strings "3,0%" → 0.03 NUMERIC
--   Convention chosen: store as decimal rates (0.03, not 3).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.raw_procurement.savings_proy` (
  rubros        STRING    NOT NULL  OPTIONS(description = "PK — Sourcing category name. Must match normalized rubro from proveedores."),
  factibilidad  STRING              OPTIONS(description = "Execution feasibility coefficient as raw string. Comma decimal. 1.0=assured, 0.7-0.9=high prob, 0.3-0.6=medium, 0.0=blocked."),
  kpi_min       STRING              OPTIONS(description = "Minimum savings KPI as percentage string. E.g. '3,0%' → stored 0.03 in staging."),
  kpi_max       STRING              OPTIONS(description = "Maximum savings KPI as percentage string."),
  variacion     STRING              OPTIONS(description = "KPI range spread (kpi_max - kpi_min). Informational. E.g. '2,0%' → 0.02 in staging.")
)
OPTIONS (
  description = "RAW source: projected savings by sourcing category. PK=rubros. All numerics stored as strings pending locale normalization. Rates stored as decimals (0.03 not 3) in staging.",
  require_partition_filter = false
);
