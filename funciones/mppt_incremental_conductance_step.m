function [Ppv_op, Vref_next, Vprev_new, Iprev_new, eta_track, Vop, Iop] = ...
    mppt_incremental_conductance_step(Vref, Vprev, Iprev, V_PS, I_PS, Pmp_panel)
%MPPT_INCREMENTAL_CONDUCTANCE_STEP undefined
% Implementa un paso del algoritmo Incremental Conductance.
%
% Entradas:
%   Vref       : tensión de operación impuesta en el instante actual [V]
%   Vprev      : tensión de operación medida en el paso anterior [V]
%   Iprev      : corriente medida en el paso anterior [A]
%   V_PS       : vector de tensiones de la curva I-V actual [V]
%   I_PS       : vector de corrientes de la curva I-V actual [A]
%   Pmp_panel  : potencia máxima ideal del panel en la curva actual [W]
%
% Salidas:
%   Ppv_op     : potencia extraída del panel en el punto de operación actual [W]
%   Vref_next  : tensión de operación para el siguiente paso temporal [V]
%   Vprev_new  : tensión medida actual, guardada para el siguiente paso [V]
%   Iprev_new  : corriente medida actual, guardada para el siguiente paso [A]
%   eta_track  : eficiencia de seguimiento Ppv_op/Pmp_panel [-]
%   Vop        : tensión de operación actual limitada [V]
%   Iop        : corriente de operación actual [A]
    
    Voc = max(V_PS);

    %% TENSIÓN DE OPERACIÓN ACTUAL:
    % se va a limitar en valores que no llegan al cero o al valor
    % máximo para evitar errores numéricos (Evitar que I = 0 o que V = 0)
    Vmin = 0.02 * Voc;
    Vmax = 0.98 * Voc;
    Vop = max(Vmin, min(Vref, Vmax));

    %% CORRIENTE Y POTENCIA EN EL PUNTO DE OPERACIÓN ACTUAL

    Iop = interp1(V_PS, I_PS, Vop, 'linear', 0);
    Ppv_op = Vop * Iop;

    %% INCREMENTOS
    dV = Vop - Vprev;
    dI = Iop - Iprev;

    %% CONDICIONAL
    % si está cerca del Vmp el sigioente punto de op siga constante y si está
    % por encima o por debajo actúe según lo que corresponda
    
    % CAMBIAR !! 
    dVref = 0.01;   % Define cuanto se mueve el punto de operación si es 
    % grande oscila mucho si es pequeño oscila poco pero tarda más en converger.
    tolV = 1e-8;
    tolI = 1e-8;
    tolCond = 1e-5;

    if abs(dV) < tolV

        if abs(dI) < tolI
            % Si ni la tensión ni
            % la corriente varían entonces se mantiene constante
            Vref_next = Vop;

        elseif dI > 0
            % Si la tensión
            % apenas varía pero la intensidad si probablemente es porque ha
            % variado la irradiancia según el modelo de pindado-cubas de
            % las curvas I-V con la Temperatura
            Vref_next = Vop + dVref;

        else
            Vref_next = Vop - dVref;
        end

    else

        inc_cond  = dI / dV;
        inst_cond = -Iop / Vop;

        if abs(inc_cond - inst_cond) < tolCond
            % Cerca del MPP entonces se mantiene el punto de operación
            Vref_next = Vop;

        elseif inc_cond > inst_cond
            % Izquierda del MPP--> se debe aumentar tensión
            Vref_next = Vop + dVref;

        else
            % Derecha del MPP--> se debe disminuir la tensión
            Vref_next = Vop - dVref;
        end
    end

    %% SE LIMITA LA NUEVA REFERENCIA
    Vref_next = max(Vmin, min(Vref_next, Vmax));

    %% GUARDAR EL PUNTO ACTUAL
    Vprev_new = Vop;
    Iprev_new = Iop;

    %% cÁLCULO DE EFICIENCIA
    eta_track = Ppv_op / Pmp_panel;
    eta_track = max(0, min(eta_track, 1)); % límite no puede ser mayor que 1 o menor que 0

end

