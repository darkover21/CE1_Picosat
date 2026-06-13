function [tabla_casos, resultados_casos, peor_caso] = comparar_casos_orbitales(casos_orbitales, simParams, t, h_orb, fecha)
%COMPARAR_CASOS_ORBITALES Ejecuta y compara los casos orbitales definidos en el main.
%
%% openspec
% @function comparar_casos_orbitales
% @version 1.1
% @changed 2026-06-13 — Fase 1.2: añadida validación de GMAT por caso (campo
%          gmat_validado + columna en la tabla + warning para casos no validados).
%          Cabecera migrada a openspec (Fase 3).
% @param casos_orbitales {struct array} [-] — Casos con .nombre, .caso_gmat,
%          .delta_RAAN_deg [deg], .w_spin [rad/s] y .gmat_validado {logical}
% @param simParams {struct} [-] — Parámetros base de simulación (ver simular_caso_eps)
% @param t {double vector} [s] — Vector temporal de la simulación
% @param h_orb {double} [km] — Altitud orbital
% @param fecha {datetime} [-] — Época de inicio (día/mes/año para la iluminación)
% @returns tabla_casos {table} [-] — Resumen por caso (energías, SOC, V_bat, gmat_validado)
% @returns resultados_casos {struct} [-] — Resultado completo de cada caso simulado
% @returns peor_caso {struct} [-] — Caso con el menor SOC mínimo
% @throws (emite warning "comparar_casos_orbitales:gmatNoValidado" para casos sin GMAT propio)
% @example
%   config = config_eps();
%   % ... armar simParams y casos_orbitales como en main.m ...
%   [tbl, res, peor] = comparar_casos_orbitales(casos_orbitales, simParams, t, h_orb, fecha);
% @see simular_caso_eps, Iluminacion_act_efe, seleccionar_estado_paneles
%
% Supuesto: cada caso debe traer su propio EclipseLocator de GMAT. Si
% .gmat_validado=false (p.ej. LTAN2 reutiliza el GMAT de LTAN1) se emite un
% warning y el caso se marca en la tabla como no validado.

n_casos = numel(casos_orbitales);

resultados_casos = struct();

nombre_caso = strings(n_casos, 1);
delta_RAAN = zeros(n_casos, 1);
w_spin = zeros(n_casos, 1);
gmat_validado = false(n_casos, 1);

E_gen_Wh = zeros(n_casos, 1);
E_cons_Wh = zeros(n_casos, 1);
balance_Wh = zeros(n_casos, 1);

SOC_min = zeros(n_casos, 1);
SOC_final = zeros(n_casos, 1);
Vbat_min = zeros(n_casos, 1);

for k = 1:n_casos

    caso = casos_orbitales(k);

    fprintf('\nSimulando caso %s\n', caso.nombre);

    % --- Validación del GMAT asociado al caso (FASE 1.2) ---
    if isfield(caso, 'gmat_validado')
        gmat_validado(k) = caso.gmat_validado;
    else
        gmat_validado(k) = false;
    end
    if ~gmat_validado(k)
        warning('comparar_casos_orbitales:gmatNoValidado', ...
            ['Caso "%s": GMAT no validado (caso_gmat = "%s"). ' ...
             'Resultados orientativos hasta disponer de su EclipseLocator propio.'], ...
            char(caso.nombre), char(caso.caso_gmat));
    end

    [G_px, G_nx, G_py, G_ny, ~] = Iluminacion_act_efe( ...
        t, ...
        h_orb, ...
        caso.delta_RAAN_deg, ...
        caso.w_spin, ...
        day(fecha), ...
        month(fecha), ...
        year(fecha));

    G_paneles = [G_px; G_nx; G_py; G_ny];

    simParams_caso = simParams;
    simParams_caso.G_paneles = G_paneles;
    simParams_caso.Panel_state = seleccionar_estado_paneles("nominal");

    res = simular_caso_eps(simParams_caso);

    campo = char(matlab.lang.makeValidName(caso.nombre));
    resultados_casos.(campo) = res;

    nombre_caso(k) = caso.nombre;
    delta_RAAN(k) = caso.delta_RAAN_deg;
    w_spin(k) = caso.w_spin;
    
    E_gen_Wh(k) = trapz(t, res.W_gen) / 3600;
    E_cons_Wh(k) = trapz(t, res.W_bus) / 3600;
    balance_Wh(k) = E_gen_Wh(k) - E_cons_Wh(k);
    
    SOC_min(k) = min(res.soc_bat);
    SOC_final(k) = res.soc_bat(end);
    Vbat_min(k) = min(res.V_bat);

end

tabla_casos = table( ...
    nombre_caso, ...
    delta_RAAN, ...
    w_spin, ...
    gmat_validado, ...
    E_gen_Wh, ...
    E_cons_Wh, ...
    balance_Wh, ...
    SOC_min, ...
    SOC_final, ...
    Vbat_min);

disp(' ');
disp('===== COMPARATIVA CASOS ORBITALES =====');
disp(tabla_casos);

[~, idx_peor] = min(SOC_min);
peor_caso = casos_orbitales(idx_peor);

fprintf('\n===== PEOR CASO ORBITAL =====\n');
fprintf('Caso: %s\n', peor_caso.nombre);
fprintf('delta_RAAN_deg = %.2f deg\n', peor_caso.delta_RAAN_deg);
fprintf('w_spin = %.4f rad/s\n', peor_caso.w_spin);
fprintf('SOC_min = %.4f\n', SOC_min(idx_peor));
fprintf('Vbat_min = %.4f V\n', Vbat_min(idx_peor));

end

%% MODIFICADO POR AGENTE — 2026-06-13 — Validación de GMAT por caso (gmat_validado + warning + columna) y cabecera openspec.