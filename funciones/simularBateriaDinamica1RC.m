function [V_bat_next, soc_next, Vrc_next] = simularBateriaDinamica1RC( ...
    batteryParams, soc_prev, Vrc_prev, I_actual, dt, Ns, Np)

    % ============================================================
    % simularBateriaDinamica1RC
    %
    % Se mantiene el nombre y la interfaz de la función original
    % para no modificar el main.m del trabajo anterior.
    %
    % En esta versión, la función se adapta a la batería LiFePO4
    % del PocketQube. Aunque el nombre conserva "1RC", no se ajusta
    % una rama dinámica R1C1 porque no se dispone de ensayos de pulsos
    % de corriente en el datasheet. Por tanto, se emplea un modelo
    % cuasi-estático:
    %
    %   SOC(k+1) = SOC(k) + I_bat*dt/(3600*C_Ah)
    %   Vbat     = OCV(SOC) + I_bat*Rint
    %
    % Convención de signo:
    %   I_actual > 0  -> carga de batería
    %   I_actual < 0  -> descarga de batería
    %
    % Entradas:
    %   batteryParams : estructura con parámetros de batería
    %   soc_prev      : SOC anterior [-]
    %   Vrc_prev      : tensión rama RC anterior [V], no usada aquí
    %   I_actual      : corriente de batería [A]
    %   dt            : paso temporal [s]
    %   Ns, Np        : se mantienen por compatibilidad
    %
    % Salidas:
    %   V_bat_next    : tensión de batería actualizada [V]
    %   soc_next      : SOC actualizado [-]
    %   Vrc_next      : tensión rama RC actualizada [V], igual a 0
    % ============================================================

    %#ok<INUSD>
    % Vrc_prev, Ns y Np se mantienen para conservar
    % compatibilidad con el main anterior.

    % ------------------------------------------------------------
    % Seguridad numérica de entradas
    % ------------------------------------------------------------
    if ~isfinite(soc_prev)
        if isfield(batteryParams, 'soc_init')
            soc_prev = batteryParams.soc_init;
        else
            soc_prev = 0.8;
        end
    end

    if ~isfinite(I_actual)
        I_actual = 0;
    end

    if ~isfinite(dt) || dt <= 0
        dt = 1;
    end

    soc_prev = max(0, min(1, soc_prev));

    % ------------------------------------------------------------
    % Parámetros de la batería
    % ------------------------------------------------------------
    C_Ah = batteryParams.C_Ah;      % [Ah], una celda LiFePO4
    Rint = batteryParams.Rint;      % [Ohm], 60 mOhm del datasheet

    V_max    = batteryParams.V_max;
    V_cutoff = batteryParams.V_cutoff;

    % ------------------------------------------------------------
    % Actualización del SOC
    % ------------------------------------------------------------
    % I_actual > 0: carga  -> aumenta SOC
    % I_actual < 0: descarga -> disminuye SOC
    dQ_Ah = I_actual * dt / 3600;      % [Ah]
    soc_next = soc_prev + dQ_Ah / C_Ah;

    % Saturación física del SOC
    soc_next = max(0, min(1, soc_next));

    % ------------------------------------------------------------
    % Cálculo de OCV a partir del SOC
    % ------------------------------------------------------------
    % La curva SOC-OCV procede de una aproximación por tramos lineales
    % de las curvas de descarga del datasheet.
    Voc = interp1( ...
        batteryParams.soc_data, ...
        batteryParams.voc_data, ...
        soc_next, ...
        'linear', ...
        'extrap');

    % Saturar la OCV para evitar extrapolaciones no físicas
    Voc = max(V_cutoff, min(V_max, Voc));

    % ------------------------------------------------------------
    % Rama dinámica RC
    % ------------------------------------------------------------
    % No se usa rama dinámica porque no se dispone de datos de pulsos
    % para ajustar R1 y C1. Se devuelve cero para mantener la salida.
    Vrc_next = 0;

    % ------------------------------------------------------------
    % Tensión en bornes de la batería
    % ------------------------------------------------------------
    % Con la convención del main:
    %   carga    I_actual > 0 -> Vbat sube por Rint
    %   descarga I_actual < 0 -> Vbat baja por Rint
    V_bat_next = Voc + I_actual * Rint;

    % Saturación física de tensión
    V_bat_next = max(V_cutoff, min(V_max, V_bat_next));

end