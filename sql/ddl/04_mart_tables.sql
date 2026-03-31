-- ============================================================
-- FILE: 04_mart_tables.sql
-- PROJECT: naranja-x-491820 | Tail Spend Analytics
-- LAYER: mart_procurement
-- ============================================================
-- Fórmula moneda homogénea (exacta, según spec):
--   monto_homogeneo_usd = (monto_usd * tc_periodo * (ipc_max / ipc_periodo)) / tc_base
--
-- Período base: Febrero 2026 (periodo = 202602)
--   ipc_base    = 10714.6255   (ipc_fecha_max)
--   tc_base     = 1430.00 ARS/USD
-- ============================================================

-- ─── dim_suppliers ───────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.dim_suppliers`
OPTIONS(description="Dimensión proveedores. PK=id_proveedor.")
AS
SELECT
  id_proveedor                                     AS supplier_key,
  id_proveedor,
  cuit,
  nombre                                           AS supplier_name,
  provincia,
  rubro                                            AS category,
  rubro_raw                                        AS category_raw,
  cuit_valido
FROM `naranja-x-491820.stg_procurement.stg_proveedores`;

-- ─── dim_categories ──────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.dim_categories`
OPTIONS(description="Dimensión categorías/rubros. PK=category. Bridge con savings_proy.")
AS
SELECT
  p.rubro                           AS category,
  COUNT(DISTINCT p.id_proveedor)    AS supplier_count,
  s.factibilidad,
  s.factibilidad_tier,
  s.kpi_min,
  s.kpi_max,
  s.variacion,
  CASE WHEN s.rubros IS NOT NULL THEN TRUE ELSE FALSE END AS tiene_savings_proy
FROM `naranja-x-491820.stg_procurement.stg_proveedores` p
LEFT JOIN `naranja-x-491820.stg_procurement.stg_savings_proy` s
  ON UPPER(TRIM(p.rubro)) = UPPER(TRIM(s.rubros))
GROUP BY
  p.rubro, s.factibilidad, s.factibilidad_tier,
  s.kpi_min, s.kpi_max, s.variacion, s.rubros;

-- ─── dim_areas ───────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.dim_areas`
OPTIONS(description="Dimensión áreas internas. PK=area_interna.")
AS
SELECT DISTINCT
  area_interna,
  ROW_NUMBER() OVER (ORDER BY area_interna) AS area_id
FROM `naranja-x-491820.stg_procurement.stg_facturas`
WHERE area_interna IS NOT NULL;

-- ─── dim_time ────────────────────────────────────────────────
-- Contiene IPC y TC embebidos para simplificar joins en fact_invoices
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.dim_time`
OPTIONS(description="Dimensión tiempo mensual. PK=periodo (YYYYMM). IPC y TC embebidos.")
AS
SELECT
  i.periodo_ipc                              AS periodo,
  DATE_TRUNC(DATE(i.fecha_ipc), MONTH)       AS month_date,
  EXTRACT(YEAR  FROM i.fecha_ipc)            AS year,
  EXTRACT(MONTH FROM i.fecha_ipc)            AS month_num,
  FORMAT_DATE('%B', DATE(i.fecha_ipc))       AS month_name,
  FORMAT_DATE('%Y-%m', DATE(i.fecha_ipc))    AS year_month_label,
  CAST(CEIL(EXTRACT(MONTH FROM i.fecha_ipc) / 3.0) AS INT64) AS quarter_num,
  CONCAT('Q', CAST(CEIL(EXTRACT(MONTH FROM i.fecha_ipc)/3.0) AS STRING),
         ' ', CAST(EXTRACT(YEAR FROM i.fecha_ipc) AS STRING)) AS quarter_label,
  i.ipc,
  i.ipc_fecha_max,
  i.coeficiente                              AS deflation_coeff,   -- ipc_max/ipc
  tc.tipo_cambio                             AS tc_periodo
FROM `naranja-x-491820.stg_procurement.stg_ipc` i
LEFT JOIN `naranja-x-491820.stg_procurement.stg_tc` tc
  ON i.periodo_ipc = tc.periodo;

-- ─── fact_invoices ───────────────────────────────────────────
-- FÓRMULA MONEDA HOMOGÉNEA:
--   monto_homogeneo_usd = (monto_usd * tc_periodo * (ipc_max / ipc_periodo)) / tc_base
--
-- Equivalente expandido:
--   = monto_usd * tc_periodo * deflation_coeff / tc_base
--
-- Donde:
--   tc_periodo      = TC ARS/USD del mes de la factura
--   ipc_max         = IPC del período base (10714.6255, constante en todas las filas)
--   ipc_periodo     = IPC del mes de la factura
--   deflation_coeff = ipc_max / ipc_periodo
--   tc_base         = TC ARS/USD del período base = 1430.00 (feb-2026)
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.fact_invoices`
PARTITION BY fecha
CLUSTER BY id_proveedor, area_interna, category
OPTIONS(
  description="Fact invoices. Grain=1 fila/factura. Incluye monto_homogeneo_usd. Partición por fecha.",
  require_partition_filter=false
)
AS
WITH base AS (
  SELECT
    f.id_factura,
    f.id_proveedor,
    f.monto_usd,
    f.area_interna,
    f.fecha_parsed                                  AS fecha,
    f.articulos,
    f.periodo,
    f.fk_valido,
    f.monto_positivo,
    f.fecha_ok,
    s.supplier_name,
    s.category,
    s.category_raw,
    s.provincia
  FROM `naranja-x-491820.stg_procurement.stg_facturas` f
  LEFT JOIN `naranja-x-491820.mart_procurement.dim_suppliers` s
    ON f.id_proveedor = s.id_proveedor
),
with_time AS (
  SELECT
    b.*,
    t.tc_periodo,
    t.deflation_coeff,         -- = ipc_max / ipc_periodo
    t.ipc,
    t.ipc_fecha_max            AS ipc_max,
    t.year,
    t.month_num,
    t.quarter_label,
    t.year_month_label,
    -- tc_base: TC del período de referencia (feb-2026)
    ref.tc_periodo             AS tc_base
  FROM base b
  LEFT JOIN `naranja-x-491820.mart_procurement.dim_time` t
    ON b.periodo = t.periodo
  CROSS JOIN (
    -- tc_base = TC del período más reciente con IPC disponible
    SELECT tc_periodo
    FROM `naranja-x-491820.mart_procurement.dim_time`
    WHERE periodo = (SELECT MAX(periodo) FROM `naranja-x-491820.mart_procurement.dim_time`)
  ) ref
)
SELECT
  id_factura                                        AS invoice_key,
  id_factura,
  id_proveedor,
  supplier_name,
  category,
  category_raw,
  provincia,
  area_interna,
  fecha,
  articulos,
  periodo,
  year,
  month_num,
  quarter_label,
  year_month_label,

  -- ── Medidas de dinero ──────────────────────────────────────
  monto_usd,
  tc_periodo,
  ipc,
  ipc_max,
  deflation_coeff,
  tc_base,

  -- Paso 1: USD → ARS nominal
  SAFE_MULTIPLY(monto_usd, tc_periodo)              AS monto_ars_nominal,

  -- Fórmula completa moneda homogénea:
  -- (monto_usd * tc_periodo * (ipc_max / ipc_periodo)) / tc_base
  SAFE_DIVIDE(
    SAFE_MULTIPLY(
      SAFE_MULTIPLY(monto_usd, tc_periodo),
      deflation_coeff                               -- = ipc_max / ipc_periodo
    ),
    tc_base
  )                                                 AS monto_homogeneo_usd,

  -- ── Flags ─────────────────────────────────────────────────
  fk_valido,
  monto_positivo,
  fecha_ok,
  CURRENT_TIMESTAMP()                               AS etl_ts
FROM with_time;

-- ─── mart_spend_by_category_period ───────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.mart_spend_by_category_period`
OPTIONS(description="Pre-agregado: categoría × período. Para trend charts y sourcing.")
AS
SELECT
  category,
  periodo,
  year,
  year_month_label,
  quarter_label,
  COUNT(DISTINCT invoice_key)    AS invoice_count,
  COUNT(DISTINCT id_proveedor)   AS supplier_count,
  SUM(monto_usd)                 AS total_usd_nominal,
  SUM(monto_homogeneo_usd)       AS total_homogeneo_usd,
  AVG(monto_usd)                 AS avg_invoice_usd
FROM `naranja-x-491820.mart_procurement.fact_invoices`
WHERE monto_positivo AND fecha_ok
GROUP BY category, periodo, year, year_month_label, quarter_label;

-- ─── mart_spend_by_area_supplier ─────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.mart_spend_by_area_supplier`
OPTIONS(description="Pre-agregado: área × proveedor. Para análisis de concentración.")
AS
SELECT
  area_interna,
  id_proveedor,
  supplier_name,
  category,
  COUNT(DISTINCT invoice_key)    AS invoice_count,
  SUM(monto_usd)                 AS total_usd_nominal,
  SUM(monto_homogeneo_usd)       AS total_homogeneo_usd,
  MIN(fecha)                     AS primera_factura,
  MAX(fecha)                     AS ultima_factura,
  COUNT(DISTINCT periodo)        AS periodos_activos
FROM `naranja-x-491820.mart_procurement.fact_invoices`
WHERE monto_positivo AND fecha_ok
GROUP BY area_interna, id_proveedor, supplier_name, category;

-- ─── executive_kpi_summary ───────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.executive_kpi_summary`
OPTIONS(description="KPI ejecutivo pre-agregado por mes. Para tiles de Looker.")
AS
SELECT
  year,
  month_num,
  year_month_label,
  quarter_label,
  COUNT(DISTINCT invoice_key)                          AS invoice_count,
  COUNT(DISTINCT id_proveedor)                         AS supplier_count,
  COUNT(DISTINCT area_interna)                         AS area_count,
  SUM(monto_usd)                                       AS raw_usd_spend,
  SUM(monto_homogeneo_usd)                             AS homogeneous_usd_spend,
  AVG(monto_usd)                                       AS avg_invoice_usd,
  COUNTIF(monto_usd > 15000)                           AS facturas_sobre_15k,
  SUM(CASE WHEN monto_usd > 15000 THEN monto_usd END)  AS spend_sobre_15k_usd
FROM `naranja-x-491820.mart_procurement.fact_invoices`
WHERE monto_positivo AND fecha_ok
GROUP BY year, month_num, year_month_label, quarter_label
ORDER BY year, month_num;
