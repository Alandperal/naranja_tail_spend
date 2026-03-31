# ============================================================
# FILE: audit_views.view.lkml
# PROJECT: naranja-x-491820 | Tail Spend Analytics
# Incluye: split_purchase_alerts, hhi_by_area,
#          concentration_by_area, sourcing_candidates
# ============================================================

# ─── split_purchase_alerts ───────────────────────────────────
view: split_purchase_alerts {
  sql_table_name: `naranja-x-491820.audit_procurement.split_purchase_alerts` ;;

  dimension: alert_id {
    primary_key: yes
    hidden:      yes
    type:        string
    sql:         ${TABLE}.alert_id ;;
  }

  dimension: id_proveedor {
    hidden: yes
    type:   string
    sql:    ${TABLE}.id_proveedor ;;
  }

  dimension: supplier_name {
    label: "Proveedor"
    type:  string
    sql:   ${TABLE}.supplier_name ;;
  }

  dimension: area_interna {
    label: "Área Interna"
    type:  string
    sql:   ${TABLE}.area_interna ;;
  }

  dimension: category {
    label: "Rubro"
    type:  string
    sql:   ${TABLE}.category ;;
  }

  dimension_group: anchor_date {
    label:      "Fecha Ancla"
    type:       time
    timeframes: [date, week, month, quarter, year]
    datatype:   date
    sql:        ${TABLE}.anchor_date ;;
  }

  dimension: window_total_usd {
    label:       "Total USD Ventana 7d"
    type:        number
    sql:         ${TABLE}.window_total_usd ;;
    value_format: "$#,##0.00"
  }

  dimension: excedente_usd {
    label:       "Excedente sobre USD 15k"
    type:        number
    sql:         ${TABLE}.excedente_usd ;;
    value_format: "$#,##0.00"
  }

  dimension: bypass_ratio {
    label:       "Ratio de Evasión (x veces el umbral)"
    type:        number
    sql:         ${TABLE}.bypass_ratio ;;
    value_format: "0.00x"
  }

  dimension: window_invoice_count {
    label: "# Facturas en ventana"
    type:  number
    sql:   ${TABLE}.window_invoice_count ;;
  }

  dimension: severity {
    label:       "Severidad"
    type:        string
    sql:         ${TABLE}.severity ;;
    # Semáforo HTML — el más importante de toda la solución
    html: {% if value == 'CRÍTICO' %}
            <span style="color:#fff;background:#c0392b;padding:3px 10px;border-radius:4px;font-weight:bold;letter-spacing:0.5px">🔴 {{ value }}</span>
          {% elsif value == 'ALTO' %}
            <span style="color:#fff;background:#e67e22;padding:3px 10px;border-radius:4px;font-weight:bold">🟠 {{ value }}</span>
          {% elsif value == 'MEDIO' %}
            <span style="color:#000;background:#f1c40f;padding:3px 10px;border-radius:4px;font-weight:bold">🟡 {{ value }}</span>
          {% else %}
            <span style="color:#27ae60;font-weight:bold">✓ {{ value }}</span>
          {% endif %} ;;
  }

  # ── Medidas ───────────────────────────────────────────────

  measure: alert_count {
    label:       "# Alertas Desdoblamiento"
    type:        count_distinct
    sql:         ${alert_id} ;;
    value_format: "#,##0"
    drill_fields: [supplier_name, area_interna, severity, anchor_date_date, window_total_usd, bypass_ratio]
  }

  measure: total_alerted_usd {
    label:       "Total USD bajo Alerta"
    type:        sum
    sql:         ${TABLE}.window_total_usd ;;
    value_format: "$#,##0"
  }

  measure: total_excedente_usd {
    label:       "Total Excedente USD 15k"
    type:        sum
    sql:         ${TABLE}.excedente_usd ;;
    value_format: "$#,##0"
  }

  measure: suppliers_involucrados {
    label:       "Proveedores Involucrados"
    type:        count_distinct
    sql:         ${TABLE}.id_proveedor ;;
    value_format: "#,##0"
  }

  measure: avg_bypass_ratio {
    label:       "Ratio Evasión Promedio"
    type:        average
    sql:         ${TABLE}.bypass_ratio ;;
    value_format: "0.00x"
  }
}

# ─── hhi_by_area ─────────────────────────────────────────────
view: hhi_by_area {
  sql_table_name: `naranja-x-491820.audit_procurement.hhi_by_area` ;;

  dimension: area_interna {
    primary_key: yes
    label:       "Área Interna"
    type:        string
    sql:         ${TABLE}.area_interna ;;
  }

  dimension: hhi_score {
    label:       "Índice HHI"
    description: "<1500=Competitivo · 1500-2500=Moderado · >2500=Concentrado"
    type:        number
    sql:         ${TABLE}.hhi_score ;;
    value_format: "#,##0"
    # Semáforo HHI
    html: {% if value > 2500 %}
            <span style="color:#fff;background:#c0392b;padding:3px 8px;border-radius:4px;font-weight:bold">🔴 {{ rendered_value }}</span>
          {% elsif value > 1500 %}
            <span style="color:#000;background:#f1c40f;padding:3px 8px;border-radius:4px;font-weight:bold">🟡 {{ rendered_value }}</span>
          {% else %}
            <span style="color:#fff;background:#27ae60;padding:3px 8px;border-radius:4px">🟢 {{ rendered_value }}</span>
          {% endif %} ;;
  }

  dimension: hhi_label {
    label: "Categoría HHI"
    type:  string
    sql:   ${TABLE}.hhi_label ;;
  }

  dimension: concentration_risk {
    label:       "Riesgo de Concentración"
    type:        string
    sql:         ${TABLE}.concentration_risk ;;
    html: {% if value == 'RIESGO ALTO' %}
            <span style="color:#fff;background:#c0392b;padding:2px 8px;border-radius:4px;font-weight:bold">{{ value }}</span>
          {% elsif value == 'RIESGO MEDIO' %}
            <span style="color:#000;background:#f1c40f;padding:2px 8px;border-radius:4px">{{ value }}</span>
          {% else %}
            <span style="color:#fff;background:#27ae60;padding:2px 8px;border-radius:4px">{{ value }}</span>
          {% endif %} ;;
  }

  dimension: top1_share {
    label:       "Share Proveedor #1"
    type:        number
    sql:         ${TABLE}.top1_share ;;
    value_format: "0.0%"
  }

  dimension: top1_supplier {
    label: "Proveedor #1 (dominante)"
    type:  string
    sql:   ${TABLE}.top1_supplier ;;
  }

  dimension: top5_share {
    label:       "Share Top 5 Proveedores"
    type:        number
    sql:         ${TABLE}.top5_share ;;
    value_format: "0.0%"
  }

  dimension: area_total_homogeneo {
    label:       "Gasto Total Área (USD Homogéneo)"
    type:        number
    sql:         ${TABLE}.area_total_homogeneo ;;
    value_format: "$#,##0"
  }

  measure: avg_hhi {
    label:       "HHI Promedio"
    type:        average
    sql:         ${TABLE}.hhi_score ;;
    value_format: "#,##0"
  }

  measure: areas_alto_riesgo {
    label:       "Áreas con RIESGO ALTO"
    type:        count_distinct
    sql:         CASE WHEN ${TABLE}.concentration_risk = 'RIESGO ALTO' THEN ${area_interna} END ;;
    value_format: "#,##0"
  }
}

# ─── concentration_by_area ────────────────────────────────────
view: concentration_by_area {
  sql_table_name: `naranja-x-491820.audit_procurement.concentration_by_area` ;;

  dimension: area_interna {
    label: "Área Interna"
    type:  string
    sql:   ${TABLE}.area_interna ;;
  }

  dimension: id_proveedor {
    hidden: yes
    type:   string
    sql:    ${TABLE}.id_proveedor ;;
  }

  dimension: supplier_name {
    label: "Proveedor"
    type:  string
    sql:   ${TABLE}.supplier_name ;;
  }

  dimension: category {
    label: "Rubro"
    type:  string
    sql:   ${TABLE}.category ;;
  }

  dimension: rank_area {
    label:       "Ranking en Área"
    type:        number
    sql:         ${TABLE}.rank_area ;;
  }

  dimension: share_homogeneo {
    label:       "% Gasto Área (Homogéneo)"
    type:        number
    sql:         ${TABLE}.share_homogeneo ;;
    value_format: "0.0%"
    html: {% if value > 0.60 %}
            <span style="color:#fff;background:#c0392b;padding:2px 6px;border-radius:3px;font-weight:bold">{{ rendered_value }}</span>
          {% elsif value > 0.40 %}
            <span style="color:#000;background:#f1c40f;padding:2px 6px;border-radius:3px">{{ rendered_value }}</span>
          {% else %}
            {{ rendered_value }}
          {% endif %} ;;
  }

  dimension: spend_homogeneo {
    label:       "Gasto USD Homogéneo"
    type:        number
    sql:         ${TABLE}.spend_homogeneo ;;
    value_format: "$#,##0"
  }

  dimension: flag_favoritism_40 {
    label:       "Favoritismo >40%"
    type:        yesno
    sql:         ${TABLE}.flag_favoritism_40 ;;
  }

  dimension: is_top5 {
    label:       "Es Top 5 Proveedor"
    type:        yesno
    sql:         ${TABLE}.is_top5 ;;
  }

  measure: count_favoritism {
    label:       "Áreas con Favoritismo >40%"
    type:        count_distinct
    sql:         CASE WHEN ${TABLE}.flag_favoritism_40 THEN ${area_interna} END ;;
  }
}

# ─── sourcing_candidates ─────────────────────────────────────
view: sourcing_candidates {
  sql_table_name: `naranja-x-491820.mart_procurement.sourcing_candidates` ;;

  dimension: category {
    primary_key: yes
    label:       "Categoría"
    type:        string
    sql:         ${TABLE}.category ;;
  }

  dimension: candidacy_status {
    label:       "Estado Candidatura"
    type:        string
    sql:         ${TABLE}.candidacy_status ;;
    # Semáforo candidatos
    html: {% if value == 'TOP CANDIDATO ACUERDO MARCO' %}
            <span style="color:#fff;background:#27ae60;padding:3px 8px;border-radius:4px;font-weight:bold">🎯 {{ value }}</span>
          {% elsif value == 'CANDIDATO SECUNDARIO' %}
            <span style="color:#fff;background:#2980b9;padding:3px 8px;border-radius:4px">{{ value }}</span>
          {% else %}
            <span style="color:#95a5a6">{{ value }}</span>
          {% endif %} ;;
  }

  dimension: candidate_rank {
    label:       "Ranking"
    type:        number
    sql:         ${TABLE}.candidate_rank ;;
  }

  dimension: invoice_count {
    label: "# Facturas"
    type:  number
    sql:   ${TABLE}.invoice_count ;;
    value_format: "#,##0"
  }

  dimension: distinct_suppliers {
    label: "# Proveedores Distintos"
    type:  number
    sql:   ${TABLE}.distinct_suppliers ;;
    value_format: "#,##0"
  }

  dimension: eligible {
    label:  ">20 Proveedores (elegible)"
    type:   yesno
    sql:    ${TABLE}.eligible ;;
  }

  dimension: total_homogeneo {
    label:       "Gasto Total USD Homogéneo"
    type:        number
    sql:         ${TABLE}.total_homogeneo ;;
    value_format: "$#,##0"
  }

  dimension: factibilidad {
    label:       "Factibilidad"
    type:        number
    sql:         ${TABLE}.factibilidad ;;
    value_format: "0%"
  }

  dimension: factibilidad_tier {
    label: "Tier Factibilidad"
    type:  string
    sql:   ${TABLE}.factibilidad_tier ;;
  }

  dimension: min_savings_usd {
    label:       "Savings Mín. (USD)"
    type:        number
    sql:         ${TABLE}.min_savings_usd ;;
    value_format: "$#,##0"
  }

  dimension: base_savings_usd {
    label:       "Savings Base (USD)"
    type:        number
    sql:         ${TABLE}.base_savings_usd ;;
    value_format: "$#,##0"
  }

  dimension: max_savings_usd {
    label:       "Savings Máx. (USD)"
    type:        number
    sql:         ${TABLE}.max_savings_usd ;;
    value_format: "$#,##0"
  }

  dimension: composite_score {
    label:       "Score Compuesto"
    type:        number
    sql:         ${TABLE}.composite_score ;;
    value_format: "0.000"
  }

  # ── Medidas ─────────────────────────────────────────────────

  measure: total_min_savings {
    label:       "Savings Mín. Total (Top 3)"
    type:        sum
    sql:         ${TABLE}.min_savings_usd ;;
    value_format: "$#,##0"
    filters: [candidacy_status: "TOP CANDIDATO ACUERDO MARCO"]
  }

  measure: total_base_savings {
    label:       "Savings Base Total (Top 3)"
    type:        sum
    sql:         ${TABLE}.base_savings_usd ;;
    value_format: "$#,##0"
    filters: [candidacy_status: "TOP CANDIDATO ACUERDO MARCO"]
  }

  measure: total_max_savings {
    label:       "Savings Máx. Total (Top 3)"
    type:        sum
    sql:         ${TABLE}.max_savings_usd ;;
    value_format: "$#,##0"
    filters: [candidacy_status: "TOP CANDIDATO ACUERDO MARCO"]
  }

  measure: candidate_count {
    label:       "# Candidatos Top"
    type:        count_distinct
    sql:         CASE WHEN ${TABLE}.candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'
                      THEN ${category} END ;;
    value_format: "#,##0"
  }
}
