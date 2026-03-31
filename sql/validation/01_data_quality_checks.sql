-- =============================================================================
-- FILE: 01_data_quality_checks.sql
-- PROJECT: Tail Spend Analytics — Procurement Intelligence Platform
-- LAYER: Validation Framework
-- =============================================================================
-- Ejecutar después de cargar las tablas de staging y mart.
-- Cada query retorna resultados: 0 filas = PASS, >0 filas = FAIL con detalle.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 01: PK Uniqueness — proveedores
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'PK_UNIQUENESS' AS check_type,
  'stg_proveedores' AS table_name,
  'id_proveedor' AS column_name,
  id_proveedor AS failing_value,
  COUNT(*) AS row_count
FROM `naranja-x-491820.stg_procurement.stg_proveedores`
GROUP BY id_proveedor
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 02: PK Uniqueness — facturas
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'PK_UNIQUENESS' AS check_type,
  'stg_facturas' AS table_name,
  'id_factura' AS column_name,
  id_factura AS failing_value,
  COUNT(*) AS row_count
FROM `naranja-x-491820.stg_procurement.stg_facturas`
GROUP BY id_factura
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 03: PK Uniqueness — ipc
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'PK_UNIQUENESS' AS check_type,
  'stg_ipc' AS table_name,
  'periodo_ipc' AS column_name,
  CAST(periodo_ipc AS STRING) AS failing_value,
  COUNT(*) AS row_count
FROM `naranja-x-491820.stg_procurement.stg_ipc`
GROUP BY periodo_ipc
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 04: PK Uniqueness — tc
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'PK_UNIQUENESS' AS check_type,
  'stg_tc' AS table_name,
  'periodo' AS column_name,
  CAST(periodo AS STRING) AS failing_value,
  COUNT(*) AS row_count
FROM `naranja-x-491820.stg_procurement.stg_tc`
GROUP BY periodo
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 05: PK Uniqueness — savings_proy
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'PK_UNIQUENESS' AS check_type,
  'stg_savings_proy' AS table_name,
  'rubros' AS column_name,
  rubros AS failing_value,
  COUNT(*) AS row_count
FROM `naranja-x-491820.stg_procurement.stg_savings_proy`
GROUP BY rubros
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 06: FK Integrity — facturas.id_proveedor → proveedores.id_proveedor
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'FK_INTEGRITY' AS check_type,
  'stg_facturas' AS table_name,
  'id_proveedor' AS column_name,
  f.id_proveedor AS failing_value,
  COUNT(*) AS orphaned_invoice_count
FROM `naranja-x-491820.stg_procurement.stg_facturas` f
LEFT JOIN `naranja-x-491820.stg_procurement.stg_proveedores` p
  ON f.id_proveedor = p.id_proveedor
WHERE p.id_proveedor IS NULL
  AND f.id_proveedor IS NOT NULL
GROUP BY f.id_proveedor
ORDER BY orphaned_invoice_count DESC;
-- Expected: 0 rows (all invoices have a valid supplier)

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 07: FK Integrity — savings_proy.rubros → proveedores.rubro
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'FK_INTEGRITY' AS check_type,
  'stg_savings_proy' AS table_name,
  'rubros' AS column_name,
  s.rubros AS failing_value,
  'No matching rubro in proveedores' AS reason
FROM `naranja-x-491820.stg_procurement.stg_savings_proy` s
LEFT JOIN (
  SELECT DISTINCT rubro FROM `naranja-x-491820.stg_procurement.stg_proveedores`
) p ON UPPER(TRIM(s.rubros)) = UPPER(TRIM(p.rubro))
WHERE p.rubro IS NULL;
-- Expected: 0 rows (all savings categories exist in supplier rubro set)

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 08: Null Checks — critical fields in stg_facturas
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'NULL_CHECK' AS check_type,
  'stg_facturas' AS table_name,
  field_name,
  null_count
FROM (
  SELECT 'id_factura'   AS field_name, COUNTIF(id_factura IS NULL)   AS null_count FROM `naranja-x-491820.stg_procurement.stg_facturas` UNION ALL
  SELECT 'id_proveedor' AS field_name, COUNTIF(id_proveedor IS NULL) AS null_count FROM `naranja-x-491820.stg_procurement.stg_facturas` UNION ALL
  SELECT 'monto_usd'    AS field_name, COUNTIF(monto_usd IS NULL)    AS null_count FROM `naranja-x-491820.stg_procurement.stg_facturas` UNION ALL
  SELECT 'fecha_parsed' AS field_name, COUNTIF(fecha_parsed IS NULL) AS null_count FROM `naranja-x-491820.stg_procurement.stg_facturas` UNION ALL
  SELECT 'area_interna' AS field_name, COUNTIF(area_interna IS NULL) AS null_count FROM `naranja-x-491820.stg_procurement.stg_facturas`
)
WHERE null_count > 0;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 09: Domain Check — monto_usd must be positive
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'DOMAIN_CHECK' AS check_type,
  'stg_facturas.monto_usd must be > 0' AS rule,
  COUNT(*) AS failing_rows
FROM `naranja-x-491820.stg_procurement.stg_facturas`
WHERE monto_usd <= 0 OR monto_usd IS NULL;
-- Expected: failing_rows = 0

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 10: Domain Check — factibilidad between 0.0 and 1.0
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'DOMAIN_CHECK' AS check_type,
  'stg_savings_proy.factibilidad must be in [0.0, 1.0]' AS rule,
  rubros,
  factibilidad AS failing_value
FROM `naranja-x-491820.stg_procurement.stg_savings_proy`
WHERE factibilidad < 0 OR factibilidad > 1 OR factibilidad IS NULL;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 11: Domain Check — kpi_min <= kpi_max in savings_proy
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'DOMAIN_CHECK' AS check_type,
  'stg_savings_proy.kpi_min must be <= kpi_max' AS rule,
  rubros,
  kpi_min,
  kpi_max
FROM `naranja-x-491820.stg_procurement.stg_savings_proy`
WHERE kpi_min > kpi_max;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 12: Date Parse Success Rate
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'DATE_PARSE_CHECK' AS check_type,
  COUNTIF(fecha_parsed IS NULL) AS failed_parses,
  COUNT(*) AS total_rows,
  ROUND(COUNTIF(fecha_parsed IS NULL) * 100.0 / COUNT(*), 2) AS pct_failed
FROM `naranja-x-491820.stg_procurement.stg_facturas`;
-- Expected: pct_failed = 0.00

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 13: IPC Coeficiente Sanity
-- coeficiente_recomputed should be >= 1.0 (deflating backward → always multiplies)
-- Max should be reasonable (< 2.0 for 14-month window)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'HOMOGENEOUS_CURRENCY_SANITY' AS check_type,
  periodo_ipc,
  ipc,
  ipc_fecha_max,
  coeficiente_recomputed,
  CASE
    WHEN coeficiente_recomputed < 1.0 THEN 'FAIL: coeff < 1 (base period should have coeff=1)'
    WHEN coeficiente_recomputed > 2.5 THEN 'WARN: coeff > 2.5 (high inflation signal - verify)'
    ELSE 'OK'
  END AS status
FROM `naranja-x-491820.stg_procurement.stg_ipc`
ORDER BY periodo_ipc DESC;
-- Expected: all OK or WARN only for oldest periods

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 14: TC Coverage — every invoice period has a TC record
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'TC_COVERAGE' AS check_type,
  f.periodo,
  COUNT(*) AS invoice_count,
  'No exchange rate record for this period' AS reason
FROM `naranja-x-491820.stg_procurement.stg_facturas` f
LEFT JOIN `naranja-x-491820.stg_procurement.stg_tc` tc
  ON f.periodo = tc.periodo
WHERE tc.periodo IS NULL
  AND f.periodo IS NOT NULL
GROUP BY f.periodo
ORDER BY f.periodo;
-- Expected: 0 rows (all invoice periods have TC entry)

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 15: IPC Coverage — every invoice period has an IPC record
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'IPC_COVERAGE' AS check_type,
  f.periodo,
  COUNT(*) AS invoice_count,
  'No IPC record for this period' AS reason
FROM `naranja-x-491820.stg_procurement.stg_facturas` f
LEFT JOIN `naranja-x-491820.stg_procurement.stg_ipc` ipc
  ON f.periodo = ipc.periodo_ipc
WHERE ipc.periodo_ipc IS NULL
  AND f.periodo IS NOT NULL
GROUP BY f.periodo
ORDER BY f.periodo;
-- Expected: 0 rows

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 16: Homogeneous USD Sanity in fact_invoices
-- homogeneous amount should not deviate more than 100% from raw USD in same period
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'HOMOGENEOUS_SANITY' AS check_type,
  periodo,
  COUNT(*) AS invoice_count,
  ROUND(AVG(monto_usd), 2) AS avg_raw_usd,
  ROUND(AVG(monto_homogeneo_usd), 2) AS avg_homogeneo_usd,
  ROUND(AVG(monto_homogeneo_usd) / NULLIF(AVG(monto_usd), 0), 4) AS ratio
FROM `naranja-x-491820.mart_procurement.fact_invoices`
WHERE monto_positivo
GROUP BY periodo
ORDER BY periodo;
-- Expectation: ratio should be close to deflation_coeff * tc_periodo / tc_referencia
-- Older periods → higher ratio (reflecting accumulated inflation)

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 17: Savings Consistency — variacion should = kpi_max - kpi_min
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'SAVINGS_CONSISTENCY' AS check_type,
  rubros,
  kpi_min,
  kpi_max,
  variacion,
  ROUND(kpi_max - kpi_min, 4) AS expected_variacion,
  CASE WHEN ABS(variacion - (kpi_max - kpi_min)) > 0.0001
       THEN 'FAIL: variacion mismatch'
       ELSE 'OK'
  END AS status
FROM `naranja-x-491820.stg_procurement.stg_savings_proy`;
-- Expected: all OK

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 18: CUIT Format Validation Summary
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'CUIT_FORMAT' AS check_type,
  cuit_formato_valido,
  COUNT(*) AS supplier_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM `naranja-x-491820.stg_procurement.stg_proveedores`
GROUP BY cuit_formato_valido;
-- Expected: cuit_formato_valido=TRUE for ~100%

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 19: Rubro Distribution — confirm 6 canonical categories
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  'RUBRO_DISTRIBUTION' AS check_type,
  rubro AS category,
  COUNT(*) AS supplier_count
FROM `naranja-x-491820.stg_procurement.stg_proveedores`
GROUP BY rubro
ORDER BY supplier_count DESC;
-- Expected: exactly 6 rubros matching savings_proy categories

-- ─────────────────────────────────────────────────────────────────────────────
-- CHECK 20: Reconciliation — row counts match raw → staging
-- ─────────────────────────────────────────────────────────────────────────────
SELECT 'proveedores' AS table_name,
  (SELECT COUNT(*) FROM `naranja-x-491820.raw_procurement.proveedores`) AS raw_count,
  (SELECT COUNT(*) FROM `naranja-x-491820.stg_procurement.stg_proveedores`) AS stg_count
UNION ALL
SELECT 'facturas',
  (SELECT COUNT(*) FROM `naranja-x-491820.raw_procurement.facturas`),
  (SELECT COUNT(*) FROM `naranja-x-491820.stg_procurement.stg_facturas`)
UNION ALL
SELECT 'ipc',
  (SELECT COUNT(*) FROM `naranja-x-491820.raw_procurement.ipc`),
  (SELECT COUNT(*) FROM `naranja-x-491820.stg_procurement.stg_ipc`)
UNION ALL
SELECT 'tc',
  (SELECT COUNT(*) FROM `naranja-x-491820.raw_procurement.tc`),
  (SELECT COUNT(*) FROM `naranja-x-491820.stg_procurement.stg_tc`)
UNION ALL
SELECT 'savings_proy',
  (SELECT COUNT(*) FROM `naranja-x-491820.raw_procurement.savings_proy`),
  (SELECT COUNT(*) FROM `naranja-x-491820.stg_procurement.stg_savings_proy`);
-- Expected: raw_count = stg_count for all tables (no row loss)
