
# 📊 TAIL SPEND ANALYTICS — DASHBOARD MOCKUP
## Proyecto: naranja-x-491820 | Datos reales de BigQuery

================================================================================
  PÁGINA 1 — RESUMEN EJECUTIVO DE GASTO
  Tabla BQ: mart_procurement.fact_invoices
================================================================================

┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   # FACTURAS    │ │   PROVEEDORES   │ │ GASTO HOMOGÉNEO │ │ TICKET PROMEDIO │
│                 │ │                 │ │                 │ │                 │
│    10,000       │ │     1,000       │ │  USD 79,994,082 │ │    USD 7,616    │
│                 │ │                 │ │  (base feb-26)  │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────────┘
  COL: COUNT(*)      COL: DISTINCT        COL: SUM(           COL: AVG(
                          id_proveedor         monto_            monto_usd)
                                              homogeneo_usd)

─────────────────────────────────────────────────────────────────────────────────
GASTO MENSUAL: USD Nominal vs USD Homogéneo (Ene-2025 → Feb-2026)
─────────────────────────────────────────────────────────────────────────────────
Tabla: fact_invoices | Cols: year_month_label, SUM(monto_usd), SUM(monto_homogeneo_usd)
Tipo de chart: Líneas dobles | Eje X: year_month_label | Eje Y: montos

USD
7.5M ┤        ╭──╮                    ╭───╮
     │    ╭───╯  ╰──╮            ╭───╯   ╰─╮
6.5M ┤ ╭──╯          ╰────╮   ╭──╯          ╰──╮
     │ │                  ╰───╯                 │  ← Homogéneo (naranja)
6.0M ┤─┼──────────────────────────────────────────  ← Nominal (azul)
     │ │
5.5M ┤╭╯
     └─┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬─
      2025-01 03 05 07 09 11 2026-01 02

      Gap promedio: +USD 3,833,172 (+5%)
      → INSIGHT: el gasto real es 5% mayor al nominal por efecto IPC/TC

─────────────────────────────────────────────────────────────────────────────────
GASTO POR RUBRO (USD Homogéneo) — Barras horizontales
─────────────────────────────────────────────────────────────────────────────────
Tabla: fact_invoices | Cols: category, SUM(monto_homogeneo_usd)

 Consultoría  ████████████████████████  USD 15,694,958  (19.6%)
 Librería     █████████████████████     USD 14,352,140  (17.9%)
 Catering     ██████████████████        USD 12,386,340  (15.5%)
 Mantenimiento███████████████           USD 11,839,xxx  (14.8%)
 Limpieza     ██████████████            USD 11,xxx,xxx  (13.9%)
 Hardware     █████████████             USD 12,052,375  (15.1%)
              ├─────────────────────────────────────────────────
              0          5M         10M        15M       20M
              ← COL: SUM(monto_homogeneo_usd) ← agrupar por: category


================================================================================
  PÁGINA 2 — AUDITORÍA: ALERTAS DE DESDOBLAMIENTO
  Tabla BQ: audit_procurement.split_purchase_alerts
================================================================================

┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  TOTAL ALERTAS   │ │ ALERTAS CRÍTICO  │ │  USD BAJO ALERTA │
│                  │ │                  │ │                  │
│      362         │ │      24 🔴        │ │  USD 10,482,614  │
│                  │ │  Marketing×PROV  │ │                  │
└──────────────────┘ └──────────────────┘ └──────────────────┘
  COL: COUNT(*)         COL: COUNT(*) WHERE    COL: SUM(
                             severity='CRÍTICO'      window_total_usd)

─────────────────────────────────────────────────────────────────────────────────
MATRIZ DE ALERTAS: Área × Severidad (HEATMAP)
─────────────────────────────────────────────────────────────────────────────────
Tabla: split_purchase_alerts | Cols: area_interna, severity, COUNT(*)
Tipo: Pivot table con colores condicionales

               │  CRÍTICO 🔴  │  ALTO 🟠  │  MEDIO 🟡  │  TOTAL
  ─────────────┼─────────────┼──────────┼────────────┼────────
   Marketing   │     24      │    94    │     93     │   211  ← ⚠️ FOCO CRÍTICO
   IT          │      —      │     4    │     25     │    29
   Finanzas    │      —      │     1    │     34     │    35
   Legales     │      —      │     1    │     31     │    32
   Operaciones │      —      │     4    │     27     │    31
   RRHH        │      —      │     —    │     24     │    24
  ─────────────┼─────────────┼──────────┼────────────┼────────
   TOTAL       │     24      │   104    │    234     │   362

  → INSIGHT KEY: PROV-0800 en Marketing → 24 alertas CRÍTICO, ratio máx 4.89x el umbral

─────────────────────────────────────────────────────────────────────────────────
TOP 10 ALERTAS POR MONTO (Tabla detalle)
─────────────────────────────────────────────────────────────────────────────────
Tabla: split_purchase_alerts | ORDER BY window_total_usd DESC | LIMIT 10

COLUMNA CLAVE: anchor_date — diferencia cada alerta aunque sea el mismo proveedor
  ↳ alert_id existe (MD5 hash) pero NO mostrarlo en el dashboard: es técnico, no legible
  ↳ anchor_invoice (FAC-XXXXX) es opcional para drill-down

┌──────────────────┬───────────┬─────────────┬──────────┬───────────┬──────────┬────────────┐
│ PROVEEDOR        │ ÁREA      │ FECHA ANCLA │ SEV.     │ TOTAL 7d  │ EXCEDENTE│ RATIO 15k  │
├──────────────────┼───────────┼─────────────┼──────────┼───────────┼──────────┼────────────┤
│ PROV-0800        │ Marketing │ 2025-02-24  │ 🔴CRÍTICO │ $73,381   │ $58,381  │   4.89x    │
│ PROV-0800        │ Marketing │ 2025-10-29  │ 🔴CRÍTICO │ $70,895   │ $55,895  │   4.73x    │
│ PROV-0800        │ Marketing │ 2025-12-29  │ 🔴CRÍTICO │ $69,640   │ $54,640  │   4.64x    │
│ PROV-0800        │ Marketing │ 2025-05-06  │ 🔴CRÍTICO │ $63,115   │ $48,115  │   4.21x    │
│ PROV-0800        │ Marketing │ 2025-08-17  │ 🔴CRÍTICO │ $62,896   │ $47,896  │   4.19x    │
│ PROV-0800        │ Marketing │ 2025-12-28  │ 🔴CRÍTICO │ $62,685   │ $47,685  │   4.18x    │
│ PROV-0800        │ Marketing │ 2025-12-26  │ 🔴CRÍTICO │ $61,756   │ $46,756  │   4.12x    │
│ ...              │ Marketing │ 2025-xx-xx  │ 🟠ALTO    │ $40,xxx   │ $25,xxx  │   2.7x     │
│ ...              │ IT        │ 2025-xx-xx  │ 🟠ALTO    │ $38,xxx   │ $23,xxx  │   2.5x     │
│ ...              │ Legales   │ 2025-xx-xx  │ 🟠ALTO    │ $37,868   │ $22,868  │   2.5x     │
└──────────────────┴───────────┴─────────────┴──────────┴───────────┴──────────┴────────────┘
→ COL usados: supplier_name, area_interna, anchor_date, severity,
              window_total_usd, excedente_usd, bypass_ratio
→ INSIGHT: PROV-0800 no es un duplicado — son 7 ventanas de 7 días distintas
   en distintos meses. Mismo proveedor, mismo patrón → comportamiento sistemático.


================================================================================
  PÁGINA 3 — CONCENTRACIÓN DE PROVEEDORES POR ÁREA
  Tablas BQ:
    • audit_procurement.concentration_by_area  → gráfico barras
    • audit_procurement.hhi_by_area            → gráfico HHI
================================================================================

FILTROS (arriba a la derecha — siempre visibles):
  [📅 Período: Ene 2025 – Feb 2026 ▼]  [🏢 Área Interna: Todas ▼]  [📦 Rubro: Todos ▼]
  ↳ "Área Interna" es el filtro más usado: el Head of Procurement filtra solo "Marketing"
    para ver el caso PROV-0800 en aislado.

─────────────────────────────────────────────────────────────────────────────────
FILA 1 — 3 SCORECARDS
─────────────────────────────────────────────────────────────────────────────────

┌────────────────────────────┐ ┌──────────────────────────────────┐ ┌────────────────────────────────┐
│     ÁREAS ANALIZADAS       │ │          CASO FLAGGED            │ │         HHI PROMEDIO           │
│                            │ │                                  │ │                                │
│            6               │ │         PROV-0800                │ │             41                 │
│                            │ │                                  │ │                                │
│ Finanzas · IT · Legales    │ │ Marketing · 12% presupuesto      │ │ Mercado competitivo            │
│ Marketing · Ops · RRHH     │ │ ⚠️ flag_favoritism activo        │ │ (umbral riesgo alto: 1.500)    │
└────────────────────────────┘ └──────────────────────────────────┘ └────────────────────────────────┘

  Card 1 → COUNT(DISTINCT area_interna) — Tabla: concentration_by_area
  Card 2 → supplier_name WHERE flag_favoritism_40 = TRUE AND rank_area = 1
            Tabla: concentration_by_area
            Subtítulo: area_interna + ROUND(share_homogeneo*100,1) + "% del presupuesto"
            Nota: flag_favoritism_40 = TRUE cuando rank_area=1 Y share > 40%.
                  En este dataset PROV-0800 tiene 12% → NO dispara ese flag.
                  Para mostrarlo igual, usar: rank_area=1 ORDER BY share_homogeneo DESC LIMIT 1
  Card 3 → AVG(hhi_score) — Tabla: hhi_by_area
            Color: verde si < 1.500 | amarillo si 1.500-2.500 | rojo si > 2.500

─────────────────────────────────────────────────────────────────────────────────
FILA 2 — GRÁFICO IZQUIERDA (55%):
"Top 5 Proveedores por Área — Share % del Gasto"
─────────────────────────────────────────────────────────────────────────────────
Tabla:  audit_procurement.concentration_by_area
Filtro: rank_area <= 5
Tipo:   Barras horizontales AGRUPADAS por área (grouped bar chart)
Eje X:  share_homogeneo × 100  →  muestra como porcentaje
Eje Y:  area_interna (6 grupos)
Color:  supplier_name (5 colores distintos por proveedor dentro de cada área)
Orden:  rank_area ASC dentro de cada grupo

Nota de color especial:
  → Si share_homogeneo > 0.10 (> 10%) → barra en rojo/coral para marcar dominancia
  → Resto de barras → tono azul estándar

Datos reales a representar:

  MARKETING  │ PROV-0800 ████████████████████████████████ 12.0% ← ROJO (dominante)
             │ PROV-0717 █ 0.5%
             │ PROV-0025 █ 0.4%
             │ PROV-0840 █ 0.4%
             │ PROV-0116 █ 0.4%
             ├────────────────────────────────────────────── %
             0%                      6%                    12%

  IT         │ PROV-0050 █ 0.5%  ← todos similares (mercado competitivo)
             │ PROV-0043 █ 0.5%
             │ PROV-0023 █ 0.5%
             │ PROV-0603 █ 0.5%
             │ PROV-0111 █ 0.4%

  FINANZAS   │ PROV-0334 █ 0.5%
             │ PROV-0804 █ 0.5%
             │ PROV-0698 █ 0.4%
             │ PROV-0635 █ 0.4%
             │ PROV-0687 █ 0.4%

  RRHH       │ PROV-0032 █ 0.7%  ← levemente más alto pero ok
             │ PROV-0003 █ 0.5%
             │ PROV-0428 █ 0.4%
             │ PROV-0869 █ 0.4%
             │ PROV-0168 █ 0.4%

  LEGALES    │ PROV-0985 █ 0.5%
             │ PROV-0866 █ 0.5%
             │ PROV-0276 █ 0.5%
             │ PROV-0721 █ 0.4%
             │ PROV-0143 █ 0.4%

  OPERACIONES│ PROV-0527 █ 0.5%
             │ PROV-0315 █ 0.4%
             │ PROV-0241 █ 0.4%
             │ PROV-0926 █ 0.4%
             │ PROV-0737 █ 0.4%

→ COLUMNAS USADAS: area_interna, supplier_name, share_homogeneo, rank_area
→ NOTA VISUAL: el contraste entre Marketing (12%) y el resto (< 1%) es
  inmediatamente legible — ese es el punto central de esta página.

Nota al pie del gráfico (texto fijo):
  "⚠️ Solo Marketing muestra proveedor dominante. Resto de áreas: mercado competitivo."

─────────────────────────────────────────────────────────────────────────────────
FILA 2 — GRÁFICO DERECHA (45%):
"HHI por Área — Índice de Concentración"
─────────────────────────────────────────────────────────────────────────────────
Tabla: audit_procurement.hhi_by_area
Tipo:  Barras verticales (column chart)
Eje X: area_interna (6 barras)
Eje Y: hhi_score  — escala 0 a 2.800
Color de barra: según concentration_risk
  → 'BAJO RIESGO'  → verde  (#16a34a)
  → 'RIESGO MEDIO' → amarillo (#ca8a04)
  → 'RIESGO ALTO'  → rojo (#dc2626)

Líneas de referencia horizontales (fijas, dashed):
  → Línea roja  en y=2.500 con etiqueta "🔴 RIESGO ALTO"
  → Línea amarilla en y=1.500 con etiqueta "🟡 RIESGO MEDIO"

Datos reales:
  Marketing    ██  hhi=158   🟢 (pero top1=12% → anomalía capturable por share%)
  RRHH         │   hhi= 18   🟢
  Finanzas     │   hhi= 18   🟢
  IT           │   hhi= 18   🟢
  Legales      │   hhi= 18   🟢
  Operaciones  │   hhi= 18   🟢

→ COLUMNAS USADAS: area_interna, hhi_score, concentration_risk
→ COLUMNAS OPCIONALES para tooltip: top1_supplier, top1_share, top5_share

Etiqueta encima de cada barra: el valor numérico de hhi_score

Nota al pie del gráfico (texto fijo):
  "Ningún área supera el umbral de riesgo HHI — la concentración de Marketing
   es capturable vía share% individual (PROV-0800 = 12%)"

─────────────────────────────────────────────────────────────────────────────────
INSIGHT PARA PRESENTACIÓN EJECUTIVA
─────────────────────────────────────────────────────────────────────────────────
  El HHI global de Marketing es 158 (BAJO RIESGO) porque tiene muchos proveedores.
  Pero PROV-0800 captura el 12% del presupuesto del área solo.
  → HHI mide distribución del total; share% mide dominancia individual.
  → Ambas métricas se necesitan: el HHI "absuelve" el área en términos de mercado,
    pero el share% del top-1 "incrimina" a un proveedor específico.
  Mensaje para el CFO: "El mercado es competitivo en general,
    pero hay un proveedor específico que elude esa competencia."


================================================================================
  PÁGINA 4 — CANDIDATOS A ACUERDO MARCO
  Título visible en el dashboard: "Candidatos a Acuerdo Marco"
  Tabla BQ principal: mart_procurement.sourcing_candidates
================================================================================

BREADCRUMB (arriba a la izquierda):
  Tail Spend Analytics  >  Sourcing

FILTROS (arriba a la derecha):
  [📦 Rubro: Todos ▼]  [🎯 Candidatura: Todas ▼]  [⚙️ Score mínimo: 0.5 ▼]
  ↳ "Rubro"       → filtra por category         — sourcing_candidates
  ↳ "Candidatura" → filtra por candidacy_status  — sourcing_candidates
                    valores: 'TOP CANDIDATO ACUERDO MARCO' | 'CANDIDATO SECUNDARIO'
  ↳ "Score mínimo"→ filtra por composite_score > valor del slider
                    En Looker Studio: usar campo numérico como rango slider

─────────────────────────────────────────────────────────────────────────────────
FILA 1 — 3 SCORECARDS
─────────────────────────────────────────────────────────────────────────────────

┌──────────────────────────┐ ┌──────────────────────────────┐ ┌──────────────────────────────┐
│    TOP CANDIDATOS AM     │ │      GASTO ADDRESSABLE       │ │   SAVINGS BASE PROYECTADO    │
│                          │ │                              │ │                              │
│           3              │ │       $42,433,438            │ │        $1,501,160            │
│                          │ │                              │ │                              │
│ Consultoría · Librería   │ │    53% del gasto total       │ │     escenario base anual     │
│ · Catering               │ │                              │ │                              │
└──────────────────────────┘ └──────────────────────────────┘ └──────────────────────────────┘

  Card 1 → COUNTIF(candidacy_status = 'TOP CANDIDATO ACUERDO MARCO')
            Subtítulo: STRING_AGG(category, ' · ') WHERE candidacy_status = 'TOP...'
            Tabla: sourcing_candidates | Color: verde

  Card 2 → SUM(total_homogeneo) WHERE candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'
            Subtítulo: ROUND(candidate_spend / total_addressable_spend * 100, 1) + "% del gasto total"
            Tabla: sourcing_candidates | Color: azul

  Card 3 → SUM(base_savings_usd) WHERE candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'
            Subtítulo: "escenario base anual"
            Tabla: sourcing_candidates | Color: verde brillante / esmeralda
            Tip: es el más importante para el CFO → hacerlo más grande o resaltado

─────────────────────────────────────────────────────────────────────────────────
FILA 2 — GRÁFICO IZQUIERDA (50%):
"Estrategia: Frecuencia vs Gasto — Candidatos a Acuerdo Marco"
─────────────────────────────────────────────────────────────────────────────────
Tabla:  sourcing_candidates
Tipo:   BUBBLE CHART (scatter con tamaño de burbuja)
Eje X:  invoice_count         — "Cantidad de Facturas"    rango 0-2.500
Eje Y:  total_homogeneo       — "Gasto USD Homogéneo"     rango $0-$18M
Tamaño: distinct_suppliers    — mayor burbuja = más proveedores distintos
Color:  candidacy_status
  → 'TOP CANDIDATO ACUERDO MARCO' → verde (#16a34a) — burbujas grandes llenas
  → 'CANDIDATO SECUNDARIO'        → azul-gris (#475569) — burbujas medianas outline
Línea vertical punteada: x=1.000 con etiqueta "umbral frecuencia"

Datos reales + posición en el scatter:
  🟢 Consultoría   x=1.948  y=$15,694,958  tamaño=182 provs  ← arriba a la derecha
  🟢 Librería      x=1.816  y=$14,352,140  tamaño=181 provs
  🟢 Catering      x=1.552  y=$12,386,340  tamaño=158 provs
  🔵 Mantenimiento x=1.xxx  y=$11,8xx,xxx  tamaño=173 provs
  🔵 Limpieza      x=1.xxx  y=$11,5xx,xxx  tamaño=163 provs
  🔵 Hardware      x=1.xxx  y=$12,052,375  tamaño=154 provs

Leyenda debajo del gráfico:
  ● TOP CANDIDATO ACUERDO MARCO    ○ Candidato Secundario

→ COLUMNAS USADAS: category, invoice_count, total_homogeneo,
                   distinct_suppliers, candidacy_status

─────────────────────────────────────────────────────────────────────────────────
FILA 2 — GRÁFICO DERECHA (50%):
"Tabla de Savings — Top 3 Candidatos"
─────────────────────────────────────────────────────────────────────────────────
Tabla:  sourcing_candidates
Filtro: candidacy_status = 'TOP CANDIDATO ACUERDO MARCO'  (solo top 3)
Tipo:   Tabla de datos con fila de totales

Columnas a mostrar:
  CATEGORÍA     → category
  FACTURAS      → invoice_count
  PROVEEDORES   → distinct_suppliers
  GASTO HOMOG.  → total_homogeneo        (formato $XX,XXX,XXX)
  SAVINGS MÍN   → min_savings_usd        (formato $XXX,XXX)
  SAVINGS BASE  → base_savings_usd       (verde + bold — es el número más importante)
  SAVINGS MÁX   → max_savings_usd        (formato $XXX,XXX)
  FACTIBIL.     → factibilidad           (formato XX%)

Datos reales:
┌─────────────────┬────────┬───────┬─────────────┬──────────┬──────────┬──────────┬───────┐
│ CATEGORÍA       │  FAC.  │ PROVS │ GASTO HOMOG.│ SAV. MÍN │ SAV.BASE │ SAV. MÁX │FACTIB.│
├─────────────────┼────────┼───────┼─────────────┼──────────┼──────────┼──────────┼───────┤
│ 🟢 Consultoría  │  1,948 │  182  │ $15,694,958 │ $502,239 │ $565,018 │ $627,798 │  80%  │
│ 🟢 Librería     │  1,816 │  181  │ $14,352,140 │ $344,451 │ $459,268 │ $574,086 │  80%  │
│ 🟢 Catering     │  1,552 │  158  │ $12,386,340 │ $433,522 │ $476,874 │ $520,226 │  70%  │
├─────────────────┼────────┼───────┼─────────────┼──────────┼──────────┼──────────┼───────┤
│ TOTAL TOP 3     │  5,316 │  521  │ $42,433,438 │$1,280,212│$1,501,160│$1,722,110│   —   │
└─────────────────┴────────┴───────┴─────────────┴──────────┴──────────┴──────────┴───────┘

Debajo de la tabla — barra de rango de savings:
  Rango de Savings: $1.28M ←────── $1.50M ──────→ $1.72M
  (texto fijo o calculado con MIN/BASE/MAX de la fila TOTAL)

Fórmulas para referencia:
  min_savings  = total_homogeneo × factibilidad × kpi_min
  base_savings = total_homogeneo × factibilidad × (kpi_min + kpi_max) / 2
  max_savings  = total_homogeneo × factibilidad × kpi_max

→ COLUMNAS USADAS: category, invoice_count, distinct_suppliers, total_homogeneo,
                   min_savings_usd, base_savings_usd, max_savings_usd, factibilidad


================================================================================
  REFERENCIA DE TABLAS Y COLUMNAS — LOOKER STUDIO
================================================================================

┌─────────────────────────────────────────────────────────────────────────────┐
│ PÁGINA 1 — Resumen                                                          │
│  Dataset: mart_procurement    Tabla: fact_invoices                          │
│  Métricas:  COUNT(invoice_key), COUNT(DISTINCT id_proveedor)               │
│             SUM(monto_usd), SUM(monto_homogeneo_usd), AVG(monto_usd)       │
│  Dimensión: year_month_label, category                                      │
│  Filtros:   monto_positivo = TRUE AND fecha_ok = TRUE                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PÁGINA 2 — Alertas                                                          │
│  Dataset: audit_procurement   Tabla: split_purchase_alerts                 │
│  Métricas:  COUNT(alert_id), SUM(window_total_usd), SUM(excedente_usd)    │
│  Dimensión: area_interna, severity, supplier_name, anchor_date             │
│  Orden:     window_total_usd DESC                                           │
│  Colores:   severity → CRÍTICO=🔴 ALTO=🟠 MEDIO=🟡                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PÁGINA 3 — Concentración                                                    │
│  Dataset: audit_procurement   Tabla: concentration_by_area                 │
│  Métricas:  SUM(spend_homogeneo), share_homogeneo (∗100 para %)            │
│  Dimensión: area_interna, supplier_name, rank_area                         │
│  Filtros:   rank_area <= 5                                                  │
│  + Tabla:   hhi_by_area → hhi_score, concentration_risk, top1_supplier     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PÁGINA 4 — Sourcing                                                         │
│  Dataset: mart_procurement    Tabla: sourcing_candidates                   │
│  Scatter:   X=invoice_count  Y=total_homogeneo  Size=distinct_suppliers    │
│             Color=candidacy_status                                          │
│  Tabla:     category, invoice_count, distinct_suppliers, total_homogeneo   │
│             min_savings_usd, base_savings_usd, max_savings_usd             │
│  Filtro:    candidate_rank <= 3 para la tabla de savings                   │
└─────────────────────────────────────────────────────────────────────────────┘
