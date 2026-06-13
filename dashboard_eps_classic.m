function dashboard_eps_classic()
%DASHBOARD_EPS_CLASSIC Panel de control del simulador EPS con figura clásica.
%
%% openspec
% @function dashboard_eps_classic
% @version 1.0
% @changed 2026-06-13 — Creado (Fase 4) como alternativa a dashboard_eps que NO
%          usa uihtml/uifigure (motor CEF/webgui). Útil cuando el renderizador
%          web de MATLAB falla (ERR_CERT_AUTHORITY_INVALID por antivirus/proxy
%          en localhost). Mismos selectores y gráficas (SOC y modo EPS).
% @param (script de lanzamiento; no recibe argumentos)
% @returns (ninguno; abre una figura clásica interactiva)
% @throws (los errores de simulación se capturan y se muestran en el texto de estado)
% @example
%   dashboard_eps_classic();   % elige caso y fallo y pulsa «Simular»
% @see dashboard_eps, config_eps, simular_caso_eps, seleccionar_estado_paneles
%
% Usa el renderizador heredado (figure + uicontrol + axes), por lo que no
% depende del motor CEF/webgui que requiere uifigure. La iluminación (cara por
% el WMM) se cachea por caso orbital, igual que en dashboard_eps.

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

    faultNames = { ...
        'nominal', ...
        'fallo_celda_Xp', 'fallo_celda_Xn', 'fallo_celda_Yp', 'fallo_celda_Yn', ...
        'fallo_dos_celdas_Xp_Yp', 'fallo_dos_celdas_Xp_Yn', ...
        'fallo_dos_celdas_Xn_Yp', 'fallo_dos_celdas_Xn_Yn', ...
        'fallo_dos_celdas_Xp_Xn', 'fallo_dos_celdas_Yp_Yn', ...
        'fallo_panel_Xp', 'fallo_panel_Xn', 'fallo_panel_Yp', 'fallo_panel_Yn'};

    orbitalLabels = { ...
        '1 - LTAN1, sin spin (w=0)', '2 - LTAN1, spin lento (w=0.1)', ...
        '3 - LTAN2, sin spin (w=0)', '4 - LTAN2, spin lento (w=0.1)'};

    % --- Figura clásica (renderizador heredado, sin CEF) ---
    f = figure("Name", "Dashboard EPS (clasico) - PocketQube 2P", ...
        "NumberTitle", "off", "Color", "w", "Position", [100 90 980 720]);

    uicontrol(f, "Style", "text", "String", "Caso orbital", ...
        "Units", "normalized", "Position", [0.05 0.945 0.20 0.03], ...
        "BackgroundColor", "w", "HorizontalAlignment", "left", "FontWeight", "bold");
    ddOrb = uicontrol(f, "Style", "popupmenu", "String", orbitalLabels, ...
        "Units", "normalized", "Position", [0.05 0.905 0.27 0.04]);

    uicontrol(f, "Style", "text", "String", "Escenario de fallo", ...
        "Units", "normalized", "Position", [0.35 0.945 0.25 0.03], ...
        "BackgroundColor", "w", "HorizontalAlignment", "left", "FontWeight", "bold");
    ddFault = uicontrol(f, "Style", "popupmenu", "String", faultNames, ...
        "Units", "normalized", "Position", [0.35 0.905 0.32 0.04]);

    btn = uicontrol(f, "Style", "pushbutton", "String", "Simular", ...
        "Units", "normalized", "Position", [0.70 0.905 0.13 0.04], ...
        "FontWeight", "bold");

    txt = uicontrol(f, "Style", "text", ...
        "String", "Selecciona un caso y un fallo, y pulsa «Simular».", ...
        "Units", "normalized", "Position", [0.05 0.855 0.90 0.035], ...
        "BackgroundColor", "w", "HorizontalAlignment", "left", "ForegroundColor", [0.3 0.3 0.3]);

    axSoc = axes("Parent", f, "Units", "normalized", "Position", [0.09 0.47 0.86 0.33]);
    title(axSoc, "SOC de la bateria");
    xlabel(axSoc, "Tiempo [h]");
    ylabel(axSoc, "SOC [-]");
    grid(axSoc, "on");

    axModo = axes("Parent", f, "Units", "normalized", "Position", [0.09 0.08 0.86 0.30]);
    title(axModo, "Modo EPS");
    xlabel(axModo, "Tiempo [h]");
    ylabel(axModo, "Modo");
    grid(axModo, "on");

    % --- Estado compartido ---
    s.config = config;
    s.t = tDashboard;
    s.dt = dtDashboard;
    s.casos = casosOrbitales;
    s.battery = batteryParams;
    s.fecha = fecha;
    s.pCpu = pCpu;
    s.pRx = pRx;
    s.pTx = pTx;
    s.hOrb = config.mission.h_orb;
    s.gCache = cell(1, numel(casosOrbitales));
    s.faultNames = faultNames;
    s.axSoc = axSoc;
    s.axModo = axModo;
    s.txt = txt;
    s.ddOrb = ddOrb;
    s.ddFault = ddFault;
    guidata(f, s);

    btn.Callback = @(src, evt) onSimular(f);
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

function onSimular(f)
    s = guidata(f);
    try
        idxOrbital = get(s.ddOrb, "Value");
        faultName = string(s.faultNames{get(s.ddFault, "Value")});

        % Iluminacion: calculo caro (WMM por paso). Se cachea por caso orbital.
        if isempty(s.gCache{idxOrbital})
            setStatus(s.txt, sprintf("Calculando iluminacion del caso %d (WMM, primera vez)...", idxOrbital), [0.3 0.3 0.3]);
            drawnow;
            caso = s.casos(idxOrbital);
            [gPx, gNx, gPy, gNy, gTot] = Iluminacion_act_efe(s.t, s.hOrb, ...
                caso.delta_RAAN_deg, caso.w_spin, day(s.fecha), month(s.fecha), year(s.fecha));
            cache.gPaneles = [gPx; gNx; gPy; gNy];
            cache.inEclipse = (gTot(:) == 0);
            cache.tPanel = calcular_temperatura_panel(cache.inEclipse, s.dt);
            s.gCache{idxOrbital} = cache;
            guidata(f, s);
        end
        cache = s.gCache{idxOrbital};

        setStatus(s.txt, "Simulando balance energetico...", [0.3 0.3 0.3]);
        drawnow;

        simParams.Nt = numel(s.t);
        simParams.dt = s.dt;
        simParams.T_panel = cache.tPanel;
        simParams.G_paneles = cache.gPaneles;
        simParams.Panel_state = seleccionar_estado_paneles(faultName);
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

        tHours = s.t/3600;
        plot(s.axSoc, tHours, res.soc_bat, "LineWidth", 1.3, "Color", [0.18 0.43 0.96]);
        yline(s.axSoc, s.battery.soc_min_operativo, "--", "SOC min op");
        title(s.axSoc, sprintf("SOC - caso %d / %s", idxOrbital, faultName), "Interpreter", "none");
        xlabel(s.axSoc, "Tiempo [h]");
        ylabel(s.axSoc, "SOC [-]");
        grid(s.axSoc, "on");

        stairs(s.axModo, tHours, res.modo_eps, "LineWidth", 1.3, "Color", [0.86 0.36 0.10]);
        ylim(s.axModo, [-0.2 2.2]);
        yticks(s.axModo, [0 1 2]);
        yticklabels(s.axModo, {"Nominal", "Degradado", "Safe"});
        xlabel(s.axModo, "Tiempo [h]");
        ylabel(s.axModo, "Modo");
        grid(s.axModo, "on");

        nMuestras = numel(res.modo_eps);
        msg = sprintf(["OK | SOC min=%.4f  SOC final=%.4f  |  " ...
            "Nominal=%.1f%%  Degradado=%.1f%%  Safe=%.1f%%"], ...
            min(res.soc_bat), res.soc_bat(end), ...
            100*sum(res.modo_eps == 0)/nMuestras, ...
            100*sum(res.modo_eps == 1)/nMuestras, ...
            100*sum(res.modo_eps == 2)/nMuestras);
        setStatus(s.txt, msg, [0.0 0.55 0.2]);

    catch ME
        setStatus(s.txt, sprintf("Error: %s", ME.message), [0.8 0.1 0.1]);
    end
end

function setStatus(txt, msg, color)
    set(txt, "String", msg, "ForegroundColor", color);
end

%% MODIFICADO POR AGENTE — 2026-06-13 — Dashboard clásico (sin CEF/uihtml) como alternativa robusta cuando falla el renderizador web de MATLAB.
