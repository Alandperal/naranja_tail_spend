-- ============================================================
-- FILE: 02_concentration_analysis.sql
-- PROJECT: naranja-x-491820 | Tail Spend Analytics
-- LAYER: audit_procurement
-- ============================================================
-- Métricas de concentración:
--   HHI = Σ(share_proveedor²) × 10.000
--   < 1500  → Competitivo
--   1500-2500 → Moderado
--   > 2500  → Concentrado (riesgo favoritismo)
-- ============================================================

-- ─── concentration_by_area ───────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.audit_procurement.concentration_by_area`
OPTIONS(description="Concentración proveedor×área. Share%, ranking, HHI component. PK compuesto: area+proveedor.")
AS
WITH area_totals AS (
  SELECT
    area_interna,
    SUM(monto_homogeneo_usd)       AS area_total_homogeneo,
    SUM(monto_usd)                 AS area_total_usd,
    COUNT(DISTINCT invoice_key)    AS area_invoices,
    COUNT(DISTINCT id_proveedor)   AS area_supplier_count
  FROM `naranja-x-491820.mart_procurement.fact_invoices`
  WHERE monto_positivo AND fecha_ok AND fk_valido
  GROUP BY area_interna
),
supplier_spend AS (
  SELECT
    area_interna,
    id_proveedor,
    supplier_name,
    category,
    SUM(monto_homogeneo_usd)       AS spend_homogeneo,
    SUM(monto_usd)                 AS spend_usd,
    COUNT(DISTINCT invoice_key)    AS invoice_count,
    COUNT(DISTINCT periodo)        AS periodos_activos
  FROM `naranja-x-491820.mart_procurement.fact_invoices`
  WHERE monto_positivo AND fecha_ok AND fk_valido
  GROUP BY area_interna, id_proveedor, supplier_name, category
),
ranked AS (
  SELECT
    s.*,
    t.area_total_homogeneo,
    t.area_total_usd,
    t.area_invoices,
    t.area_supplier_count,
    SAFE_DIVIDE(s.spend_homogeneo, t.area_total_homogeneo) AS share_homogeneo,
    SAFE_DIVIDE(s.spend_usd,       t.area_total_usd)        AS share_usd,
    ROW_NUMBER() OVER (
      PARTITION BY s.area_interna
      ORDER BY s.spend_homogeneo DESC
    )                                                        AS rank_area,
    -- Componente HHI = share² × 10000
    POWER(SAFE_DIVIDE(s.spend_homogeneo, t.area_total_homogeneo), 2) * 10000 AS hhi_comp
  FROM supplier_spend s
  JOIN area_totals t ON s.area_interna = t.area_interna
)
SELECT
  *,
  rank_area = 1                          AS is_top1,
  rank_area <= 5                         AS is_top5,
  -- Favoritismo: proveedor #1 con >40% del área
  (rank_area = 1 AND share_homogeneo > 0.40) AS flag_favoritism_40,
  -- Favoritismo severo: >60%
  (rank_area = 1 AND share_homogeneo > 0.60) AS flag_favoritism_60
FROM ranked;

-- ─── hhi_by_area ─────────────────────────────────────────────
CREATE OR REPLACE TABLE `naranja-x-491820.audit_procurement.hhi_by_area`
OPTIONS(description="HHI por área interna. PK=area_interna. Incluye top1/top5 share y risk label.")
AS
SELECT
  area_interna,
  MAX(area_total_homogeneo)                    AS area_total_homogeneo,
  MAX(area_supplier_count)                     AS supplier_count,
  ROUND(SUM(hhi_comp))                         AS hhi_score,
  -- Top 1
  MAX(CASE WHEN rank_area = 1 THEN share_homogeneo END) AS top1_share,
  MAX(CASE WHEN rank_area = 1 THEN supplier_name  END)  AS top1_supplier,
  MAX(CASE WHEN rank_area = 1 THEN spend_homogeneo END) AS top1_spend,
  -- Top 5
  SUM(CASE WHEN rank_area <= 5 THEN share_homogeneo ELSE 0 END) AS top5_share,
  SUM(CASE WHEN rank_area <= 5 THEN spend_homogeneo ELSE 0 END) AS top5_spend,
  -- Riesgo
  CASE
    WHEN ROUND(SUM(hhi_comp)) > 2500 THEN 'RIESGO ALTO'
    WHEN ROUND(SUM(hhi_comp)) > 1500 THEN 'RIESGO MEDIO'
    ELSE 'BAJO RIESGO'
  END                                          AS concentration_risk,
  CASE
    WHEN ROUND(SUM(hhi_comp)) > 2500 THEN 'Altamente Concentrado'
    WHEN ROUND(SUM(hhi_comp)) > 1500 THEN 'Moderadamente Concentrado'
    ELSE 'Competitivo'
  END                                          AS hhi_label
FROM `naranja-x-491820.audit_procurement.concentration_by_area`
GROUP BY area_interna
ORDER BY hhi_score DESC;

-- ─── repeat_favoritism_indicator ─────────────────────────────
CREATE OR REPLACE VIEW `naranja-x-491820.audit_procurement.repeat_favoritism_indicator` AS
WITH period_rank AS (
  SELECT
    area_interna,
    id_proveedor,
    supplier_name,
    category,
    periodo,
    SUM(monto_homogeneo_usd) AS periodo_spend,
    ROW_NUMBER() OVER (
      PARTITION BY area_interna, periodo
      ORDER BY SUM(monto_homogeneo_usd) DESC
    ) AS rank_periodo
  FROM `naranja-x-491820.mart_procurement.fact_invoices`
  WHERE monto_positivo AND fecha_ok AND fk_valido
  GROUP BY area_interna, id_proveedor, supplier_name, category, periodo
)
SELECT
  area_interna,
  id_proveedor,
  supplier_name,
  category,
  COUNT(DISTINCT periodo)          AS periodos_como_top,
  SUM(periodo_spend)               AS gasto_total_como_top,
  MIN(periodo)                     AS primer_periodo_top,
  MAX(periodo)                     AS ultimo_periodo_top,
  CASE
    WHEN COUNT(DISTINCT periodo) >= 6 THEN 'FAVORITISM SISTEMÁTICO'
    WHEN COUNT(DISTINCT periodo) >= 3 THEN 'FAVORITISM RECURRENTE'
    ELSE 'AISLADO'
  END                              AS favoritism_severity
FROM period_rank
WHERE rank_periodo = 1
GROUP BY area_interna, id_proveedor, supplier_name, category
HAVING COUNT(DISTINCT periodo) >= 2
ORDER BY periodos_como_top DESC, gasto_total_como_top DESC;
