# Interview Defense — Tail Spend Analytics | naranja-x
## 12 Q&As Técnicas — Preparación para Presentación

---

### Q1: ¿Por qué elegiste deflactar en ARS y volver a USD en lugar de analizar directamente en USD constante?

**Respuesta:**

Las facturas son nominalmente en USD, pero la empresa opera y liquida en ARS. El tipo de cambio ARS/USD pasó de 1.061 en enero 2025 a 1.430 en febrero 2026 — una devaluación del **34,8% en 14 meses**. Esto significa que la misma factura en USD nominal representó volúmenes muy distintos de ARS reales según el período.

Si quedara el análisis en USD nominal, una factura de USD 10.000 en enero 2025 parecería idéntica a una de febrero 2026. Pero la primera consumió 10,6 millones de ARS y la segunda 14,3 millones de ARS. El impacto en el budget real de la empresa es 35% mayor. Eso hace inválida cualquier comparación interanual.

El método correcto para Argentina es: **USD → ARS nominal → ARS constante (deflactado por IPC) → USD base**. La vuelta a USD no es análisis — es presentación. El ejecutivo entiende USD; el desinflado sucedió en ARS.

**Fórmula:** `(monto_usd × tc_periodo × (ipc_max / ipc_periodo)) / tc_base`

---

### Q2: El campo `coeficiente` en la tabla IPC venía como "1.028.963.191". ¿Qué hiciste y por qué?

**Respuesta:**

Ese string no representa un coeficiente de deflación válido como número entero. Un coeficiente de 1.028 millones no tiene interpretación económica posible.

Las opciones eran: (a) interpretarlo como formato europeo con punto como separador de miles →  `1.028963191`, plausible pero no verificable sin la fuente original; (b) descartar el campo y recomputar.

**Mi decisión:** descartar el string raw, preservarlo en `coeficiente_raw` para forensics, y **recomputar como `ipc_fecha_max / ipc_periodo`**, que es la definición exacta del coeficiente de deflación. Resultado: valores entre 1.000 (base feb-2026) y 1.362 (ene-2025). Económicamente válidos para 14 meses de inflación acumulada.

**Por qué es la decisión correcta:** es reproducible, auditable, no depende de la calidad del campo fuente y puede explicarse ante cualquier auditor con una línea de SQL.

---

### Q3: ¿Por qué el umbral de split purchasing (USD 15.000) se evalúa en monto_usd nominal y no en moneda homogénea?

**Respuesta:**

La norma regulatoria que establece el límite de compra directa está expresada en **USD nominales**. Aplicar el umbral en moneda homogénea introduciría inconsistencia temporal:

- En períodos de alta inflación, el umbral homogéneo sería más permisivo en USD nominal → facturas que antes alertaban, dejan de alertar.
- En períodos de baja inflación, el umbral sería más estricto.

Eso es técnicamente insostenible en un sistema de compliance. **El control de norma debe ser determinístico y consistente en el tiempo.**

Sin embargo, el dashboard muestra **ambos**:
- `window_total_usd` para el alert flag (compliance)
- `monto_homogeneo_usd` para el impacto económico real (análisis)

Esto responde dos preguntas diferentes:
- "¿Se eludió la norma?" → USD nominal.
- "¿Cuánto costó realmente?" → USD homogéneo.

---

### Q4: ¿Por qué usaste self-join para la ventana de 7 días en lugar de window functions?

**Respuesta:**

BigQuery soporta `RANGE BETWEEN N PRECEDING AND CURRENT ROW` en window functions, pero **solo para columnas numéricas**, no para columnas `DATE` o `DATETIME`. Una ventana de 7 días sobre fechas requiere lógica diferente.

Opciones:
1. **Self-join** (elegida): JOIN de la tabla contra sí misma con condición `b.fecha BETWEEN DATE_SUB(a.fecha, INTERVAL 6 DAY) AND a.fecha`.
2. `UNNEST(GENERATE_DATE_ARRAY(...))`: genera un array de fechas del período y lo desanida — más verboso.
3. Convertir fechas a INT64 (days since epoch) y usar RANGE — funciona pero menos legible.

Elegí el self-join porque:
- Es conceptualmente claro: "para cada factura ancla, busca todas las del período".
- Es eficiente gracias al **clustering configurado en `fact_invoices` sobre `id_proveedor, area_interna`** — el self-join opera sobre particiones físicas acotadas.
- Es testeable: puedo verificar `window_facturas` (el ARRAY de facturas en la ventana) en la tabla de alertas.

---

### Q5: ¿Cómo garantizás que no hubo pérdida de filas entre el raw layer y el staging?

**Respuesta:**

El Check #20 del framework de validación compara `COUNT(*)` de cada tabla raw contra su equivalente staging. Si hay diferencia, el check retorna filas — señal de error.

Las dos causas legítimas de diferencia son:
1. **Deduplicación por PK**: la staging layer retiene solo la primera ocurrencia de PK duplicados (`ROW_NUMBER() = 1`). Logs auditables.
2. **Exclusión de PK nulo**: filas sin PK son descartadas porque no pueden ser identificadas. Documentado como regla de negocio.

Ambas son intencionales, documentadas y auditable. El check detecta cualquier otro caso inesperado.

En producción, agregaría una tabla `etl_audit_log` que registra: run_id, tabla, raw_count, stg_count, delta, timestamp.

---

### Q6: ¿Por qué el HHI y no simplemente el share del proveedor #1?

**Respuesta:**

El share del proveedor #1 es fácil de comunicar pero **ignora la distribución del resto**. Dos áreas con el mismo proveedor dominante al 30% son completamente diferentes si:
- Área A: top proveedor 30%, segundo 28%, quince proveedores más...  
- Área B: top proveedor 30%, segundo 29%, un tercer proveedor...

El HHI captura la distribución completa: `Σ(share_i²) × 10.000`.

Los umbrales HHI son estándar internacional (FTC, DOJ, CNDC Argentina):
- < 1.500: mercado competitivo
- 1.500–2.500: concentración moderada
- > 2.500: altamente concentrado → riesgo de captura de proveedor

Incluyo **ambas métricas** en el dashboard:
- HHI para el analista y el auditor (riguroso, standard)
- Top-1 share para el CFO (comunicable, directo)

Responden preguntas distintas y se complementan.

---

### Q7: ¿Qué pasa si un rubro de `proveedores` no tiene entrada en `savings_proy`?

**Respuesta:**

El join entre `sourcing_candidates` y `stg_savings_proy` es **LEFT OUTER**. Si una categoría no tiene proyección de savings:
- `factibilidad`, `kpi_min`, `kpi_max` → NULL
- `min/base/max_savings_usd` → NULL  
- `savings_score` → `COALESCE(savings_score, 0)` → 0

El efecto: la categoría es **penalizada en el score compuesto** pero no excluida del análisis. Puede aún aparecer como candidata si tiene altísima frecuencia y dispersión.

El Check #7 del framework de validación alerta cuando un rubro de proveedores no tiene match en savings_proy. En producción, el equipo de procurement debe completar `savings_proy` para todos los rubros activos. El modelo está diseñado para aceptar esa completitud de forma incremental.

---

### Q8: ¿Cómo justificás que Consultoría sea top candidato si puede estar concentrada en algunas áreas?

**Respuesta:**

Concentración y candidatura a acuerdo marco son análisis **ortogonales**, no contradictorios.

La concentración de Consultoría en el área IT (por ejemplo) es exactamente el **síntoma** que el acuerdo marco busca resolver. Si hay 1–2 proveedores dominantes en una categoría, es porque no existe un mecanismo formal de competencia. El acuerdo marco provee ese mecanismo: licitación abierta, múltiples adjudicatarios calificados, precios negociados.

El candidato más urgente no es el que ya tiene diversificación. Es el que tiene **alta dispersión de proveedores no calificados + alta concentración en algunos focos = urgencia de normalización**.

La lógica del score lo captura: dispersion_score alto + la concentración aparece como alerta HHI separada, aportando urgencia estratégica adicional.

---

### Q9: ¿Cómo escala este diseño si el volumen de facturas crece 100x?

**Respuesta:**

Con 10.000 facturas mensuales el costo de queries es marginal. Con 1M mensuales, los puntos de atención son:

1. **Self-join de split purchasing**: con 100x volumen, el self-join puede ser caro si no está bien acotado. Solución: pre-filtrar solo facturas de los últimos 90 días antes del self-join, y materializar con Cloud Scheduler diario en lugar de por demanda.

2. **dim_time CROSS JOIN**: la referencia al `tc_base` via CROSS JOIN es siempre 1 fila — no escala con volumen.

3. **mart_spend_by_category_period**: pre-agregado — resuelve el problema de performance en Looker para tiles de tendencia.

4. **Particionado en fact_invoices por fecha**: con 100x, las particiones mensuales tienen ~100k filas c/u — manejable en BQ.

Para una escala mayor, la siguiente optimización sería implementar una materialización incremental (INSERT INTO en lugar de WRITE_TRUNCATE) basada en `fecha > DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)`.

---

### Q10: ¿Por qué no usaste dbt para las transformaciones?

**Respuesta:**

No fue una decisión contra dbt — fue una decisión de **portabilidad y accesibilidad**.

dbt es lo que recomendaría en producción. La estructura de esta solución **imita exactamente el patrón dbt**: raw → staging → mart, con separación clara de responsabilidades. La migración es directa:

- Cada `CREATE OR REPLACE TABLE AS SELECT` → modelo dbt con el mismo SQL
- Los 20 data quality checks → tests nativos dbt (uniqueness, not_null, relationships, accepted_values)
- Los comentarios de business logic → documentación dbt auto-generada

La elección de BigQuery SQL puro hace que el entrevistador pueda ejecutar cualquier archivo individualmente sin instalar nada adicional. Eso es una ventaja táctica para una demo en vivo.

---

### Q11: ¿Cómo validarías que `monto_homogeneo_usd` está calculado correctamente?

**Respuesta:**

Tres capas de validación:

**1. Verificación del período base:**  
Para facturas de febrero 2026 (el período base), `monto_homogeneo_usd` debe ser `≈ monto_usd` (deflation_coeff = 1.0, tc_periodo ≈ tc_base). Cualquier desvío significativo indica error en la fórmula o en los datos de TC.

**2. Sanidad temporal:**  
El ratio `monto_homogeneo / monto_usd` debe ser **creciente** hacia períodos más antiguos. Una factura de enero 2025 debe tener ratio ~1.36 (coeficiente de deflación de ese período).

**3. Check #16 del framework de DQ:**  
Compara el ratio promedio por período contra el `deflation_coeff` esperado de la `dim_time`. Si difieren en más del 1%, hay un error de join o de lookup.

En la presentación mostraría el query del `01_homogeneous_currency.sql` que tabula el ejemplo numérico período a período.

---

### Q12: ¿Por qué esta solución es senior-level y no un análisis básico?

**Respuesta:**

Cinco indicadores concretos:

**1. Decisión auditable sobre el campo ambiguo:**  
`coeficiente` IPC recomputado como `ipc_max/ipc` en lugar de confiar en el string raw. El raw está preservado para forensics. Un analista junior hubiera descartado el campo o usado el string directo.

**2. Fórmula de moneda homogénea en 3 pasos económicamente rigurosos:**  
USD → ARS nominal → ARS constante → USD base. No "deflactar en USD" que sería económicamente incorrecto para Argentina. El método usa dos fuentes (IPC + TC) articuladas correctamente.

**3. Favoritism temporal (no puntual):**  
La vista `repeat_favoritism_indicator` detecta patrones de dominancia **a través del tiempo**, no solo en un corte cross-sectional. Eso es análisis forense real, no solo descriptivo.

**4. Framework de 20 checks incluyendo sanidad económica:**  
El Check #13 valida que el coeficiente sea ≥ 1.0. El Check #16 valida que el ratio homogéneo/nominal crezca hacia el pasado. Esos son checks de lógica de negocio, no solo checks técnicos de datos.

**5. Dual para compliance y comparabilidad:**  
El threshold de 15k se evalúa en USD nominal (compliance) y el impacto económico se muestra en homogéneo (análisis). No es redundancia — son respuestas a preguntas *diferentes*. Un analista básico elegiría uno. Un senior muestra ambos y explica exactamente por qué.

---

## Frases de seniority para la presentación verbal

> *"Preservé el esquema fuente canónico intacto porque en producción el contrato con el sistema origen tiene prioridad sobre la comodidad analítica."*

> *"El coeficiente era ambiguo. Recomputar como `ipc_max/ipc` no es solo más correcto — es más auditable. Cualquier CFO puede verificar esa fórmula en 5 segundos."*

> *"El HHI de IT es [X]. Eso es mercado oligopólico según los estándares de la CNDC. En compras, se llama proveedor cautivo."*

> *"El threshold de 15k lo evalúo en nominal porque la norma está escrita en nominal. Homogéneo es para análisis económico, no para compliance."*

> *"El roadmap tiene 12 meses porque en meses 1-2 no se puede firmar ningún acuerdo marco — primero necesitás visibilidad confiable y datos auditados."*

> *"El primer euro de ahorro visible es en el mes 6. Eso no es casualidad — es el tiempo mínimo para negociar, firmar y empezar a medir un contrato marco real."*
