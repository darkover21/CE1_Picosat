
function [P_CPU, P_Rx, P_Tx, P_total] = perfil_consumo(t)

%Esta función calcula el perfil de consumo de potencia para un tiempo t
%determinado. 
%Además, devuelve la potencia útil consumida por los equipos:
% P_CPU: Potencia CPU [W]
% P_Rx: Potencia Receptor [W]
% P_Tx: Potencia Transmisor [W]
% P_total: Potencia útil total [W]

    T_cycle = 120; % [s] ciclo de 2 minutos. Del enunciado.

    %Potencias del enunciado

    P_CPU_max = 250e-03; % [W]
    P_CPU_min = 10e-03; % [W]
    P_Rx_on = 50e-03; % [W]
    P_Tx_on = 150e-03; % [W]

    %Tiempo dentro de cada ciclo

    tau = mod(t,T_cycle);

    %Inicialización
    P_CPU = zeros (size(t));
    P_Rx = zeros (size(t));
    P_Tx = zeros (size(t));

    %CPU: del enunciado, 30% del tiempo
    P_CPU(tau < 0.30*T_cycle) = P_CPU_max;
    P_CPU(tau >= 0.30*T_cycle) = P_CPU_min;

    %Rx: del enunciado, 100% del tiempo
    P_Rx(:) = P_Rx_on;

    %Tx: del enunciado, 50% del tiempo, después de fase de CPU
    t_tx_ini = 0.30*T_cycle;
    t_tx_fin = t_tx_ini + 0.50*T_cycle;
    P_Tx(tau >= t_tx_ini & tau < t_tx_fin) = P_Tx_on;
    %Potencia total útil
    P_total = P_CPU + P_Rx + P_Tx;
end 


