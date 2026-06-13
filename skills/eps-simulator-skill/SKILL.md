---
name: eps-simulator-skill
description: Use this skill to run, configure, or extend the PocketQube 2P EPS (Electrical Power System) MATLAB simulator in this repository. Trigger phrases include "run the EPS simulation", "simulate a panel fault", "add an orbital case", "change an EPS mode threshold", "run a single case", "why is the satellite in Safe mode". Do NOT trigger for unrelated MATLAB tasks or for editing the WMM/illumination physics, which is out of scope.
license: MIT
metadata:
  author: CE1 — Máster Sistemas Espaciales UPM-ETSIAE
  version: "1.0"
---

# EPS Simulator (PocketQube 2P)

This skill encapsulates the full simulation flow of the EPS simulator so an agent can
drive it with one instruction. It fixes the failures an agent makes when dropped into
this repo cold: rebuilding `simParams` wrong, reintroducing the terminal-voltage Safe
bug, hardcoding parameters that live in `config_eps`, or trusting the LTAN2 results.

## When this skill applies

- Running the simulator (`main`) or a single case headlessly.
- Adding/altering an orbital case or a panel-fault scenario.
- Changing an EPS mode threshold (SOC or OCV) or a regulator/mission parameter.
- Diagnosing why the EPS enters (or does not enter) Degradado/Safe.
- Launching the interactive dashboard or running the unit tests.

Do not apply this skill to modify the illumination/WMM physics in
`funciones/Iluminacion_act_efe.m` — that is a separate, out-of-scope model.

## Core rules

Ordered by how often they prevent failures. Read top to bottom.

### Rule 1: All physical parameters come from `config_eps`, never hardcode them

Mission, regulator and EPS-mode thresholds live in `config_eps.m`. Do not reintroduce
literals (e.g. `V_min_admisible = 3.3`) in `main.m` or `simParams`.

```matlab
% WRONG
simParams.V_min_admisible = 3.3;        % removed; caused spurious Safe

% RIGHT
config = config_eps();
simParams.cfg_modos = config.modos_eps; % SOC + OCV thresholds live here
```

### Rule 2: The Safe-mode voltage check uses OCV(SOC), not terminal voltage

The terminal voltage drops by `I*Rint` (Rint = 60 mΩ) and once falsely triggered Safe
with SOC ≈ 0.80. Entry to Safe is primarily by SOC (`SOC ≤ 0.55`) and, for voltage, by
`OCV(SOC) ≤ V_min_ocv` (3.05 V). Never compare `V_bat` against the Safe threshold.

```matlab
% RIGHT (inside seleccionar_modo_eps): decide by OCV, not V_bat
Voc = interp1(batteryParams.soc_data, batteryParams.voc_data, soc_bat, "linear", "extrap");
if soc_bat <= cfg_modos.SOC_entra_safe || Voc <= cfg_modos.V_min_ocv
    modo_eps = 2;   % Safe
end
```

### Rule 3: Build `simParams` with the exact field contract of `simular_caso_eps`

`simular_caso_eps(simParams)` reads these fields. Missing `cfg_modos` or `batteryParams`
is the most common breakage.

```matlab
simParams.Nt = numel(t);  simParams.dt = dt;
simParams.T_panel = T_panel;          % [°C] vector
simParams.G_paneles = [Gpx; Gnx; Gpy; Gny];   % 4 x Nt [W/m^2]
simParams.Panel_state = seleccionar_estado_paneles("nominal");  % [X+ X- Y+ Y-]
simParams.P_CPU = P_CPU; simParams.P_Rx = P_Rx; simParams.P_Tx = P_Tx;
simParams.eta_DCDC = config.reguladores.eta_DCDC;
simParams.Vo_RL = config.reguladores.Vo_RL;
simParams.batteryParams = batteryParams;
simParams.ns_bat = batteryParams.Ns; simParams.np_bat = batteryParams.Np;
simParams.cfg_modos = config.modos_eps;
simParams.usar_mppt_dinamico = false;   % true -> MPPT IC dinámico
res = simular_caso_eps(simParams);
```

### Rule 4: Battery sign convention is I>0 charge, I<0 discharge

`res.I_bat > 0` means the battery is charging. Do not flip this when reading results.

### Rule 5: LTAN2 orbital results are NOT validated

LTAN2 reuses the GMAT EclipseLocator of LTAN1, so its cases carry `gmat_validado=false`
and emit a warning. Treat LTAN2 SOC/energy numbers as orientative until a dedicated
`datos_gmat/<LTAN2>/EclipseLocator1.txt` exists.

## API patterns

### Run everything (nominal case + orbital and fault comparatives + plots)

```matlab
main
```

### Run a single case headlessly

Build `simParams` per Rule 3, compute the environment, then call `simular_caso_eps`.
Illumination/temperature come from `Iluminacion_act_efe` + `calcular_temperatura_panel`.

### Add a panel-fault scenario

Add a `case` to `funciones/seleccionar_estado_paneles.m` returning a 1×4 vector with
values {1 nominal, 0.5 one cell lost, 0 panel dead}. Then add the name to
`casos_paneles_requeridos` in `main.m`.

### Change a mode threshold

Edit the relevant field of `config.modos_eps` in `config_eps.m` (e.g. `V_min_ocv`,
`SOC_entra_safe`). Do not edit `seleccionar_modo_eps.m` to hardcode it.

### Run the unit tests

```matlab
run_all_tests   % from the project root; prints PASS/FAIL + summary
```

### Launch the interactive dashboard

```matlab
dashboard_eps   % uihtml panel: pick orbital case + fault, plots SOC and EPS mode
```

## Common pitfalls

- **Reintroducing the 3.3 V Safe bug**: comparing terminal `V_bat` instead of `OCV(SOC)` makes the EPS dive into Safe with SOC still ~0.80. Use Rule 2.
- **Forgetting `simParams.cfg_modos`**: `simular_caso_eps` errors without it. See Rule 3.
- **Trusting LTAN2 numbers**: they are unvalidated (Rule 5).
- **Dashboard slowness expectations**: the dashboard uses a reduced horizon and coarse `dt`, and caches illumination per orbital case; full-fidelity (10 orbits, dt=1) is `main.m` only.
- **WMM date warning**: `Iluminacion_act_efe` falls back to year 2024 for dates after 2025 (WMM2020 validity). Expected, not an error.

## See also

- `config_eps.m`: the single source of physical parameters.
- `simular_caso_eps.m`: the time loop and its `simParams` contract.
- `funciones/seleccionar_modo_eps.m`: the Nominal/Degradado/Safe state machine.
- `tests/`: unit tests for the mode logic, IV curves, and battery integrator.
- Related skill: `matlab-uihtml-app-builder` for the dashboard UI patterns.
