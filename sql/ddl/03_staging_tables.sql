-- ============================================================
-- FILE: 03_staging_tables.sql
-- PROJECT: naranja-x-491820 | Tail Spend Analytics
-- LAYER: stg_procurement
-- ============================================================
-- Responsabilidades:
--   1. Parseo de numéricos con locale europeo (coma decimal)
--   2. Parseo de fechas dd/m/yyyy → DATE
--   3. Normalización de rubros a 6 categorías canónicas
--   4. Deduplicación por PK
--   5. Flags de validación FK / parse ok
--   6. Recompute de coeficiente IPC (campo raw ambiguo)
-- ============================================================

-- ─── stg_proveedores ────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.stg_procurement.stg_proveedores`
OPTIONS(description="Staging proveedores. PK=id_proveedor. Rubro normalizado. CUIT validado.")
AS
WITH ranked AS (
  SELECT
    TRIM(id_proveedor)                               AS id_proveedor,
    TRIM(cuit)                                       AS cuit,
    TRIM(nombre)                                     AS nombre,
    INITCAP(TRIM(provincia))                         AS provincia,
    CASE UPPER(TRIM(rubro))
      WHEN 'HARDWARE'      THEN 'Hardware'
      WHEN 'CONSULTORÍA'   THEN 'Consultoría'
      WHEN 'CONSULTORIA'   THEN 'Consultoría'
      WHEN 'LIMPIEZA'      THEN 'Limpieza'
      WHEN 'CATERING'      THEN 'Catering'
      WHEN 'MANTENIMIENTO' THEN 'Mantenimiento'
      WHEN 'LIBRERÍA'      THEN 'Librería'
      WHEN 'LIBRERIA'      THEN 'Librería'
      ELSE INITCAP(TRIM(rubro))
    END                                              AS rubro,
    TRIM(rubro)                                      AS rubro_raw,
    REGEXP_CONTAINS(TRIM(cuit), r'^\d{2}-\d{7,8}-\d{1}$') AS cuit_valido,
    ROW_NUMBER() OVER (PARTITION BY TRIM(id_proveedor) ORDER BY TRIM(id_proveedor)) AS rn
  FROM `naranja-x-491820.raw_procurement.proveedores`
  WHERE id_proveedor IS NOT NULL AND TRIM(id_proveedor) != ''
)
SELECT
  id_proveedor, cuit, nombre, provincia,
  rubro, rubro_raw, cuit_valido,
  CURRENT_TIMESTAMP() AS etl_ts
FROM ranked WHERE rn = 1;

-- ─── stg_facturas ───────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.stg_procurement.stg_facturas`
PARTITION BY fecha_parsed
CLUSTER BY id_proveedor, area_interna
OPTIONS(
  description="Staging facturas. monto_usd parseado. fecha parseada. FK flag. Partición por fecha.",
  require_partition_filter=false
)
AS
WITH base AS (
  SELECT
    TRIM(id_factura)                                 AS id_factura,
    TRIM(id_proveedor)                               AS id_proveedor,
    -- Locale numeric: quitar puntos de miles, cambiar coma por punto
    SAFE_CAST(
      REPLACE(REPLACE(TRIM(monto_usd), '.', ''), ',', '.') AS NUMERIC
    )                                                AS monto_usd,
    TRIM(area_interna)                               AS area_interna,
    -- Fecha dd/m/yyyy → DATE con zero-padding robusto
    SAFE.PARSE_DATE(
      '%d/%m/%Y',
      CONCAT(
        LPAD(SPLIT(TRIM(fecha), '/')[OFFSET(0)], 2, '0'), '/',
        LPAD(SPLIT(TRIM(fecha), '/')[OFFSET(1)], 2, '0'), '/',
        SPLIT(TRIM(fecha), '/')[OFFSET(2)]
      )
    )                                                AS fecha_parsed,
    TRIM(fecha)                                      AS fecha_raw,
    TRIM(articulos)                                  AS articulos,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(id_factura)
      ORDER BY TRIM(id_factura)
    )                                                AS rn
  FROM `naranja-x-491820.raw_procurement.facturas`
  WHERE id_factura IS NOT NULL AND TRIM(id_factura) != ''
)
SELECT
  b.id_factura,
  b.id_proveedor,
  b.monto_usd,
  b.area_interna,
  b.fecha_parsed,
  b.fecha_raw,
  b.articulos,
  -- FK flag
  CASE WHEN p.id_proveedor IS NOT NULL THEN TRUE ELSE FALSE END AS fk_valido,
  -- Sanity flags
  CASE WHEN b.monto_usd > 0         THEN TRUE ELSE FALSE END    AS monto_positivo,
  CASE WHEN b.fecha_parsed IS NOT NULL THEN TRUE ELSE FALSE END  AS fecha_ok,
  -- Periodo YYYYMM para joins con IPC y TC
  CAST(FORMAT_DATE('%Y%m', b.fecha_parsed) AS INT64)            AS periodo,
  CURRENT_TIMESTAMP() AS etl_ts
FROM base b
LEFT JOIN `naranja-x-491820.stg_procurement.stg_proveedores` p
  ON b.id_proveedor = p.id_proveedor
WHERE b.rn = 1;

-- ─── stg_ipc ────────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.stg_procurement.stg_ipc`
OPTIONS(description="Staging IPC. coeficiente RECOMPUTADO como ipc_fecha_max/ipc. Raw preservado.")
AS
WITH parsed AS (
  SELECT
    SAFE_CAST(TRIM(periodo_ipc) AS INT64)            AS periodo_ipc,
    SAFE.PARSE_DATETIME(
      '%Y-%m-%d %H:%M:%S',
      -- Normalizar "2026-02-28 0:00:00" → "2026-02-28 00:00:00"
      REGEXP_REPLACE(
        TRIM(fecha_ipc),
        r' (\d):',
        ' 0\\1:'
      )
    )                                                AS fecha_ipc,
    SAFE_CAST(
      REPLACE(REPLACE(TRIM(ipc), '.', ''), ',', '.') AS NUMERIC
    )                                                AS ipc,
    SAFE_CAST(
      REPLACE(REPLACE(TRIM(ipc_fecha_max), '.', ''), ',', '.') AS NUMERIC
    )                                                AS ipc_fecha_max,
    SAFE.PARSE_DATE(
      '%d/%m/%Y',
      CONCAT(
        LPAD(SPLIT(TRIM(fecha_ipc_max), '/')[OFFSET(0)], 2, '0'), '/',
        LPAD(SPLIT(TRIM(fecha_ipc_max), '/')[OFFSET(1)], 2, '0'), '/',
        SPLIT(TRIM(fecha_ipc_max), '/')[OFFSET(2)]
      )
    )                                                AS fecha_ipc_max,
    coeficiente                                      AS coeficiente_raw
  FROM `naranja-x-491820.raw_procurement.ipc`
  WHERE periodo_ipc IS NOT NULL
)
SELECT
  periodo_ipc, fecha_ipc, ipc, ipc_fecha_max, fecha_ipc_max,
  coeficiente_raw,
  -- Recompute auditable: siempre >= 1 para períodos anteriores al base
  SAFE_DIVIDE(ipc_fecha_max, ipc)                    AS coeficiente,
  CURRENT_TIMESTAMP() AS etl_ts
FROM parsed;

-- ─── stg_tc ─────────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.stg_procurement.stg_tc`
OPTIONS(description="Staging TC ARS/USD por período. tipo_cambio normalizado. PK=periodo.")
AS
SELECT
  SAFE_CAST(TRIM(periodo) AS INT64)                  AS periodo,
  SAFE_CAST(
    REPLACE(REPLACE(TRIM(tipo_cambio), '.', ''), ',', '.') AS NUMERIC
  )                                                  AS tipo_cambio,
  TRIM(tipo_cambio)                                  AS tipo_cambio_raw,
  CURRENT_TIMESTAMP() AS etl_ts
FROM `naranja-x-491820.raw_procurement.tc`
WHERE periodo IS NOT NULL;

-- ─── stg_savings_proy ───────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.stg_procurement.stg_savings_proy`
OPTIONS(description="Staging savings_proy. Tasas como decimales (0.03=3%). Tier de factibilidad.")
AS
SELECT
  INITCAP(TRIM(rubros))                              AS rubros,
  SAFE_CAST(
    REPLACE(REPLACE(TRIM(factibilidad), '.', ''), ',', '.') AS NUMERIC
  )                                                  AS factibilidad,
  -- "3,0%" → 0.03
  SAFE_CAST(
    REPLACE(REPLACE(REPLACE(TRIM(kpi_min), '%', ''), '.', ''), ',', '.') AS NUMERIC
  ) / 100.0                                          AS kpi_min,
  SAFE_CAST(
    REPLACE(REPLACE(REPLACE(TRIM(kpi_max), '%', ''), '.', ''), ',', '.') AS NUMERIC
  ) / 100.0                                          AS kpi_max,
  SAFE_CAST(
    REPLACE(REPLACE(REPLACE(TRIM(variacion), '%', ''), '.', ''), ',', '.') AS NUMERIC
  ) / 100.0                                          AS variacion,
  -- Tier de factibilidad (semáforo de riesgo)
  CASE
    WHEN SAFE_CAST(REPLACE(REPLACE(TRIM(factibilidad),'.',''),',','.') AS NUMERIC) = 1.0
      THEN 'Éxito Asegurado'
    WHEN SAFE_CAST(REPLACE(REPLACE(TRIM(factibilidad),'.',''),',','.') AS NUMERIC) >= 0.7
      THEN 'Alta Probabilidad'
    WHEN SAFE_CAST(REPLACE(REPLACE(TRIM(factibilidad),'.',''),',','.') AS NUMERIC) >= 0.3
      THEN 'Dificultad Media-Alta'
    ELSE 'Bloqueado'
  END                                                AS factibilidad_tier,
  CURRENT_TIMESTAMP() AS etl_ts
FROM `naranja-x-491820.raw_procurement.savings_proy`
WHERE rubros IS NOT NULL;
