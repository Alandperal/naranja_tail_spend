-- ============================================================
-- FILE: 01_homogeneous_currency.sql
-- PROJECT: naranja-x-491820 | Tail Spend Analytics
-- LAYER: mart_procurement — validación y KPI ejecutivo
-- ============================================================
-- Fórmula moneda homogénea:
--   monto_homogeneo_usd = (monto_usd × tc_periodo × (ipc_max/ipc_periodo)) / tc_base
-- Base: Febrero 2026 — ipc_max=10714.6255, tc_base=1430 ARS/USD
-- ============================================================

-- ─── VALIDATION: coeficientes por período ────────────────────
-- Útil para auditoría del CFO: muestra el multiplicador real por mes
SELECT
  i.periodo_ipc,
  i.ipc,
  i.ipc_fecha_max,
  -- coeficiente = ipc_max / ipc  (siempre ≥ 1 para períodos anteriores al base)
  ROUND(i.coeficiente, 6)          AS deflation_coeff,
  tc.tipo_cambio                   AS tc_periodo,
  ref.tipo_cambio                  AS tc_base_202602,
  -- Ejemplo: ¿qué vale USD 10k homogéneo?
  ROUND(
    10000
    * tc.tipo_cambio
    * i.coeficiente
    / ref.tipo_cambio,
    2
  )                                AS ejemplo_10k_usd_homogeneo
FROM `naranja-x-491820.stg_procurement.stg_ipc` i
JOIN `naranja-x-491820.stg_procurement.stg_tc` tc
  ON i.periodo_ipc = tc.periodo
CROSS JOIN (
  SELECT tipo_cambio
  FROM `naranja-x-491820.stg_procurement.stg_tc`
  WHERE periodo = 202602
) ref
ORDER BY i.periodo_ipc DESC;

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
  AVG(monto_homogeneo_usd)                             AS avg_invoice_homogeneo_usd,
  COUNTIF(monto_usd > 15000)                           AS invoices_above_15k,
  SUM(CASE WHEN monto_usd > 15000 THEN monto_usd END)  AS spend_above_15k_usd
FROM `naranja-x-491820.mart_procurement.fact_invoices`
WHERE monto_positivo AND fecha_ok
GROUP BY year, month_num, year_month_label, quarter_label
ORDER BY year, month_num;
