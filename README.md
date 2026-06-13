# CE1 — Simulador EPS de un PicoSatélite PocketQube 2P

Simulador del **Sistema de Potencia Eléctrica (EPS, *Electrical Power System*)** de un
picosatélite **PocketQube 2P** en órbita LEO heliosíncrona (SSO), desarrollado para el
**Caso de Estudio 1** del **Máster en Sistemas Espaciales (UPM–ETSIAE, curso 2025–2026)**.

El modelo integra, sobre un bucle temporal a paso fijo, la generación fotovoltaica de los
cuatro paneles laterales, el modelo térmico de panel, el consumo de las cargas, la máquina
de estados de modos del EPS y la dinámica de la batería LiFePO₄, y permite analizar el
balance energético a lo largo de varias órbitas, distintos casos orbitales y escenarios de
fallo de paneles.

---

## Requisitos

- **MATLAB R2024b o superior** (probado en R2025b). No requiere toolboxes adicionales.

---

## Cómo ejecutar

```matlab
% Desde la raíz del proyecto:
main            % ejecuta la simulación principal + comparativas + gráficas
```

`main.m` añade automáticamente la carpeta `funciones/` al path. Al arrancar carga la
configuración centralizada con `config = config_eps();`.

### Tests

```matlab
run_all_tests   % desde la raíz del proyecto: ejecuta los 3 tests y resume
```

`run_all_tests.m` vive en la raíz y añade `funciones/` y `tests/` al path por sí
mismo. Cada test imprime `PASS`/`FAIL` por comprobación y usa `assert()` con tolerancia.

### Dashboard interactivo

```matlab
dashboard_eps   % panel uihtml: elige caso orbital y escenario de fallo, y traza SOC y modo EPS
```

Construido con la skill `matlab-uihtml-app-builder`. Usa un horizonte reducido y paso
grueso, y **cachea la iluminación por caso orbital** (la parte cara, vía WMM) para que
cada simulación sea ágil. La fidelidad completa (10 órbitas, `dt=1 s`) está en `main.m`.

---

## Estructura del repositorio

```
.
├── main.m                          % Script principal: parámetros, simulación, gráficas
├── config_eps.m                    % Configuración centralizada (misión, reguladores, modos)
├── simular_caso_eps.m              % Bucle temporal principal del EPS
├── run_all_tests.m                 % Runner de tests (raíz del proyecto)
├── dashboard_eps.m / .html         % Panel de control interactivo (uihtml)
├── skills/
│   └── eps-simulator-skill/SKILL.md% Agent Skill reutilizable del flujo EPS
├── funciones/
│   ├── Iluminacion_act_efe.m       % Irradiancia por panel (WMM + spin)
│   ├── calcular_temperatura_panel.m% Modelo térmico exponencial del panel
│   ├── curvas_IV_Temperatura.m     % Modelo Pindado–Cubas celda SM141K06L
│   ├── seleccionar_modo_eps.m      % Máquina de estados Nominal/Degradado/Safe
│   ├── seleccionar_estado_paneles.m% Vector Panel_state por escenario de fallo
│   ├── comparar_casos_orbitales.m  % Comparativa de los 4 casos orbitales
│   ├── importarParametrosBateria.m % Parámetros LiFePO4 ACL9011 + curva OCV(SOC)
│   ├── simularBateriaDinamica1RC.m % Integrador OCV(SOC) + Rint
│   ├── perfil_consumo.m            % Perfiles CPU/Rx/Tx (ciclo de 120 s)
│   ├── get_eclipse_mask.m          % Parser del EclipseLocator de GMAT
│   ├── mppt_incremental_conductance_step.m  % MPPT Incremental Conductance
│   └── graficar_comparativa_fallos.m        % Gráficas de escenarios de fallo
├── datos_gmat/
│   └── 10_30_SSO/                  % Datos GMAT (EclipseLocator1.txt, masks.csv, script)
└── tests/
    ├── run_all_tests.m
    ├── test_seleccionar_modo_eps.m
    ├── test_curvas_IV.m
    └── test_bateria.m
```

---

## Arquitectura del modelo

| Bloque | Fichero | Descripción |
|---|---|---|
| **Misión / órbita** | `config_eps.m` | SMA, periodo orbital, nº de órbitas, paso temporal. |
| **Entorno** | `get_eclipse_mask.m`, `calcular_temperatura_panel.m` | Máscara de eclipse a partir de GMAT y temperatura del panel en `[-25, 65] °C`. |
| **Iluminación** | `Iluminacion_act_efe.m` | Irradiancia `G` de cada panel (X±, Y±) con campo magnético (WMM) y giro (*spin*). |
| **Generación FV** | `curvas_IV_Temperatura.m` | Modelo Pindado–Cubas de la celda SM141K06L; `Pbus = η_MPPT · Vmp · Imp`. |
| **Consumo** | `perfil_consumo.m` | Potencia útil de CPU/Rx/Tx según el ciclo de operación de 120 s. |
| **Modos EPS** | `seleccionar_modo_eps.m` | Máquina de estados con histéresis: Nominal (0) / Degradado (1) / Safe (2). |
| **Batería** | `importarParametrosBateria.m`, `simularBateriaDinamica1RC.m` | LiFePO₄ ACL9011 1S1P, modelo cuasi-estático `OCV(SOC) + Rint`. |
| **Orquestación** | `simular_caso_eps.m`, `main.m` | Bucle temporal, balance de potencia y postprocesado. |

### Convención de la batería

```
I_bat > 0  → batería carga
I_bat < 0  → batería descarga
```

### Modos del EPS

| Modo | Valor | Entrada | Comportamiento |
|---|---|---|---|
| Nominal   | 0 | SOC alto                       | Todas las cargas activas. |
| Degradado | 1 | `SOC ≤ 0.70` (DoD ≥ 30 %)      | Tx solo cada 3 ciclos. |
| Safe      | 2 | `SOC ≤ 0.55` **o** `OCV(SOC) ≤ 3.05 V` | CPU apagada; Rx/Tx en ventanas puntuales. |

La salida de cada modo aplica **histéresis** (`SOC_sale_*`) para evitar oscilaciones.

---

## Configuración centralizada (`config_eps.m`)

Todos los parámetros físicos viven en un único punto. `config_eps()` devuelve una `struct`
con tres campos:

- `config.mission` — `mu`, `SMA`, `h_orb`, `T_orb`, `N_orb`, `dt`.
- `config.reguladores` — `eta_DCDC`, `Vo_RL`, `G0`.
- `config.modos_eps` — umbrales de SOC, `V_min_ocv` y `periodo_operacion`.

Para cambiar el número de órbitas, el paso temporal o cualquier umbral de modo, **edita
`config_eps.m`**, no `main.m`.

---

## Decisiones de modelado y correcciones relevantes

### Umbral de entrada a *Safe* basado en OCV (no en tensión de bornes)

La condición de tensión para entrar en *Safe* evalúa **`OCV(SOC) ≤ V_min_ocv` (3.05 V)**,
interpolando sobre la curva `soc_data`/`voc_data` de la batería, en lugar de la tensión de
bornes. La tensión de bornes cae por `I·Rint` (Rint = 60 mΩ) y disparaba *Safe* de forma
espuria con el SOC todavía alto (≈ 0.80). La condición primaria sigue siendo por SOC
(`SOC ≤ 0.55`).

### Casos orbitales y validación de GMAT

Se simulan 4 casos: 2 LTAN × 2 velocidades de *spin*. Cada caso lleva un campo
`gmat_validado`. **LTAN2 reutiliza temporalmente el archivo GMAT de LTAN1**, por lo que sus
casos se marcan como **no validados** y `main.m`/`comparar_casos_orbitales.m` emiten un
`warning()` explícito en consola.

### Análisis de fallos de paneles

Con `hacer_comparativa_paneles = true`, `main.m` analiza los casos exigidos por el enunciado:

- `nominal`
- `fallo_dos_celdas_Xp_Yp`, `fallo_dos_celdas_Xp_Yn` — 2 celdas en paneles distintos.
- `fallo_panel_Xp`, `fallo_panel_Yn` — fallo de un panel completo.

El vector `Panel_state = [X+ X- Y+ Y-]` usa `1` (nominal 1S2P), `0.5` (una celda perdida,
1S1P) y `0` (panel completo fallado).

### MPPT dinámico opcional

`simParams.usar_mppt_dinamico` (por defecto `false`) selecciona la extracción de potencia:

- `false` → rendimiento de seguimiento constante `η_MPPT = 0.92` (dentro de `curvas_IV_Temperatura`).
- `true`  → `mppt_incremental_conductance_step` (Incremental Conductance) por panel.

---

## Tests

| Test | Verifica |
|---|---|
| `test_seleccionar_modo_eps` | *Safe* **no** se activa con `SOC = 0.80` y descarga nominal (fix OCV); control positivo con `SOC = 0.50`. |
| `test_curvas_IV` | `Pbus ≈ 0.92 · Vmp · Imp` a `T = 25 °C`, `G = 1000 W/m²`. |
| `test_bateria` | El SOC decrece de forma monótona con descarga constante y cumple `ΔSOC = I·dt/(3600·C_Ah)`. |

---

## Agent Skill reutilizable

`skills/eps-simulator-skill/SKILL.md` encapsula el flujo completo del simulador para que
otro agente lo conduzca con una sola instrucción (ejecutar, simular un fallo, añadir un
caso orbital, cambiar un umbral, diagnosticar el modo Safe). Recoge las reglas no obvias:
parámetros desde `config_eps`, umbral de Safe por `OCV(SOC)` (no por tensión de bornes),
contrato de `simParams` y la advertencia de LTAN2. Generado siguiendo la skill
`agent-skill-author` del repositorio `matlab/agent-skills-playground`.

## Documentación openspec

Cada función creada o modificada lleva al inicio un bloque `%% openspec` (con
`@function`, `@version`, `@changed`, `@param`, `@returns`, `@throws`, `@example`,
`@see`) y, al final, una línea `%% MODIFICADO POR AGENTE — <fecha> — <descripción>`.

## Pendientes (`PENDIENTE` en el código)

- `delta_RAAN_LTAN1_deg` / `delta_RAAN_LTAN2_deg`: valores provisionales; sustituir por el
  RAAN real una vez definido el LTAN en GMAT.
- LTAN2 necesita su propio `EclipseLocator1.txt`; mientras tanto reutiliza el de LTAN1.
- `factor_iluminacion_paneles` (en `main.m`): modelo de actitud/iluminación por modelar.

---

## Autores

Trabajo de equipo del Máster en Sistemas Espaciales (UPM–ETSIAE). Contribuciones de los
módulos de iluminación, batería, modos EPS y comparativas según se referencia en los
comentarios del código.
