function [pcpu, prx, ptx, modo_eps] = seleccionar_modo_eps(V_bat, soc_bat, pcpu_nom, prx_nom, ptx_nom, modo_anterior, t_actual, batteryParams, cfg_modos)
%SELECCIONAR_MODO_EPS Máquina de estados del EPS y consumos útiles por modo.
%
%% openspec
% @function seleccionar_modo_eps
% @version 1.1
% @changed 2026-06-13 — Fase 1.1: corregido el bug del umbral de tensión. Antes
%          comparaba V_bat <= V_min_admisible (3.3 V), disparando Safe falso con
%          SOC ~= 0.80; ahora compara OCV(SOC) <= V_min_ocv (3.05 V). Umbrales
%          movidos a config_eps (cfg_modos) y firma actualizada. Cabecera openspec (Fase 3).
% @param V_bat {double} [V] — Tensión de bornes actual (informativa; no decide el modo)
% @param soc_bat {double} [-] — Estado de carga actual
% @param pcpu_nom {double} [W] — Consumo útil nominal de CPU
% @param prx_nom {double} [W] — Consumo útil nominal de Rx
% @param ptx_nom {double} [W] — Consumo útil nominal de Tx
% @param modo_anterior {double} [-] — Modo del paso previo (0 Nominal / 1 Degradado / 2 Safe)
% @param t_actual {double} [s] — Tiempo actual de simulación
% @param batteryParams {struct} [-] — Parámetros de batería con la curva OCV(SOC) (soc_data/voc_data)
% @param cfg_modos {struct} [-] — Umbrales EPS de config_eps().modos_eps
% @returns pcpu {double} [W] — Consumo útil de CPU aplicado tras la selección de modo
% @returns prx {double} [W] — Consumo útil de Rx aplicado tras la selección de modo
% @returns ptx {double} [W] — Consumo útil de Tx aplicado tras la selección de modo
% @returns modo_eps {double} [-] — Modo seleccionado (0 Nominal / 1 Degradado / 2 Safe)
% @throws interp1:NotEnoughPts — si batteryParams.soc_data/voc_data no son vectores válidos
% @example
%   bp  = importarParametrosBateria("dummy.txt");
%   cfg = config_eps();
%   [pc, pr, pt, modo] = seleccionar_modo_eps(3.29, 0.80, 0.25, 0.05, 0.15, 0, 0, bp, cfg.modos_eps);
%   % modo == 0 (Nominal): SOC alto, no entra en Safe pese a V_bat < 3.3 V
% @see config_eps, simular_caso_eps, simularBateriaDinamica1RC
%
% Supuesto clave: la entrada/salida de Safe se decide por SOC (condición
% primaria) y por OCV(SOC) <= V_min_ocv, NO por la tensión de bornes V_bat
% (que cae por I*Rint y disparaba Safe de forma espuria con SOC todavía alto).

    % Modos:
    %   0 -> nominal
    %   1 -> degradado
    %   2 -> safe
    %
    % SOC = 1 - DoD
    %
    % Degradado:
    %   entra con DoD >= 30%  -> SOC <= 0.70
    %   sale  con DoD <= 20%  -> SOC >= 0.80
    %
    % Safe:
    %   entra con DoD >= 45%  -> SOC <= 0.55  (condición primaria)
    %   o si la OCV(SOC) cae por debajo de V_min_ocv.

    SOC_entra_degradado = cfg_modos.SOC_entra_degradado;
    SOC_sale_degradado  = cfg_modos.SOC_sale_degradado;

    SOC_entra_safe = cfg_modos.SOC_entra_safe;
    SOC_sale_safe  = cfg_modos.SOC_sale_safe;

    V_min_ocv = cfg_modos.V_min_ocv;

    periodo_operacion = cfg_modos.periodo_operacion;  % [s] ciclo de operacion del enunciado

    % ------------------------------------------------------------
    % Tension de circuito abierto a partir del SOC
    % ------------------------------------------------------------
    % Se evalua sobre la curva OCV(SOC) de la bateria, NO sobre la tension
    % de bornes V_bat: esta ultima cae por I*Rint y activaba Safe de forma
    % espuria con SOC todavia alto (~0.80).
    Voc = interp1(batteryParams.soc_data, batteryParams.voc_data, ...
                  soc_bat, 'linear', 'extrap');

    pcpu = pcpu_nom;
    prx  = prx_nom;
    ptx  = ptx_nom;

    modo_eps = modo_anterior;

    % ------------------------------------------------------------
    % Seleccion del modo con histeresis
    % ------------------------------------------------------------

    if modo_anterior == 2

        % Salir de Safe: SOC recuperado (condicion primaria) y OCV por encima
        % del minimo.
        if soc_bat >= SOC_sale_safe && Voc > V_min_ocv
            modo_eps = 1;
        else
            modo_eps = 2;
        end

    elseif modo_anterior == 1

        if soc_bat <= SOC_entra_safe || Voc <= V_min_ocv
            modo_eps = 2;
        elseif soc_bat >= SOC_sale_degradado
            modo_eps = 0;
        else
            modo_eps = 1;
        end

    else

        if soc_bat <= SOC_entra_safe || Voc <= V_min_ocv
            modo_eps = 2;
        elseif soc_bat <= SOC_entra_degradado
            modo_eps = 1;
        else
            modo_eps = 0;
        end

    end

    % ------------------------------------------------------------
    % Aplicacion de consumos segun modo
    % ------------------------------------------------------------

    ciclo = floor(t_actual / periodo_operacion);
    tiempo_en_ciclo = mod(t_actual, periodo_operacion);

    if modo_eps == 1

        % Modo degradado:
        % Se mantiene el procesado y la recepcion.
        % La transmision se permite solo cada 3 ciclos de operacion.

        pcpu = pcpu_nom;
        prx  = prx_nom;

        if mod(ciclo, 3) == 0
            ptx = ptx_nom;
        else
            ptx = 0;
        end

    elseif modo_eps == 2

        % Modo safe:
        % Se apaga el procesador.
        % La recepcion queda activa solo al inicio de cada ciclo para
        % poder recibir telecomandos.
        % La transmision se reduce a una ventana puntual cada 5 ciclos.

        pcpu = 0;

        if tiempo_en_ciclo < 10
            prx = prx_nom;
        else
            prx = 0;
        end

        if mod(ciclo, 5) == 0 && tiempo_en_ciclo < 10
            ptx = ptx_nom;
        else
            ptx = 0;
        end

    end

end

%% MODIFICADO POR AGENTE — 2026-06-13 — Fix umbral Safe basado en OCV(SOC), umbrales desde config_eps y cabecera openspec.
