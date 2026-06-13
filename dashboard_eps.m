function dashboard_eps()
%DASHBOARD_EPS Panel de control interactivo (uihtml) del simulador EPS.
%
%% openspec
% @function dashboard_eps
% @version 1.0
% @changed 2026-06-13 — Creado (Fase 4) con la skill matlab-uihtml-app-builder:
%          selectores de caso orbital y escenario de fallo, y gráficas de SOC y
%          modo EPS al lanzar la simulación.
% @param (script de lanzamiento; no recibe argumentos)
% @returns (ninguno; abre una uifigure interactiva)
% @throws (los errores de simulación se capturan y se envían a la UI como "SimError")
% @example
%   dashboard_eps();   % abre el panel; elige caso y fallo y pulsa «Simular»
% @see config_eps, simular_caso_eps, seleccionar_estado_paneles, Iluminacion_act_efe
%
% Diseño: la iluminación (cara por el WMM, calculado por paso) depende solo del
% caso orbital, así que se cachea por caso tras el primer cálculo. El escenario
% de fallo solo cambia Panel_state, por lo que reusar la iluminación cacheada
% hace que cada nueva simulación sea rápida. El horizonte se reduce respecto a
% main.m (menos órbitas y paso más grueso) para mantener la interactividad.

    root = fileparts(mfilename("fullpath"));
    addpath(fullfile(root, "funciones"));   % entry-point: necesita las funciones del modelo

    config = config_eps();

    % Horizonte reducido para interactividad (fidelidad completa en main.m).
    nOrbDashboard = 2;
    dtDashboard = 5;
    tDashboard = (0:dtDashboard:nOrbDashboard*config.mission.T_orb)';

    casosOrbitales = buildOrbitalCases();
    batteryParams = importarParametrosBateria("dashboard_dummy.txt");
    fecha = datetime("01 Jul 2027 08:52:00", ...
        "InputFormat", "dd MMM yyyy HH:mm:ss", "Locale", "en_US");
    [pCpu, pRx, pTx] = perfil_consumo(tDashboard);

    % --- Figura y disposición ---
    fig = uifigure("Name", "Dashboard EPS - PocketQube 2P", "Position", [80 80 1000 740]);
    gl = uigridlayout(fig, [3 1]);
    gl.RowHeight = {230, "1x", "1x"};
    gl.ColumnWidth = {"1x"};

    h = uihtml(gl);
    h.Layout.Row = 1;
    h.HTMLSource = fullfile(root, "dashboard_eps.html");

    axSoc = uiaxes(gl);
    axSoc.Layout.Row = 2;
    title(axSoc, "SOC de la bateria");
    xlabel(axSoc, "Tiempo [h]");
    ylabel(axSoc, "SOC [-]");
    grid(axSoc, "on");

    axModo = uiaxes(gl);
    axModo.Layout.Row = 3;
    title(axModo, "Modo EPS");
    xlabel(axModo, "Tiempo [h]");
    ylabel(axModo, "Modo");
    yticks(axModo, [0 1 2]);
    yticklabels(axModo, {"Nominal", "Degradado", "Safe"});
    grid(axModo, "on");

    % --- Estado compartido entre callbacks ---
    state.config = config;
    state.t = tDashboard;
    state.dt = dtDashboard;
    state.casos = casosOrbitales;
    state.battery = batteryParams;
    state.fecha = fecha;
    state.pCpu = pCpu;
    state.pRx = pRx;
    state.pTx = pTx;
    state.hOrb = config.mission.h_orb;
    state.gCache = cell(1, numel(casosOrbitales));   % iluminacion cacheada por caso orbital
    state.axSoc = axSoc;
    state.axModo = axModo;
    state.html = h;
    fig.UserData = state;

    h.HTMLEventReceivedFcn = @(src, event) onHtmlEvent(src, event, fig);
end

function casos = buildOrbitalCases()
    % Mismos 4 casos orbitales que main.m (LTAN x velocidad de spin).
    % PENDIENTE: delta_RAAN provisional hasta definir el LTAN real en GMAT.
    deltaRaanLtan1 = 0;
    deltaRaanLtan2 = 90;
    casos = struct( ...
        "nombre", {"LTAN1_w0", "LTAN1_w01", "LTAN2_w0", "LTAN2_w01"}, ...
        "delta_RAAN_deg", {deltaRaanLtan1, deltaRaanLtan1, deltaRaanLtan2, deltaRaanLtan2}, ...
        "w_spin", {0, 0.1, 0, 0.1});
end

function onHtmlEvent(src, event, fig)
    try
        switch event.HTMLEventName
            case "RunSimulation"
                data = event.HTMLEventData;
                idxOrbital = double(data.orbital);
                faultName = string(data.fault);
                runAndPlot(fig, idxOrbital, faultName);
            otherwise
                % No se esperan otros eventos desde el HTML.
        end
    catch ME
        sendEventToHTMLSource(src, "SimError", ME.message);
    end
end

function runAndPlot(fig, idxOrbital, faultName)
    s = fig.UserData;
    h = s.html;

    % Validacion del caso orbital.
    if idxOrbital < 1 || idxOrbital > numel(s.casos)
        error("dashboard_eps:casoOrbitalInvalido", ...
            "Caso orbital fuera de rango: %d. Debe estar entre 1 y %d.", ...
            idxOrbital, numel(s.casos));
    end

    % Iluminacion: calculo caro (WMM por paso). Se cachea por caso orbital.
    if isempty(s.gCache{idxOrbital})
        sendEventToHTMLSource(h, "SimBusy", ...
            sprintf("Calculando iluminacion del caso %d (WMM, primera vez)...", idxOrbital));
        drawnow;
        caso = s.casos(idxOrbital);
        [gPx, gNx, gPy, gNy, gTot] = Iluminacion_act_efe(s.t, s.hOrb, ...
            caso.delta_RAAN_deg, caso.w_spin, day(s.fecha), month(s.fecha), year(s.fecha));
        cache.gPaneles = [gPx; gNx; gPy; gNy];
        cache.inEclipse = (gTot(:) == 0);
        cache.tPanel = calcular_temperatura_panel(cache.inEclipse, s.dt);
        s.gCache{idxOrbital} = cache;
        fig.UserData = s;
    end
    cache = s.gCache{idxOrbital};

    sendEventToHTMLSource(h, "SimBusy", "Simulando balance energetico...");
    drawnow;

    % Armado de simParams (mismo contrato que main.m / simular_caso_eps).
    simParams.Nt = numel(s.t);
    simParams.dt = s.dt;
    simParams.T_panel = cache.tPanel;
    simParams.G_paneles = cache.gPaneles;
    simParams.Panel_state = seleccionar_estado_paneles(faultName);   % valida el nombre
    simParams.P_CPU = s.pCpu;
    simParams.P_Rx = s.pRx;
    simParams.P_Tx = s.pTx;
    simParams.eta_DCDC = s.config.reguladores.eta_DCDC;
    simParams.Vo_RL = s.config.reguladores.Vo_RL;
    simParams.batteryParams = s.battery;
    simParams.ns_bat = s.battery.Ns;
    simParams.np_bat = s.battery.Np;
    simParams.cfg_modos = s.config.modos_eps;
    simParams.usar_mppt_dinamico = false;

    res = simular_caso_eps(simParams);

    % --- Gráficas ---
    tHours = s.t/3600;

    plot(s.axSoc, tHours, res.soc_bat, "LineWidth", 1.3, "Color", [0.18 0.43 0.96]);
    yline(s.axSoc, s.battery.soc_min_operativo, "--", "SOC min op");
    title(s.axSoc, sprintf("SOC - caso %d / %s", idxOrbital, faultName), "Interpreter", "none");
    grid(s.axSoc, "on");

    stairs(s.axModo, tHours, res.modo_eps, "LineWidth", 1.3, "Color", [0.86 0.36 0.10]);
    ylim(s.axModo, [-0.2 2.2]);
    yticks(s.axModo, [0 1 2]);
    yticklabels(s.axModo, {"Nominal", "Degradado", "Safe"});
    grid(s.axModo, "on");

    % --- Métricas de vuelta a la UI ---
    nMuestras = numel(res.modo_eps);
    result = struct( ...
        "status", "ok", ...
        "socMin", min(res.soc_bat), ...
        "socFinal", res.soc_bat(end), ...
        "pctNominal", 100*sum(res.modo_eps == 0)/nMuestras, ...
        "pctDegradado", 100*sum(res.modo_eps == 1)/nMuestras, ...
        "pctSafe", 100*sum(res.modo_eps == 2)/nMuestras);
    sendEventToHTMLSource(h, "SimDone", result);
end

%% MODIFICADO POR AGENTE — 2026-06-13 — Dashboard uihtml creado en la Fase 4 (skill matlab-uihtml-app-builder).
