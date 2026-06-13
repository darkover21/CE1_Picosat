%dt = 1;
%in_eclipse = [true; true; true; false; false; false; false; false; true; true];
%T = calcular_temperatura_panel(in_eclipse, dt);
%disp(T)

function T_panel = calcular_temperatura_panel(in_eclipse, dt)
% ENTRADAS
%   in_eclipse  : vector lógico [Nt x 1], true si el satélite está en eclipse
%   dt          : paso de tiempo [s]
% SALIDA
%   T_panel     : vector [Nt x 1] con la temperatura del panel en °C

T_min  = -25.0;     % [°C]  temperatura mínima (salida del eclipse)
T_max  =  65.0;     % [°C]  temperatura máxima (final de la fase iluminada)

% Parámetros físicos del PQ (basados en SMOG-1, Kovács 2018), para los
% valores de alpha, al resultar valores similares a los proporcionados en
% el trabajo final de GGE optamos por dejar estos valores.
alpha1 =  0.0015;   % [1/s] constante de calentamiento
alpha2 =  0.0030;   % [1/s] constante de enfriamiento

Nt = length(in_eclipse);
T_panel = zeros(Nt, 1);

% Condición inicial: el satélite se asume saliendo del eclipse → T = T_min
T_panel(1) = T_min;
ts_count   = 0;   % tiempo acumulado en la fase iluminada actual [s]
te_count   = 0;   % tiempo acumulado en la fase de eclipse actual [s]

for k = 2:Nt
    if ~in_eclipse(k)
        % ---- Fase iluminada ----
        if in_eclipse(k-1)
            ts_count = 0;   % transición eclipse → sol: reinicia contador
        else
            ts_count = ts_count + dt;
        end
        T_panel(k) = T_min + (T_max - T_min) * (1 - exp(-alpha1 * ts_count));

    else
        % ---- Fase de eclipse ----
        if ~in_eclipse(k-1)
            te_count = 0;   % transición sol → eclipse: reinicia contador
        else
            te_count = te_count + dt;
        end
        T_panel(k) = T_max - (T_max - T_min) * (1 - exp(-alpha2 * te_count));
    end
end

end