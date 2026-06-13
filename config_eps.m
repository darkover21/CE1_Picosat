function config = config_eps()
%CONFIG_EPS Punto único de configuración del simulador EPS.
%
%% openspec
% @function config_eps
% @version 1.1
% @changed 2026-06-13 — Creado (Fase 2): centraliza parámetros de misión,
%          reguladores y umbrales EPS, sustituyendo literales de main.m y el
%          antiguo simParams.V_min_admisible. Cabecera migrada a openspec (Fase 3).
% @returns config {struct} [-] — Configuración con campos .mission (mu, SMA,
%          h_orb, T_orb, N_orb, dt), .reguladores (eta_DCDC, Vo_RL, G0) y
%          .modos_eps (umbrales de SOC, V_min_ocv y periodo_operacion).
% @throws (no lanza errores; función pura sin efectos secundarios)
% @example
%   config = config_eps();
%   dt        = config.mission.dt;          % paso temporal [s]
%   v_min_ocv = config.modos_eps.V_min_ocv; % umbral OCV de Safe [V]
% @see seleccionar_modo_eps, simular_caso_eps, main
%
% Supuestos: órbita SSO LEO circular; umbrales de modo basados en SOC y en
% OCV(SOC), NO en la tensión de bornes (ver seleccionar_modo_eps).

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

%% MODIFICADO POR AGENTE — 2026-06-13 — Fichero creado (configuración centralizada, Fase 2) y documentado con cabecera openspec (Fase 3).
