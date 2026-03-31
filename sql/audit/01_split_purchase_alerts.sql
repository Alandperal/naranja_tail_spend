-- ============================================================
-- FILE: 01_split_purchase_alerts.sql
-- PROJECT: naranja-x-491820 | Tail Spend Analytics
-- LAYER: audit_procurement
-- ============================================================
-- REGLA: mismo proveedor + misma área > USD 15.000 acumulado
--        en ventana móvil de 7 días (inclusive: [fecha-6, fecha])
-- THRESHOLD evaluado en monto_usd NOMINAL (no homogéneo)
-- ============================================================

CREATE OR REPLACE TABLE `naranja-x-491820.audit_procurement.split_purchase_alerts`
OPTIONS(description="Alertas desdoblamiento. Rolling 7d. Umbral USD 15k nominal. PK=alert_id.")
AS
WITH invoice_base AS (
  SELECT
    invoice_key,
    id_factura,
    id_proveedor,
    supplier_name,
    category,
    area_interna,
    fecha,
    monto_usd,
    monto_homogeneo_usd,
    periodo
  FROM `naranja-x-491820.mart_procurement.fact_invoices`
  WHERE monto_positivo AND fecha_ok AND fk_valido
),
rolling AS (
  -- Para cada factura ANCLA, suma todas las facturas del mismo proveedor+área
  -- en la ventana [ancla - 6 días, ancla] inclusive
  SELECT
    a.id_factura                             AS anchor_invoice,
    a.id_proveedor,
    a.supplier_name,
    a.area_interna,
    a.category,
    a.fecha                                  AS anchor_date,
    a.monto_usd                              AS anchor_amount_usd,
    COUNT(b.id_factura)                      AS window_invoice_count,
    SUM(b.monto_usd)                         AS window_total_usd,
    MIN(b.fecha)                             AS window_start,
    MAX(b.fecha)                             AS window_end,
    ARRAY_AGG(
      STRUCT(b.id_factura AS fac, b.fecha AS dt, b.monto_usd AS amt)
      ORDER BY b.fecha
    )                                        AS window_facturas
  FROM invoice_base a
  JOIN invoice_base b
    ON  a.id_proveedor = b.id_proveedor
    AND a.area_interna = b.area_interna
    AND b.fecha BETWEEN DATE_SUB(a.fecha, INTERVAL 6 DAY) AND a.fecha
  GROUP BY
    a.id_factura, a.id_proveedor, a.supplier_name,
    a.area_interna, a.category, a.fecha, a.monto_usd
),
flagged AS (
  SELECT
    *,
    window_total_usd > 15000                 AS is_alert,
    CASE
      WHEN window_total_usd > 50000 THEN 'CRÍTICO'
      WHEN window_total_usd > 30000 THEN 'ALTO'
      WHEN window_total_usd > 15000 THEN 'MEDIO'
      ELSE 'OK'
    END                                      AS severity,
    GREATEST(window_total_usd - 15000, 0)    AS excedente_usd,
    ROUND(window_total_usd / 15000.0, 2)     AS bypass_ratio
  FROM rolling
)
SELECT
  -- PK determinístico
  TO_HEX(MD5(CONCAT(
    anchor_invoice,
    CAST(window_start AS STRING),
    CAST(window_end AS STRING)
  )))                                        AS alert_id,
  anchor_invoice,
  id_proveedor,
  supplier_name,
  area_interna,
  category,
  anchor_date,
  window_start,
  window_end,
  window_invoice_count,
  window_total_usd,
  anchor_amount_usd,
  excedente_usd,
  bypass_ratio,
  severity,
  window_facturas,
  CURRENT_TIMESTAMP()                        AS alert_ts
FROM flagged
WHERE is_alert = TRUE
ORDER BY window_total_usd DESC;

-- ─── Vista resumen para Looker ────────────────────────────────
CREATE OR REPLACE VIEW `naranja-x-491820.audit_procurement.split_purchase_summary` AS
SELECT
  severity,
  area_interna,
  category,
  COUNT(DISTINCT alert_id)        AS alert_count,
  COUNT(DISTINCT id_proveedor)    AS suppliers_involved,
  SUM(window_total_usd)           AS total_alerted_usd,
  SUM(excedente_usd)              AS total_excedente_usd,
  AVG(bypass_ratio)               AS avg_bypass_ratio,
  MAX(anchor_date)                AS ultima_alerta
FROM `naranja-x-491820.audit_procurement.split_purchase_alerts`
GROUP BY severity, area_interna, category
ORDER BY total_alerted_usd DESC;
