function res = simular_caso_eps(simParams)
%SIMULAR_CASO_EPS Ejecuta el bucle temporal principal del modelo EPS.
%
%% openspec
% @function simular_caso_eps
% @version 1.1
% @changed 2026-06-13 — Fase 1.1: firma de seleccionar_modo_eps (cfg_modos + OCV);
%          Fase 2.6: MPPT Incremental Conductance dinámico opcional por panel.
%          Cabecera migrada a openspec (Fase 3).
% @param simParams {struct} [-] — Parámetros y entradas de simulación: dt [s], Nt,
%          T_panel [°C], G_paneles [W/m^2], Panel_state, perfiles P_CPU/P_Rx/P_Tx [W],
%          eta_DCDC, Vo_RL [V], batteryParams, ns_bat, np_bat, cfg_modos y el flag
%          opcional usar_mppt_dinamico {logical}.
% @returns res {struct} [-] — Series temporales: W_gen/W_bus [W], corrientes [A],
%          V_bat [V], soc_bat [-], modo_eps (0/1/2), Pbus_panel [W] por panel, etc.
% @throws (emite warning y detiene el bucle si Vbus <= 0; no lanza error)
% @example
%   config = config_eps();
%   simParams = struct("Nt",10,"dt",1, ... );   % ver main.m para el armado completo
%   simParams.cfg_modos = config.modos_eps;
%   res = simular_caso_eps(simParams);
%   plot(res.soc_bat);
% @see config_eps, seleccionar_modo_eps, curvas_IV_Temperatura, mppt_incremental_conductance_step
%
% Supuestos:
%   - Convención de batería: I_bat>0 carga, I_bat<0 descarga.
%   - Por defecto la extracción de los paneles usa eta_MPPT=0.92 constante
%     (dentro de curvas_IV_Temperatura). Si usar_mppt_dinamico=true se usa
%     mppt_incremental_conductance_step.

    %% -------------------- Extraer parámetros ---------------------------

    Nt = simParams.Nt;
    dt = simParams.dt;

    T_panel = simParams.T_panel;
    G_paneles = simParams.G_paneles;
    Panel_state = simParams.Panel_state;

    P_CPU = simParams.P_CPU;
    P_Rx  = simParams.P_Rx;
    P_Tx  = simParams.P_Tx;

    eta_DCDC = simParams.eta_DCDC;
    Vo_RL = simParams.Vo_RL;

    batteryParams = simParams.batteryParams;
    ns_bat = simParams.ns_bat;
    np_bat = simParams.np_bat;

    % Umbrales de los modos EPS (FASE 2: centralizados en config_eps).
    cfg_modos = simParams.cfg_modos;

    % FASE 2.6: seguimiento del punto de máxima potencia.
    %   false -> eta_MPPT = 0.92 constante (dentro de curvas_IV_Temperatura)
    %   true  -> MPPT Incremental Conductance dinámico por panel
    if isfield(simParams, 'usar_mppt_dinamico')
        usar_mppt_dinamico = simParams.usar_mppt_dinamico;
    else
        usar_mppt_dinamico = false;
    end


    %% -------------------- Reserva de memoria ---------------------------

    W_gen     = zeros(Nt,1);
    W_bus     = zeros(Nt,1);

    I_CPU_bus = zeros(Nt,1);
    I_Rx_bus  = zeros(Nt,1);
    I_Tx_bus  = zeros(Nt,1);

    W_bat     = zeros(Nt,1);
    I_bat     = zeros(Nt,1);

    V_bat     = zeros(Nt,1);
    soc_bat   = zeros(Nt,1);
    Vrc_bat   = zeros(Nt,1);

    W_disip   = zeros(Nt,1);
    W_dump    = zeros(Nt,1);   % Potencia excedente disipada/no aprovechada [W]
    modo_safe = zeros(Nt,1);
    modo_eps = zeros(Nt,1);
    P_CPU_real = zeros(Nt,1);
    P_Rx_real  = zeros(Nt,1);
    P_Tx_real  = zeros(Nt,1);

    Pbus_panel = zeros(Nt,4);

    % Estado del MPPT dinámico por panel (solo se usa si usar_mppt_dinamico)
    mppt_Vref  = zeros(1,4);
    mppt_Vprev = zeros(1,4);
    mppt_Iprev = zeros(1,4);
    mppt_init  = false(1,4);


    %% -------------------- Condición inicial ----------------------------

    soc_bat(1) = batteryParams.soc_init;

    [V_bat(1), ~, ~] = simularBateriaDinamica1RC( ...
        batteryParams, soc_bat(1), 0, 0, dt, ns_bat, np_bat);


    %% -------------------- Bucle de simulación --------------------------

    for i = 1:Nt

        Vbus = V_bat(i);

        % Evitar divisiones entre cero o valores no físicos
        if Vbus <= 0
            warning('Vbus no físico en i = %d. Se detiene la simulación.', i);
            break;
        end


        %% -------- 1. Generación de los paneles -------------------------

        for j = 1:4

            if G_paneles(j,i) > 0 && Panel_state(j) == 1
                % Panel nominal 1S2P
                Ns_j = 1; Np_j = 2;
            elseif G_paneles(j,i) > 0 && Panel_state(j) == 0.5
                % Panel degradado, equivalente a 1S1P
                Ns_j = 1; Np_j = 1;
            else
                % Panel sin iluminación o panel roto
                Pbus_panel(i,j) = 0;
                continue;
            end

            [Pmp_j, Pbus_eta, V_PS, I_PS] = curvas_IV_Temperatura( ...
                T_panel(i), G_paneles(j,i), Ns_j, Np_j);

            if usar_mppt_dinamico

                % Arranque del seguidor cerca del Vmp en la primera iteración
                % con sol de cada panel.
                if ~mppt_init(j)
                    mppt_Vref(j) = 0.8 * max(V_PS);
                    mppt_init(j) = true;
                end

                [Ppv_op, Vref_next, Vprev_new, Iprev_new] = ...
                    mppt_incremental_conductance_step( ...
                        mppt_Vref(j), mppt_Vprev(j), mppt_Iprev(j), ...
                        V_PS, I_PS, Pmp_j);

                Pbus_panel(i,j) = Ppv_op;

                mppt_Vref(j)  = Vref_next;
                mppt_Vprev(j) = Vprev_new;
                mppt_Iprev(j) = Iprev_new;

            else
                % eta_MPPT = 0.92 constante (dentro de curvas_IV_Temperatura)
                Pbus_panel(i,j) = Pbus_eta;
            end

        end

        W_gen(i) = sum(Pbus_panel(i,:));


        %% -------- 2. Consumo útil de las cargas ------------------------

        pcpu = P_CPU(i);
        prx  = P_Rx(i);
        ptx  = P_Tx(i);


        %% -------- 3. Estrategia de protección --------------------------
        
        if i == 1
            modo_anterior = 0;
        else
            modo_anterior = modo_eps(i-1);
        end
        
        t_actual = (i-1)*dt;

        [pcpu, prx, ptx, modo_eps(i)] = seleccionar_modo_eps( ...
            V_bat(i), ...
            soc_bat(i), ...
            pcpu, ...
            prx, ...
            ptx, ...
            modo_anterior, ...
            t_actual, ...
            batteryParams, ...
            cfg_modos);
        
        if modo_eps(i) == 2
            modo_safe(i) = 1;
        end
        
        P_CPU_real(i) = pcpu;
        P_Rx_real(i)  = prx;
        P_Tx_real(i)  = ptx;


        %% -------- 4. Consumo visto desde el bus de batería -------------

        % DC/DC
        P_CPU_bus = pcpu / eta_DCDC;
        I_CPU_bus(i) = P_CPU_bus / Vbus;

        % Reguladores lineales
        I_Rx_bus(i) = prx / Vo_RL;
        I_Tx_bus(i) = ptx / Vo_RL;

        P_Rx_bus = prx * Vbus / Vo_RL;
        P_Tx_bus = ptx * Vbus / Vo_RL;

        W_bus(i) = P_CPU_bus + P_Rx_bus + P_Tx_bus;


        %% -------- 5. Potencia disipada --------------------------------

        W_disip(i) = ...
            (P_CPU_bus - pcpu) + ...
            (P_Rx_bus  - prx)  + ...
            (P_Tx_bus  - ptx);


       %% -------- 6. Balance energético y batería ---------------------

        % Convención:
        % I_bat > 0  -> batería carga
        % I_bat < 0  -> batería descarga
        
        SOC_dump = 1.00;   % umbral de limitación de carga
        
        W_balance = W_gen(i) - W_bus(i);
        
        if soc_bat(i) >= SOC_dump && W_balance > 0
            % Batería suficientemente cargada y sobra potencia:
            % el excedente se disipa/no se aprovecha
            W_dump(i) = W_balance;
            W_bat(i)  = 0;
            I_bat(i)  = 0;
        else
            % Caso normal: la batería carga o descarga
            W_bat(i) = W_balance;
            I_bat(i) = W_bat(i) / Vbus;
        end
        
        if i < Nt
            [V_bat(i+1), soc_bat(i+1), Vrc_bat(i+1)] = ...
                simularBateriaDinamica1RC( ...
                    batteryParams, ...
                    soc_bat(i), ...
                    Vrc_bat(i), ...
                    I_bat(i), ...
                    dt, ...
                    ns_bat, ...
                    np_bat);
        end

    end 


    %% -------------------- Empaquetar resultados ------------------------

        res.W_gen     = W_gen;
        res.W_bus     = W_bus;
        
        res.I_CPU_bus = I_CPU_bus;
        res.I_Rx_bus  = I_Rx_bus;
        res.I_Tx_bus  = I_Tx_bus;
        
        res.W_bat     = W_bat;
        res.I_bat     = I_bat;
        
        res.V_bat     = V_bat;
        res.soc_bat   = soc_bat;
        res.Vrc_bat   = Vrc_bat;
        
        res.W_disip   = W_disip;
        res.W_dump    = W_dump;
        res.W_disip_total = W_disip + W_dump;
        
        res.modo_safe = modo_safe;
        res.modo_eps  = modo_eps;
        
        res.P_CPU_real = P_CPU_real;
        res.P_Rx_real  = P_Rx_real;
        res.P_Tx_real  = P_Tx_real;
        
        res.Pbus_panel = Pbus_panel;
end

%% MODIFICADO POR AGENTE — 2026-06-13 — Firma OCV de seleccionar_modo_eps, MPPT IC opcional por panel y cabecera openspec.