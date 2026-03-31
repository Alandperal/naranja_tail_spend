# ============================================================
# FILE: tail_spend.model.lkml
# PROJECT: naranja-x-491820 | Tail Spend Analytics
# ============================================================

connection: "naranja_x"   # ← nombre de la conexión en Looker (ajustar si difiere)

include: "/views/*.view.lkml"

fiscal_month_offset: 0   # Argentina: año fiscal = año calendario

# ── Explore 1: Gasto principal ────────────────────────────────
explore: fact_invoices {
  label:       "📊 Análisis de Gasto"
  description: "Facturas, proveedores y moneda homogénea. Base del análisis de tail spend."
  group_label: "Tail Spend — naranja-x-491820"

  join: dim_suppliers {
    type:         left_outer
    relationship: many_to_one
    sql_on:       ${fact_invoices.id_proveedor} = ${dim_suppliers.id_proveedor} ;;
  }

  join: dim_categories {
    type:         left_outer
    relationship: many_to_one
    sql_on:       ${fact_invoices.category} = ${dim_categories.category} ;;
  }

  join: dim_areas {
    type:         left_outer
    relationship: many_to_one
    sql_on:       ${fact_invoices.area_interna} = ${dim_areas.area_interna} ;;
  }

  join: dim_time {
    type:         left_outer
    relationship: many_to_one
    sql_on:       ${fact_invoices.periodo} = ${dim_time.periodo} ;;
  }
}

# ── Explore 2: Alertas desdoblamiento ────────────────────────
explore: split_purchase_alerts {
  label:       "⚠️ Alertas Split Purchasing"
  description: "Casos de desdoblamiento: mismo proveedor+área >USD 15k en 7 días."
  group_label: "Auditoría — naranja-x-491820"

  join: dim_suppliers {
    type:         left_outer
    relationship: many_to_one
    sql_on:       ${split_purchase_alerts.id_proveedor} = ${dim_suppliers.id_proveedor} ;;
    fields:       [dim_suppliers.supplier_name, dim_suppliers.cuit,
                   dim_suppliers.provincia, dim_suppliers.category]
  }
}

# ── Explore 3: Concentración por área ────────────────────────
explore: concentration_by_area {
  label:       "🔍 Concentración de Proveedores"
  description: "Share% y ranking de proveedores por área interna."
  group_label: "Auditoría — naranja-x-491820"

  join: dim_suppliers {
    type:         left_outer
    relationship: many_to_one
    sql_on:       ${concentration_by_area.id_proveedor} = ${dim_suppliers.id_proveedor} ;;
    fields:       [dim_suppliers.supplier_name, dim_suppliers.cuit, dim_suppliers.provincia]
  }
}

# ── Explore 4: HHI por área ───────────────────────────────────
explore: hhi_by_area {
  label:       "📐 Índice HHI por Área"
  description: "Herfindahl-Hirschman Index de concentración. <1500=OK, >2500=Riesgo."
  group_label: "Auditoría — naranja-x-491820"
}

# ── Explore 5: Candidatos acuerdo marco ──────────────────────
explore: sourcing_candidates {
  label:       "🎯 Candidatos Acuerdo Marco"
  description: "Categorías candidatas con savings estimados min/base/max."
  group_label: "Sourcing — naranja-x-491820"
}
