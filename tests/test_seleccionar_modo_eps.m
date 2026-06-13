function test_seleccionar_modo_eps()
%% ===== OPENSPEC =====
% @spec        test_seleccionar_modo_eps
% @purpose     Test unitario del fix del bug del umbral de tensión (FASE 1.1).
% @inputs      (ninguna)
% @outputs     imprime PASS/FAIL por comprobación.
% @assumes     El modo Safe NO debe activarse con SOC=0.80 y corriente nominal
%              de descarga, aunque la tensión de bornes caiga por debajo de los
%              3.3 V del antiguo umbral, porque ahora se decide por OCV(SOC).
% @changed     2026-06-13 creado en FASE 2.5.
% =====================

    % --- Preparación del path ---
    this_dir = fileparts(mfilename('fullpath'));
    root = fileparts(this_dir);
    addpath(root);
    addpath(fullfile(root, 'funciones'));

    fprintf('== test_seleccionar_modo_eps ==\n');

    % --- Parámetros ---
    batteryParams = importarParametrosBateria('dummy.txt');
    cfg = config_eps();
    cfg_modos = cfg.modos_eps;

    % Consumos nominales (perfil del enunciado, fase de CPU activa)
    pcpu_nom = 0.250; prx_nom = 0.050; ptx_nom = 0.150;

    % --- Caso 1: SOC alto (0.80), tensión de bornes por debajo de 3.3 V ---
    % OCV(0.80) = 3.31 V; con descarga I*Rint la tensión de bornes baja de 3.3,
    % lo que ANTES disparaba Safe de forma espuria.
    soc = 0.80;
    Voc_080 = interp1(batteryParams.soc_data, batteryParams.voc_data, soc);
    I_desc = -0.30;                                   % [A] descarga nominal aprox.
    V_bornes = Voc_080 + I_desc * batteryParams.Rint; % ~3.292 V (< 3.3 V)

    [~, ~, ~, modo] = seleccionar_modo_eps(V_bornes, soc, ...
        pcpu_nom, prx_nom, ptx_nom, 0, 0, batteryParams, cfg_modos);

    check(V_bornes < 3.3, ...
        sprintf('La tension de bornes (%.4f V) cae bajo el antiguo umbral 3.3 V', V_bornes));
    check(modo ~= 2, 'Modo Safe NO se activa con SOC=0.80 y descarga nominal');
    check(modo == 0, 'Modo seleccionado es Nominal (0) con SOC=0.80');

    % --- Caso 2 (control): SOC bajo (0.50) SÍ debe entrar en Safe ---
    soc_bajo = 0.50;
    Voc_bajo = interp1(batteryParams.soc_data, batteryParams.voc_data, soc_bajo);
    V_bornes2 = Voc_bajo + I_desc * batteryParams.Rint;
    [~, ~, ~, modo2] = seleccionar_modo_eps(V_bornes2, soc_bajo, ...
        pcpu_nom, prx_nom, ptx_nom, 0, 0, batteryParams, cfg_modos);
    check(modo2 == 2, 'Modo Safe SI se activa con SOC=0.50 (control positivo)');

    fprintf('\n');
end

function check(cond, msg)
    if cond
        fprintf('  PASS: %s\n', msg);
    else
        fprintf('  FAIL: %s\n', msg);
    end
    assert(cond, msg);
end
