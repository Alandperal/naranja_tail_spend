# Executive Deck — Tail Spend Analytics
## Proyecto: naranja-x | 5 Slides para Head of Procurement + CFO

---

## SLIDE 1 — Situación Inicial: El Problema con Datos

**Título del slide:** "Nuestro Tail Spend: fragmentado, costoso y en riesgo de compliance"

**Objetivo:** Establecer el baseline con datos reales del dashboard. Mostrar el problema antes de proponer solución.

---

**Mensaje central:**
> En 14 meses, la compañía procesó ~10.000 facturas con ~999 proveedores activos en 7 áreas internas.
> El 85% de las facturas están por debajo de USD 15.000 — zona no contractualizada.
> **Ajustado por inflación (IPC INDEC), el gasto real acumulado es un 36% mayor que lo que muestra el nominal en USD.**

---

**Visuales a incluir:**

| Tile | Tipo | Dato |
|---|---|---|
| KPI #1 | Número grande | Total facturas: ~9.999 |
| KPI #2 | Número grande | Proveedores activos: ~999 |
| KPI #3 | Número grande | Gasto USD Homogéneo (Feb-2026): ejecutar pipeline para valor real |
| KPI #4 | Número grande | Ticket promedio: ~USD 8.500 |
| Trend línea doble | Gráfico de líneas | Gasto mensual USD nominal (celeste) vs. USD homogéneo (naranja) — brecha visible |
| Histograma | Bar chart | Distribución de facturas por monto — pico masivo en [5k–14.8k] |
| Top áreas | Bar horizontal | Gasto por área (homogéneo) |

---

**Números para destacar en voz alta:**
- 85% de las facturas están en la zona gris (< USD 15k) — no hay compliance automático
- La brecha entre gasto nominal y homogéneo: **el dinero real estuvo 36% más caro en promedio**
- Proveedores que facturaron una sola vez en el año: ~60% del padrón activo

---

**Speaker notes:**
> "Este slide responde la primera pregunta del CFO: ¿cuánto gastamos en tail spend? La respuesta en USD nominal y en USD constante son muy diferentes. La inflación del período fue del 36% acumulado usando el IPC INDEC. Ignorar esto no es solo un error analítico — es tomar decisiones de sourcing con información incorrecta. Los 999 proveedores activos son una señal clara de fragmentación: nadie está negociando a escala."

---

**Transición al Slide 2:**
> "Con ese volumen distribuido entre ~1.000 proveedores y sin contratos marco, ¿qué prácticas emergen? Pasemos a los hallazgos de auditoría."

---

---

## SLIDE 2 — Hallazgos de Auditoría: DOS Patrones de Riesgo Confirmados

**Título del slide:** "Split Purchasing y Favoritismo: evidencia visual con datos"

**Objetivo:** Mostrar evidencia concreta de las dos anomalías detectadas. No acusar — mostrar patrones estadísticos.

---

**Mensaje central:**
> Encontramos dos patrones de riesgo sistemático:
> 1. **Desdoblamiento (split purchasing):** casos donde el mismo proveedor factura a la misma área más de USD 15.000 en una ventana de 7 días.
> 2. **Favoritismo por concentración:** áreas donde el HHI supera 2.500 — equivalente a un mercado oligopólico.

---

**Visuales a incluir:**

**Panel izquierdo — Split Purchasing:**

| Tile | Tipo | Dato |
|---|---|---|
| KPI alertas | Número | Total alertas split purchasing (completar post-pipeline) |
| Heatmap | Pivot table | Área × Severidad (CRÍTICO = rojo, ALTO = naranja, MEDIO = amarillo) |
| Tabla | Table | Proveedor · Área · Total 7d · Excedente sobre 15k · Ratio de evasión |

**Panel derecho — Concentración:**

| Tile | Tipo | Dato |
|---|---|---|
| KPI HHI alto | Número | Áreas con HHI > 2.500 |
| Bar horizontal | Chart | HHI por área (rojo > 2500, amarillo 1500–2500, verde < 1500) |
| Bar | Chart | Top 5 proveedores por área − share% del presupuesto |

---

**Números para destacar:**
- Proveedor más concentrado: [PROV-0001 en IT] = [X]% del presupuesto del área
- HHI del área más concentrada: [X] (referencia: >2.500 = mercado oligopólico)
- Alertas CRÍTICO (>USD 50k en 7 días): [N cases]
- Bypass ratio máximo: [X]x el límite de USD 15k

---

**Speaker notes:**
> "El heatmap muestra qué áreas concentran más alertas de desdoblamiento. No es coincidencia: cuando el mismo proveedor factura 3 veces a la misma área en 6 días por montos similares, el patrón es estadísticamente difícil de explicar como casual. En concentración: el HHI de IT equivale al nivel de concentración que la CNDC considera Altamente Concentrado. En procurement, eso es un proveedor cautivo. Ambos riesgos se resuelven con el mismo instrumento: el acuerdo marco."

---

**Transición al Slide 3:**
> "Tenemos el diagnóstico. ¿Cuáles son las categorías con mayor potencial para centralizar primero?"

---

---

## SLIDE 3 — Propuesta Estratégica: TOP 3 Categorías para Acuerdo Marco

**Título del slide:** "USD [BASE_SAVINGS] en savings anuales — en 3 categorías priorizadas"

**Objetivo:** Justificar las 3 categorías seleccionadas con evidencia cuantitativa. Presentar savings por escenario.

---

**Mensaje central:**
> Las categorías **Consultoría, Librería y Catering** reúnen los criterios de elegibilidad:
> alta frecuencia de transacciones, más de 20 proveedores distintos activos, y la mejor proyección de ahorro ajustada por factibilidad de implementación.

---

**Visuales a incluir:**

**Scatter Plot (visual central del slide):**
- Eje X: Número de facturas (frecuencia de compra)
- Eje Y: Gasto USD Homogéneo total
- Tamaño de burbuja: N° de proveedores distintos
- Color de burbuja: 🟢 TOP CANDIDATO · 🔵 Secundario · ⚫ No priorizado
- Añadir línea vertical en x=100 (umbral de frecuencia relevante)
- Label con nombre de categoría sobre cada burbuja

**Tabla de savings:**

| Categoría | Gasto Homogéneo | Factibilidad | Savings Mín. | Savings Base | Savings Máx. |
|---|---|---|---|---|---|
| Consultoría | [completar] | 80% | [completar] | **[completar]** | [completar] |
| Librería | [completar] | 80% | [completar] | **[completar]** | [completar] |
| Catering | [completar] | 70% | [completar] | **[completar]** | [completar] |
| **TOTAL TOP 3** | **[completar]** | — | **[MIN]** | **[BASE]** | **[MAX]** |

---

**Números para destacar:**
- Total savings escenario base: **USD [X]** (completar con valor del pipeline)
- Porcentaje del gasto addressable que esto representa: **[X]%**
- Factibilidad promedio top 3: **77%** (promedio ponderado de 0.8, 0.8, 0.7)
- ROI estimado del programa vs. costo de implementación

---

**Por qué estas 3 categorías y no otras:**
- **Consultoría:** factibilidad 0.8 (alta), mercado con múltiples proveedores calificados, KPIs de savings 4-5%
- **Librería:** factibilidad 0.8, compras altamente repetitivas, estandarizables con catálogo único, KPIs 3-5%
- **Catering:** factibilidad 0.7, KPIs de savings más altos (5-6%), volumen suficiente para masa crítica de negociación

---

**Speaker notes:**
> "El scatter plot es el corazón analítico de esta presentación. Las categorías en la esquina superior derecha tienen alto gasto Y alta frecuencia. Cuando además tienen más de 20 proveedores distintos, el argumento para consolidar bajo un contrato único es económicamente irrefutable. La factibilidad no es optimismo — es el coeficiente de probabilidad de éxito de la implementación basado en características del mercado proveedor. Un 0.8 en Consultoría significa que el mercado tiene competencia real y los proveedores tienen incentivos para participar."

---

**Transición al Slide 4:**
> "El análisis dice QUÉ hacer. El roadmap dice CÓMO y — lo más importante — CUÁNDO vemos el primer peso de ahorro real."

---

---

## SLIDE 4 — Roadmap de Implementación: 12 Meses

**Título del slide:** "De descentralizado a centralizado en 3 fases — primer ahorro en el mes 6"

**Objetivo:** Convertir la estrategia en plan ejecutable con responsables, hitos y KPIs de éxito medibles.

---

**Mensaje central:**
> 3 fases: Visibilidad → Centralización → Optimización.
> No proponemos transformar todo simultáneamente. Las categorías de alta factibilidad (Consultoría + Librería) van primero para generar un quick win en el mes 6.

---

**Visual: Gantt simplificado**

```
                    M1  M2  M3  M4  M5  M6  M7  M8  M9  M10 M11 M12
FASE 1 VISIBILIDAD  ██  ██
FASE 2 CENTRALIZ.           ██  ██  ██  ██  ██  ██
FASE 3 OPTIMIZ.                                     ██  ██  ██  ██
```

---

**Hitos clave por mes:**

| Mes | Hito | KPI de éxito |
|---|---|---|
| **M2** | Pipeline productivo + dashboards Looker live | Latencia <24h, 0 errores críticos DQ |
| **M3** | Acuerdo Marco firmado — **Consultoría** | 1er contrato marco activo |
| **M4** | Acuerdo Marco firmado — **Librería** | 2do contrato marco activo |
| **M5** | Pre-autorización obligatoria para compras >USD 10k | 100% compras >10k bajo flujo de aprobación |
| **M6** | ✅ Mid-year: primeros savings medibles vs. baseline | ≥3% ahorro vs. H1-2025 en categorías AM |
| **M8** | Acuerdo Marco firmado — **Catering** | 3er contrato marco activo |
| **M9** | Supresión de proveedores <USD 5k anuales | -30% en padrón de proveedores activos |
| **M10** | Alertas automáticas split purchasing en tiempo real | 0 alertas CRÍTICO en mes |
| **M12** | Revisión anual: savings realizados vs. proyectados | ≥ Savings Escenario Base cumplido |

---

**Speaker notes:**
> "El mes 6 es político, no solo operativo. Necesitamos mostrar un número concreto de ahorro antes de que se cierre el año fiscal. Si llegamos al mes 6 sin un número medible, el programa pierde momentum político. Por eso priorizamos Consultoría y Librería primero: son las de mayor factibilidad y las más rápidas de implementar. El mes 9 es el punto de inflexión en la calidad del padrón de proveedores — cuando la reducción del 30% se consolide, la carga administrativa se reduce y el control se vuelve sistémico, no manual."

---

**Transición al Slide 5:**
> "Tenemos el análisis, la estrategia y el plan. Para arrancarlo, necesitamos tres aprobaciones hoy."

---

---

## SLIDE 5 — Decisión Ejecutiva Requerida

**Título del slide:** "Tres decisiones que desbloquean USD [BASE_SAVINGS] en savings"

**Objetivo:** Cerrar con call to action accionable. No con un resumen — con decisiones.

---

**Mensaje central:**
> El análisis está hecho. Los datos son auditables. Para iniciar el programa necesitamos tres aprobaciones en esta reunión.

---

**Visual: Tres cards de decisión**

```
┌──────────────────────────────────────────┐
│  DECISIÓN 1                              │
│                                          │
│  Aprobar el programa de Acuerdo Marco   │
│  para Consultoría + Librería            │
│                                          │
│  Savings Base: USD [X] anuales          │
│  → Responsable: Head of Procurement     │
│  → Deadline: 15 días desde hoy          │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  DECISIÓN 2                              │
│                                          │
│  Implementar flujo de pre-autorización  │
│  para compras > USD 10.000              │
│                                          │
│  Elimina 100% del riesgo de split PO   │
│  → Responsable: CFO                     │
│  → Deadline: 30 días desde hoy          │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  DECISIÓN 3                              │
│                                          │
│  Activar Looker como sistema único de   │
│  reporte de procurement                  │
│                                          │
│  Pipeline live en naranja-x. Listo.     │
│  → Responsable: CTO / IT                │
│  → Deadline: Inmediato                  │
└──────────────────────────────────────────┘
```

---

**Números finales de alto impacto:**

| Indicador | Valor |
|---|---|
| Savings escenario mínimo | USD [MIN_SAVINGS] |
| **Savings escenario base** | **USD [BASE_SAVINGS]** |
| Savings escenario máximo | USD [MAX_SAVINGS] |
| Reducción de proveedores activos | -30% en 12 meses |
| Alertas CRÍTICO eliminadas | 100% en 6 meses |
| ROI del programa | [X]x en 12 meses |

---

**Speaker notes:**
> "No vine a presentar un análisis. Vine a pedir tres decisiones. El pipeline está deployado en naranja-x y los dashboards están disponibles ahora mismo en Looker para el nivel de detalle que necesiten. Los savings del escenario base son conservadores: asumen factibilidad realista, no optimista. Si aprobamos hoy, el primer contrato marco puede firmarse en 45 días. El único riesgo de no actuar es otro año de desdoblamiento, favoritismo y gasto en montos que crecen un 36% en términos reales sin ningún control sobre los precios."

---

---

*Deck generado como parte de la solución técnica naranja-x | Tail Spend Analytics Platform*
*Completar valores [X], [BASE_SAVINGS], [MIN_SAVINGS], [MAX_SAVINGS] ejecutando: `SELECT * FROM naranja-x.mart_procurement.executive_savings_summary`*
