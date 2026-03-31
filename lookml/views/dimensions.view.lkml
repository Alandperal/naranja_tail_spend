# ============================================================
# FILE: dimensions.view.lkml
# PROJECT: naranja-x-491820 | Tail Spend Analytics
# Incluye: dim_suppliers, dim_categories, dim_areas, dim_time
# ============================================================

view: dim_suppliers {
  sql_table_name: `naranja-x-491820.mart_procurement.dim_suppliers` ;;

  dimension: supplier_key {
    primary_key: yes
    hidden:      yes
    type:        string
    sql:         ${TABLE}.supplier_key ;;
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

  dimension: cuit {
    label: "CUIT"
    type:  string
    sql:   ${TABLE}.cuit ;;
  }

  dimension: category {
    label: "Rubro"
    type:  string
    sql:   ${TABLE}.category ;;
  }

  dimension: provincia {
    label: "Provincia"
    type:  string
    sql:   ${TABLE}.provincia ;;
  }

  dimension: cuit_valido {
    label:  "CUIT Formato Válido"
    hidden: yes
    type:   yesno
    sql:    ${TABLE}.cuit_valido ;;
  }

  measure: count {
    label: "# Proveedores"
    type:  count_distinct
    sql:   ${supplier_key} ;;
  }
}

# ─────────────────────────────────────────────────────────────

view: dim_categories {
  sql_table_name: `naranja-x-491820.mart_procurement.dim_categories` ;;

  dimension: category {
    primary_key: yes
    label:       "Categoría / Rubro"
    type:        string
    sql:         ${TABLE}.category ;;
  }

  dimension: supplier_count {
    label:       "# Proveedores en Categoría"
    type:        number
    sql:         ${TABLE}.supplier_count ;;
  }

  dimension: factibilidad {
    label:       "Factibilidad"
    type:        number
    sql:         ${TABLE}.factibilidad ;;
    value_format: "0.00"
  }

  dimension: factibilidad_tier {
    label:       "Tier Factibilidad"
    type:        string
    sql:         ${TABLE}.factibilidad_tier ;;
    # Semáforo HTML para tier de factibilidad
    html: {% if value == 'Éxito Asegurado' %}
            <span style="color:#fff;background:#27ae60;padding:2px 7px;border-radius:4px;font-weight:bold">{{ value }}</span>
          {% elsif value == 'Alta Probabilidad' %}
            <span style="color:#fff;background:#2980b9;padding:2px 7px;border-radius:4px">{{ value }}</span>
          {% elsif value == 'Dificultad Media-Alta' %}
            <span style="color:#fff;background:#e67e22;padding:2px 7px;border-radius:4px">{{ value }}</span>
          {% elsif value == 'Bloqueado' %}
            <span style="color:#fff;background:#c0392b;padding:2px 7px;border-radius:4px;font-weight:bold">{{ value }}</span>
          {% else %}
            {{ value }}
          {% endif %} ;;
  }

  dimension: kpi_min {
    label:       "KPI Savings Mín."
    type:        number
    sql:         ${TABLE}.kpi_min ;;
    value_format: "0.0%"
  }

  dimension: kpi_max {
    label:       "KPI Savings Máx."
    type:        number
    sql:         ${TABLE}.kpi_max ;;
    value_format: "0.0%"
  }

  dimension: tiene_savings_proy {
    label:  "Con Proyección de Savings"
    type:   yesno
    sql:    ${TABLE}.tiene_savings_proy ;;
  }
}

# ─────────────────────────────────────────────────────────────

view: dim_areas {
  sql_table_name: `naranja-x-491820.mart_procurement.dim_areas` ;;

  dimension: area_interna {
    primary_key: yes
    label:       "Área Interna"
    type:        string
    sql:         ${TABLE}.area_interna ;;
  }

  measure: count {
    label: "# Áreas"
    type:  count_distinct
    sql:   ${area_interna} ;;
  }
}

# ─────────────────────────────────────────────────────────────

view: dim_time {
  sql_table_name: `naranja-x-491820.mart_procurement.dim_time` ;;

  dimension: periodo {
    primary_key: yes
    hidden:      yes
    type:        number
    sql:         ${TABLE}.periodo ;;
  }

  dimension_group: month {
    label:      "Mes"
    type:       time
    timeframes: [date, month, quarter, year]
    datatype:   date
    sql:        ${TABLE}.month_date ;;
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

  dimension: ipc {
    label:       "Índice IPC"
    type:        number
    sql:         ${TABLE}.ipc ;;
    value_format: "#,##0.00"
  }

  dimension: deflation_coeff {
    label:       "Coef. Deflación IPC"
    description: "ipc_max / ipc_periodo. Valor > 1 para períodos anteriores al base."
    type:        number
    sql:         ${TABLE}.deflation_coeff ;;
    value_format: "0.0000"
  }

  dimension: tc_periodo {
    label:       "Tipo de Cambio ARS/USD"
    type:        number
    sql:         ${TABLE}.tc_periodo ;;
    value_format: "#,##0.00"
  }
}
