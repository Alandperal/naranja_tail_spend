# ============================================================
# FILE: fact_invoices.view.lkml
# PROJECT: naranja-x-491820 | Tail Spend Analytics
# TABLE: naranja-x-491820.mart_procurement.fact_invoices
# ============================================================

view: fact_invoices {
  sql_table_name: `naranja-x-491820.mart_procurement.fact_invoices` ;;

  # ── PK ──────────────────────────────────────────────────────
  dimension: invoice_key {
    primary_key: yes
    hidden:      yes
    type:        string
    sql:         ${TABLE}.invoice_key ;;
  }

  # ── Identificadores ─────────────────────────────────────────
  dimension: id_factura {
    label:       "ID Factura"
    type:        string
    sql:         ${TABLE}.id_factura ;;
  }

  dimension: id_proveedor {
    label:       "ID Proveedor"
    hidden:      yes
    type:        string
    sql:         ${TABLE}.id_proveedor ;;
  }

  dimension: supplier_name {
    label:       "Proveedor"
    type:        string
    sql:         ${TABLE}.supplier_name ;;
    drill_fields: [id_factura, category, area_interna, fecha_date, monto_usd]
  }

  dimension: category {
    label:       "Rubro / Categoría"
    type:        string
    sql:         ${TABLE}.category ;;
  }

  dimension: area_interna {
    label:       "Área Interna"
    type:        string
    sql:         ${TABLE}.area_interna ;;
  }

  dimension: articulos {
    label:       "SKU / Artículo"
    type:        string
    sql:         ${TABLE}.articulos ;;
  }

  dimension: periodo {
    hidden:  yes
    type:    number
    sql:     ${TABLE}.periodo ;;
  }

  # ── Fecha ────────────────────────────────────────────────────
  dimension_group: fecha {
    label:      "Fecha Factura"
    type:       time
    timeframes: [date, week, month, quarter, year, month_num]
    datatype:   date
    sql:        ${TABLE}.fecha ;;
  }

  dimension: year_month_label {
    label: "Año-Mes"
    type:  string
    sql:   ${TABLE}.year_month_label ;;
  }

  dimension: quarter_label {
    label: "Trimestre"
    type:  string
    sql:   ${TABLE}.quarter_label ;;
  }

  # ── Montos ───────────────────────────────────────────────────
  dimension: monto_usd {
    label:       "Monto USD Nominal"
    type:        number
    sql:         ${TABLE}.monto_usd ;;
    value_format: "$#,##0.00"
  }

  dimension: monto_homogeneo_usd {
    label:       "Monto USD Homogéneo (Base Feb-2026)"
    description: "Fórmula: (monto_usd × tc_periodo × (ipc_max/ipc_periodo)) / tc_base"
    type:        number
    sql:         ${TABLE}.monto_homogeneo_usd ;;
    value_format: "$#,##0.00"
  }

  dimension: sobre_umbral_15k {
    label:       "Supera USD 15k"
    description: "TRUE si monto_usd nominal > 15.000 USD (umbral compra directa)"
    type:        yesno
    sql:         ${TABLE}.monto_usd > 15000 ;;
  }

  # ── Coeficientes de moneda (para referencia) ─────────────────
  dimension: tc_periodo {
    label:       "TC ARS/USD (período)"
    hidden:      yes
    type:        number
    sql:         ${TABLE}.tc_periodo ;;
    value_format: "#,##0.00"
  }

  dimension: deflation_coeff {
    label:       "Coef. Deflación IPC"
    hidden:      yes
    type:        number
    sql:         ${TABLE}.deflation_coeff ;;
    value_format: "0.0000"
  }

  # ── Flags de calidad ─────────────────────────────────────────
  dimension: fk_valido {
    hidden: yes
    type:   yesno
    sql:    ${TABLE}.fk_valido ;;
  }

  dimension: monto_positivo {
    hidden: yes
    type:   yesno
    sql:    ${TABLE}.monto_positivo ;;
  }

  # ── MEDIDAS ──────────────────────────────────────────────────

  measure: invoice_count {
    label:       "# Facturas"
    type:        count_distinct
    sql:         ${invoice_key} ;;
    value_format: "#,##0"
    drill_fields: [id_factura, supplier_name, area_interna, fecha_date, monto_usd]
  }

  measure: supplier_count {
    label:       "# Proveedores Únicos"
    type:        count_distinct
    sql:         ${id_proveedor} ;;
    value_format: "#,##0"
    drill_fields: [id_proveedor, supplier_name, category]
  }

  measure: raw_usd_spend {
    label:       "Gasto USD Nominal"
    description: "Suma de montos en USD sin ajuste inflacionario."
    type:        sum
    sql:         ${TABLE}.monto_usd ;;
    value_format: "$#,##0"
    drill_fields: [supplier_name, area_interna, category, fecha_month, monto_usd]
  }

  measure: homogeneous_usd_spend {
    label:       "Gasto USD Homogéneo (Feb-2026)"
    description: "Suma ajustada por IPC y TC. Comparable interanualmente."
    type:        sum
    sql:         ${TABLE}.monto_homogeneo_usd ;;
    value_format: "$#,##0"
    drill_fields: [supplier_name, area_interna, category, fecha_month, monto_homogeneo_usd]
  }

  measure: avg_invoice_usd {
    label:       "Ticket Promedio USD"
    type:        average
    sql:         ${TABLE}.monto_usd ;;
    value_format: "$#,##0.00"
  }

  measure: avg_invoice_homogeneo {
    label:       "Ticket Promedio USD Homogéneo"
    type:        average
    sql:         ${TABLE}.monto_homogeneo_usd ;;
    value_format: "$#,##0.00"
  }

  measure: max_invoice_usd {
    label:       "Mayor Factura (USD)"
    type:        max
    sql:         ${TABLE}.monto_usd ;;
    value_format: "$#,##0.00"
  }

  measure: invoices_sobre_15k {
    label:       "# Facturas > USD 15k"
    description: "Facturas individuales que superan el umbral de compra directa."
    type:        count_distinct
    sql:         CASE WHEN ${TABLE}.monto_usd > 15000 THEN ${invoice_key} END ;;
    value_format: "#,##0"
  }

  measure: pct_sobre_15k {
    label:       "% Facturas > USD 15k"
    type:        number
    sql:         ${invoices_sobre_15k} / NULLIF(${invoice_count}, 0) ;;
    value_format: "0.0%"
  }

  measure: gap_nominal_vs_homogeneo {
    label:       "Gap Inflacionario (USD)"
    description: "Diferencia entre gasto homogéneo y nominal. Muestra el impacto de inflación."
    type:        number
    sql:         ${homogeneous_usd_spend} - ${raw_usd_spend} ;;
    value_format: "$#,##0"
  }
}
