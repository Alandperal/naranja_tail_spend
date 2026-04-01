# Solución Técnica — Tail Spend Analytics Platform

**Autor:** Alan Damian Peralta

**Proyecto:** Análisis y Transformación de Tail Spend  
**Audiencia:** Head of Procurement / CFO  
**Stack:** BigQuery · Looker (LookML) · Python · GitHub  
**Período de datos:** Enero 2025 – Febrero 2026  
**Fecha:** Marzo 2026

---

## 1. Contexto y Objetivo

La compañía detectó que su **Tail Spend** (compras menores, generalmente <USD 15.000 por operación) es fragmentado, descentralizado y expuesto a riesgos de compliance. El gasto se distribuye entre cientos de proveedores sin contratos marco, impidiendo economías de escala y habilitando prácticas como el desdoblamiento de facturas.

**Objetivo de la solución:**
1. Centralizar el análisis de gasto bajo un modelo de datos único y auditado
2. Detectar irregularidades (desdoblamiento, concentración excesiva)
3. Presentar cifras en moneda homogénea para comparaciones interanuales válidas
4. Proponer las 3 categorías prioritarias para migrar a Acuerdo Marco

---

## 2. Arquitectura Elegida

```
CSV Fuente → raw_procurement (BQ) → stg_procurement (BQ) → mart_procurement (BQ)
                                                         → audit_procurement (BQ)
                                                              ↓
                                                         Looker (LookML)
                                                              ↓
                                                    Dashboards + Executive Deck
```

**Por qué este enfoque es sólido:**
- Preserva el esquema fuente canónico (obligatorio por el spec)
- Separa responsabilidades: raw=fidelidad, staging=tipos, mart=negocio, audit=compliance
- BigQuery-native SQL: sin dependencia de herramientas ETL externas
- Particionado y clustering en fact_invoices garantiza performance en Looker

---

## 3. Diseño del Modelo de Datos

### Tipo de modelo: Snowflake-lite Star Schema

#### Tablas Fuente (raw_procurement) — STRING sin parsear
| Tabla | PK | Columnas |
|---|---|---|
| `proveedores` | `id_proveedor` | cuit, nombre, provincia, rubro |
| `facturas` | `id_factura` | id_proveedor, monto_usd, area_interna, fecha, articulos |
| `ipc` | `periodo_ipc` | fecha_ipc, ipc, ipc_fecha_max, fecha_ipc_max, coeficiente |
| `tc` | `periodo` | tipo_cambio |
| `savings_proy` | `rubros` | factibilidad, kpi_min, kpi_max, variacion |

#### Tabla de Hechos (mart_procurement)
- **`fact_invoices`** — grano: una fila por factura
  - Particionada por `fecha`, clusterizada por `id_proveedor, area_interna, category`
  - Contiene: `monto_usd`, `monto_ars_nominal`, `monto_ars_constante`, **`monto_homogeneo_usd`**

#### Dimensiones
| Tabla | PK | Joins |
|---|---|---|
| `dim_suppliers` | `id_proveedor` | → fact_invoices.id_proveedor |
| `dim_categories` | `category` | → fact_invoices.category, savings_proy |
| `dim_areas` | `area_interna` | → fact_invoices.area_interna |
| `dim_time` | `periodo` | → fact_invoices.periodo; incluye IPC + TC |

#### Diagrama ERD (texto)

```
proveedores (id_proveedor PK)
    ↑ FK
facturas (id_factura PK, id_proveedor FK)
    ↕ periodo JOIN
ipc (periodo_ipc PK) ←→ tc (periodo PK)
    ↓ (bridge)
dim_time → fact_invoices ← dim_suppliers
                         ← dim_categories ← savings_proy (rubros PK)
                         ← dim_areas
                         ↓
                  audit_procurement
                  (split_purchase_alerts, hhi_by_area)
```

---

## 4. Metodología de Moneda Homogénea

### Decisión y justificación

Las facturas están en USD, pero el **poder adquisitivo real en ARS varía mensualmente** por inflación. El tipo de cambio ARS/USD pasó de 1.061 (ene-2025) a 1.430 (feb-2026): una devaluación del 34,8%. Ignorar esto hace que comparaciones interanuales subestimen el costo real de las compras tempranas.

**Método elegido:** Deflactación ARS con reexpresión a USD constante

#### Fórmula exacta (período base = Febrero 2026)

```
monto_ars_nominal    = monto_usd × tc_periodo
monto_ars_constante  = monto_ars_nominal × (ipc_feb2026 / ipc_periodo)
monto_homogeneo_usd  = monto_ars_constante / tc_feb2026

Donde:
  tc_feb2026    = 1.430 ARS/USD
  ipc_feb2026   = 10.714,6255
  coeficiente   = ipc_feb2026 / ipc_periodo  (siempre ≥ 1)
```

#### Ejemplo numérico

| Período | monto_usd | TC | Coef. IPC | monto_homogéneo_usd |
|---|---|---|---|---|
| ene-2025 | 10.000 | 1.061 | 1,362 | **10.122** |
| ago-2025 | 10.000 | 1.340 | 1,165 | **10.920** |
| feb-2026 | 10.000 | 1.430 | 1,000 | **10.000** |

> La factura de agosto 2025 requirió más poder adquisitivo real que la misma en USD nominal.

#### Compliance

El umbral de USD 15.000 para compra directa **siempre se evalúa en `monto_usd` nominal**, no en moneda homogénea. Razón: el límite regulatorio está expresado en términos nominales en USD.

---

## 5. Lógica de Auditoría

### 5.1 Split Purchasing (Desdoblamiento)

**Regla:** Alerta cuando el mismo proveedor factura a la misma área interna más de USD 15.000 acumulado en una **ventana móvil de 7 días**.

**Implementación:**
- Self-join de `fact_invoices` sobre `id_proveedor + area_interna` con condición de fecha `BETWEEN anchor - 6 AND anchor`
- Se agrupa por factura ancla y se suma el total de la ventana
- Se clasifica por severidad: MEDIO >15k, ALTO >30k, CRÍTICO >50k

**Output:** `audit_procurement.split_purchase_alerts`

**Por qué este enfoque:**
- La ventana de 7 días es la más estándar para detectar fraccionamiento deliberado
- El self-join es computacionalmente eficiente con la tabla clusterizada
- El campo `bypass_ratio` cuantifica qué tan lejos está el proveedor del límite

### 5.2 Concentración Excesiva / Favoritismo

**Métrica principal:** Índice de Herfindahl-Hirschman (HHI)

```
HHI_area = Σ (share_proveedor_i)² × 10.000
```

| Rango HHI | Interpretación |
|---|---|
| < 1.500 | Área competitiva — OK |
| 1.500 – 2.500 | Concentración moderada — Monitorear |
| > 2.500 | Altamente concentrada — Riesgo de favoritismo |

**Flags adicionales:**
- `favoritism_flag_40pct`: proveedor #1 supera el 40% del presupuesto del área
- `favoritism_flag_60pct`: proveedor #1 supera el 60%
- `repeat_favoritism_indicator`: proveedor que es #1 en la misma área en ≥3 períodos distintos

---

## 6. Lógica de Sourcing

### Identificación de Top 3 Categorías para Acuerdo Marco

**Criterios de elegibilidad:**
- Más de 20 proveedores distintos activos en la categoría (fragmentación real)

**Score compuesto:**
```
composite_score = (0.40 × freq_score) + (0.30 × dispersion_score) + (0.30 × savings_score)
```

**Savings estimados por categoría:**
```
min_savings  = gasto_homogeneo × factibilidad × kpi_min
base_savings = gasto_homogeneo × factibilidad × ((kpi_min + kpi_max) / 2)
max_savings  = gasto_homogeneo × factibilidad × kpi_max
```

**Interpretación de factibilidad:**
| Valor | Significado |
|---|---|
| 1.0 | Éxito asegurado |
| 0.7–0.9 | Alta probabilidad |
| 0.3–0.6 | Dificultad media-alta |
| 0.0 | Bloqueado |

---

## 7. KPIs Clave

| KPI | Fuente BQ | Implementación |
|---|---|---|
| invoice_count | fact_invoices | Looker measure |
| supplier_count | fact_invoices | Looker measure |
| homogeneous_spend | fact_invoices | Looker measure (sum) |
| raw_usd_spend | fact_invoices | Looker measure (sum) |
| avg_invoice_value | fact_invoices | Looker measure (avg) |
| top_supplier_share | concentration_by_area | BQ precomputed |
| top_5_supplier_share | hhi_by_area | BQ precomputed |
| hhi_score | hhi_by_area | BQ precomputed |
| split_purchase_alert_count | split_purchase_alerts | Looker measure |
| split_purchase_alert_amount | split_purchase_alerts | Looker measure |
| candidate_category_count | sourcing_candidates | Looker measure |
| estimated_min_savings | sourcing_candidates | BQ precomputed |
| estimated_base_savings | sourcing_candidates | BQ precomputed |
| estimated_max_savings | sourcing_candidates | BQ precomputed |

---

## 8. Decisiones Técnicas

| Decisión | Elección | Justificación |
|---|---|---|
| Parseo de `coeficiente` IPC | Recomputado como `ipc_max/ipc` | El string raw "1.028.963.191" es ambiguo; el ratio calculado es auditable |
| Separador decimal CSV | Punto europeo eliminado, coma→punto | Regla: `REPLACE('.','') → REPLACE(',','.')` |
| Fechas | `SAFE.PARSE_DATE` con zero-pad de día/mes | Robustez ante `4/9/2025` vs `04/09/2025` |
| `articulos` | Tratado como SKU único por fila | La muestra no evidencia listas; la asunción es documentada |
| Período base moneda | Feb-2026 (último IPC disponible) | Maximiza la cantidad de períodos deflactados; siempre coeff ≥ 1 |
| Tasas en savings_proy | Decimales (0.03 = 3%) | Convención uniforme; conversión: string "3,0%" → 3.0 / 100 = 0.03 |
| HHI vs. top-N share | Ambos | HHI es más defensible estadísticamente; top-N más comunicable al CFO |

---

## 9. Hallazgos Esperables (con datos reales)

1. **Consultoría y Librería** aparecen como top candidatos a acuerdo marco (alta frecuencia, >20 proveedores, buena factibilidad)
2. **IT y Legal** muestran HHI > 2.500 (concentración severa en 1-2 proveedores)
3. **Finanzas** probablemente presenta la mayor cantidad de alertas de split purchasing
4. El gasto homogéneo de ene-2025 es ~36% mayor en términos reales que el nominal en USD
5. Los rubros con `factibilidad < 0.5` (Limpieza, Hardware) requieren gestión de resistencia interna antes de centralizar

---

## 10. Limitaciones

1. **IPC mensual:** Se parte del período, no del día exacto de la factura. Error máximo ≈ diferencia inflacionaria dentro del mes (~1-2%).
2. **TC abierto:** Se usa TC mensual (no intradía). Facturas en días con volatilidad fuerte pueden tener TC real diferente.
3. **Un SKU por factura:** Si el sistema real tiene facturas multi-ítem, la lógica de split purchasing debe recalcularse a nivel de ítem.
4. **sin datos históricos pre-2025:** El análisis interanual requiere al menos 2 años completos para tendencias robustas.
5. **IPC = CPI general INDEC:** Idealmente se usaría índice de precios mayoristas por categoría. El IPC general es una aproximación válida pero conservadora.

---

## 11. Próximos Pasos hacia Producción

### Fase 1 — Estabilización (meses 1-2)
- [ ] Conectar pipeline a sistema ERP origen (reemplazar CSVs manuales)
- [ ] Configurar Cloud Composer (Airflow) para orquestación diaria
- [ ] Activar monitoreo de data quality con alertas en Slack/email
- [ ] Conectar Looker a BigQuery con service account de solo lectura

### Fase 2 — Centralización (meses 3-6)
- [ ] Negociar acuerdos marco con top 3 categorías identificadas
- [ ] Implementar flujo de aprobación: compras > USD 10k requieren pre-autorización
- [ ] Crear tabla `acuerdos_marco` como nueva fuente en el modelo
- [ ] Agregar dimensión `tipo_compra` (spot vs. acuerdo marco) a fact_invoices

### Fase 3 — Optimización (meses 7-12)
- [ ] Machine Learning: forecast de gasto por área usando BigQuery ML (ARIMA_PLUS)
- [ ] Scoring de riesgo de proveedor: combinar HHI + split alerts + factibilidad
- [ ] Dashboard self-service para jefes de área (acceso filtrado por área propia)
- [ ] Integración con sistema de cotizaciones para pre-validar vs. acuerdo marco

---

## Roadmap 12 Meses: De Descentralizado a Centralizado

| Mes | Hito | KPI de éxito |
|---|---|---|
| 1-2 | Pipeline productivo; dashboards live | Latencia < 24h; 0 errores críticos DQ |
| 3 | Framework agreement firmado Consultoría | 1er contrato marco activo |
| 4 | Framework agreement firmado Librería | 2do contrato marco activo |
| 5 | Regla de pre-autorización >10k implementada | 100% compras >10k bajo flujo |
| 6 | Revisión mid-year savings — primeros ahorros medibles | ≥3% ahorro vs. baseline H1-2025 |
| 7-8 | Framework agreement Catering/Mantenimiento | 3er/4to contrato marco |
| 9 | Supresión de proveedores no consolidados (<5k anual) | -30% proveedores activos |
| 10 | Alertas automáticas split purchasing en tiempo real | 0 alertas CRÍTICO en mes |
| 11 | Dashboard self-service rollout a áreas | NPS >7 en áreas usuarias |
| 12 | Revisión anual: savings realizados vs. proyectados | ≥base_savings cumplido |
