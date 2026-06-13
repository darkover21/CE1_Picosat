function config = config_eps()
%% ===== OPENSPEC =====
% @spec        config_eps
% @purpose     Punto único de configuración del simulador EPS. Centraliza
%              todos los parámetros físicos (misión, reguladores y umbrales
%              de los modos EPS) para evitar valores "hardcodeados" dispersos
%              por main.m / simParams.
% @inputs      (ninguna)
% @outputs     config : struct con campos .mission, .reguladores, .modos_eps
% @assumes     - Órbita SSO LEO circular (mu, SMA del Word de documentación).
%              - Umbrales de los modos EPS basados en SOC y en OCV(SOC),
%                NO en la tensión de bornes (ver [[seleccionar_modo_eps]]).
% @changed     2026-06-13 creado en la FASE 2; sustituye los literales
%              numéricos de main.m y el antiguo simParams.V_min_admisible.
% =====================

    config = struct();

    % ------------------------------------------------------------
    % 1. PARÁMETROS DE MISIÓN
    % ------------------------------------------------------------
    config.mission.mu    = 398600.4418;   % [km^3/s^2] mu Tierra
    config.mission.SMA   = 6971;          % [km] semieje mayor
    config.mission.R_T   = 6371;          % [km] radio terrestre
    config.mission.h_orb = config.mission.SMA - config.mission.R_T;   % [km] altitud
    config.mission.T_orb = 2*pi*sqrt(config.mission.SMA^3 / config.mission.mu);  % [s] ~5786 s
    config.mission.N_orb = 10;            % [-] nº de periodos a simular (mínimo del enunciado)
    config.mission.dt    = 1;             % [s] paso temporal del bucle

    % ------------------------------------------------------------
    % 2. CONSTANTES DE LOS REGULADORES
    % ------------------------------------------------------------
    config.reguladores.eta_DCDC = 0.90;   % [-] eficiencia del DC/DC del bus
    config.reguladores.Vo_RL    = 2.2;    % [V] salida de los reguladores lineales
    config.reguladores.G0       = 1367;   % [W/m^2] constante solar (LEO)

    % ------------------------------------------------------------
    % 3. UMBRALES DE LOS MODOS EPS  (Nominal / Degradado / Safe)
    % ------------------------------------------------------------
    % SOC = 1 - DoD. Las transiciones de modo son por SOC con histéresis.
    % La condición de tensión usa OCV(SOC), NO la tensión de bornes, para
    % evitar disparar Safe por la caída I*Rint con SOC todavía alto.
    config.modos_eps.SOC_entra_degradado = 0.70;   % entra a degradado con DoD >= 30%
    config.modos_eps.SOC_sale_degradado  = 0.80;   % sale a nominal con DoD <= 20%
    config.modos_eps.SOC_entra_safe      = 0.55;    % entra a safe con DoD >= 45%
    config.modos_eps.SOC_sale_safe       = 0.65;    % sale de safe (histéresis)

    % Umbral de tensión de circuito abierto para entrar en Safe.
    % 3.05 V corresponde a OCV(SOC ~= 0.55) según la tabla de la batería
    % LiFePO4 ACL9011 (ver [[importarParametrosBateria]]).
    config.modos_eps.V_min_ocv = 3.05;    % [V] OCV mínima admisible

    config.modos_eps.periodo_operacion = 120;   % [s] ciclo de operación del enunciado

end
