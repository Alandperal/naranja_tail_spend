-- ============================================================
-- FILE: 01_sourcing_candidates.sql
-- PROJECT: naranja-x-491820 | Tail Spend Analytics
-- LAYER: mart_procurement
-- ============================================================
-- Criterios de elegibilidad:
--   distinct_supplier_count > 20  (fragmentación real)
--
-- Score compuesto (normalizado 0–1):
--   composite = 0.40 × freq_score + 0.30 × dispersion_score + 0.30 × savings_score
--
-- Savings:
--   min_savings  = gasto_homogeneo × factibilidad × kpi_min
--   base_savings = gasto_homogeneo × factibilidad × (kpi_min + kpi_max) / 2
--   max_savings  = gasto_homogeneo × factibilidad × kpi_max
-- ============================================================

CREATE OR REPLACE TABLE `naranja-x-491820.mart_procurement.sourcing_candidates`
OPTIONS(description="Candidatos a acuerdo marco. Score compuesto: frecuencia, dispersión, savings. PK=category.")
AS
WITH metrics AS (
  SELECT
    category,
    COUNT(DISTINCT invoice_key)      AS invoice_count,
    COUNT(DISTINCT id_proveedor)     AS distinct_suppliers,
    COUNT(DISTINCT area_interna)     AS distinct_areas,
    SUM(monto_usd)                   AS total_usd,
    SUM(monto_homogeneo_usd)         AS total_homogeneo,
    AVG(monto_homogeneo_usd)         AS avg_invoice_homogeneo,
    MAX(monto_usd)                   AS max_invoice_usd,
    COUNTIF(monto_usd > 15000)       AS facturas_sobre_umbral
  FROM `naranja-x-491820.mart_procurement.fact_invoices`
  WHERE monto_positivo AND fecha_ok
  GROUP BY category
),
with_savings AS (
  SELECT
    m.*,
    sp.factibilidad,
    sp.factibilidad_tier,
    sp.kpi_min,
    sp.kpi_max,
    -- savings mín: gasto×factibilidad×kpi_min
    ROUND(m.total_homogeneo * sp.factibilidad * sp.kpi_min, 0)          AS min_savings_usd,
    -- savings base: gasto×factibilidad×(kpi_min+kpi_max)/2
    ROUND(m.total_homogeneo * sp.factibilidad * (sp.kpi_min + sp.kpi_max) / 2.0, 0) AS base_savings_usd,
    -- savings max: gasto×factibilidad×kpi_max
    ROUND(m.total_homogeneo * sp.factibilidad * sp.kpi_max, 0)          AS max_savings_usd
  FROM metrics m
  LEFT JOIN `naranja-x-491820.stg_procurement.stg_savings_proy` sp
    ON UPPER(TRIM(m.category)) = UPPER(TRIM(sp.rubros))
),
scored AS (
  SELECT
    *,
    -- elegibilidad
    distinct_suppliers > 20                                  AS eligible,
    -- scores normalizados 0-1
    SAFE_DIVIDE(invoice_count,      MAX(invoice_count) OVER())      AS freq_score,
    SAFE_DIVIDE(distinct_suppliers, MAX(distinct_suppliers) OVER())  AS dispersion_score,
    SAFE_DIVIDE(base_savings_usd,   MAX(base_savings_usd) OVER())   AS savings_score
  FROM with_savings
),
ranked AS (
  SELECT
    *,
    ROUND(
      0.40 * freq_score +
      0.30 * dispersion_score +
      0.30 * COALESCE(savings_score, 0),
      4
    )                                                        AS composite_score,
    DENSE_RANK() OVER (
      ORDER BY (
        0.40 * freq_score +
        0.30 * dispersion_score +
        0.30 * COALESCE(savings_score, 0)
      ) DESC
    )                                                        AS candidate_rank
  FROM scored
)
SELECT
  category,
  candidate_rank,
  CASE
    WHEN candidate_rank <= 3 AND eligible THEN 'TOP CANDIDATO ACUERDO MARCO'
    WHEN candidate_rank <= 6 AND eligible THEN 'CANDIDATO SECUNDARIO'
    ELSE 'NO PRIORIZADO'
  END                                                        AS candidacy_status,
  invoice_count,
  distinct_suppliers,
  distinct_areas,
  eligible,
  total_usd,
  total_homogeneo,
  avg_invoice_homogeneo,
  max_invoice_usd,
  facturas_sobre_umbral,
  factibilidad,
  factibilidad_tier,
  kpi_min,
  kpi_max,
  min_savings_usd,
  base_savings_usd,
  max_savings_usd,
  freq_score,
  dispersion_score,
  savings_score,
  composite_score,
  CURRENT_TIMESTAMP() AS etl_ts
FROM ranked
ORDER BY candidate_rank;

-- ─── Vista ejecutiva de savings totales ──────────────────────
CREATE OR REPLACE VIEW `naranja-x-491820.mart_procurement.executive_savings_summary` AS
SELECT
  COUNT(DISTINCT category)                                    AS total_categories,
  COUNTIF(candidacy_status = 'TOP CANDIDATO ACUERDO MARCO')   AS top_candidates,
  SUM(total_homogeneo)                                        AS total_addressable_spend,
  SUM(CASE WHEN candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'
      THEN total_homogeneo  ELSE 0 END)                       AS candidate_spend,
  SUM(CASE WHEN candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'
      THEN min_savings_usd  ELSE 0 END)                       AS total_min_savings,
  SUM(CASE WHEN candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'
      THEN base_savings_usd ELSE 0 END)                       AS total_base_savings,
  SUM(CASE WHEN candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'
      THEN max_savings_usd  ELSE 0 END)                       AS total_max_savings
FROM `naranja-x-491820.mart_procurement.sourcing_candidates`;
