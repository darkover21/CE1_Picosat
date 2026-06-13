function [tabla_casos, resultados_casos, peor_caso] = comparar_casos_orbitales(casos_orbitales, simParams, t, h_orb, fecha)
%% ===== OPENSPEC =====
% @spec        comparar_casos_orbitales
% @purpose     Simula los casos orbitales (LTAN x velocidad de spin) y los
%              compara por energía y SOC, identificando el peor caso.
% @inputs      casos_orbitales : struct array con .nombre, .caso_gmat,
%              .delta_RAAN_deg, .w_spin y .gmat_validado.
%              simParams, t, h_orb, fecha : entradas de simulación.
% @outputs     tabla_casos, resultados_casos, peor_caso.
% @assumes     Cada caso debe traer su propio EclipseLocator de GMAT. Si
%              .gmat_validado=false (p.ej. LTAN2 reutiliza el GMAT de LTAN1)
%              se emite un warning y el caso se marca en la tabla.
% @changed     2026-06-13 FASE 1.2: añadida validación de GMAT por caso
%              (campo gmat_validado + columna en la tabla).
% =====================
%COMPARAR_CASOS_ORBITALES Ejecuta los casos orbitales definidos en el main.

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