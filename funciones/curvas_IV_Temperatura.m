function [Pmp_panel, Pbus_panel, V_PS, I_PS] = curvas_IV_Temperatura(T, G, Ns, Np)
%% En este código se calcula las curvas I-V en función de la temperatura siguiendo el modelo Pindado Cubas del artículo 
% On the Thermo-Electrical Modeling of Small Satellite’s Solar Panels

%% Definiciones:
    % T es la temperatura para la que se quiere calcular la curva
    % G es la irradiación solar según el instante deseado
    
    %% Configuración en serie y en pararlelo para CADA panel
    % Ns = 1;
    % Np = 2; 

    %% DATOS DE LA CELDA sm141k06l 
    
    Voc_cell_0 = 4.15;      % [V]
    Isc_cell_0 = 58.6e-3;   % [A]
    Vmp_cell_0 = 3.35;      % [V]
    Imp_cell_0 = 55.1e-3;   % [A]
    
    % Coeficientes térmicos de la celda
    b_Voc_cell = -10.4e-3;  % [V/ºC]
    a_Isc_cell =  26.5e-6;  % [A/ºC]
    % No hemos encontrado datos en el data sheet. Asi que se va a estimar 
    % usando los de cortocircuito y la relación Voc/Vmp e Imp/Isc como 
    % factores de escala esto cuadra con lo visto en otros datasheet en los
    % que el  b_Vmp_cell suele ser myor en valor absoluto y a_Imp_cell
    % menor
    % b_Vmp_cell = Voc_cell_0/Vmp_cell_0 * b_Voc_cell; % [V/ºC] No hemos encontrado datos en el data sheet. 
    % a_Imp_cell = Imp_cell_0/Isc_cell_0 * a_Isc_cell; % [A/ºC] No hemos encontrado datos en el data sheet. 
    % Con el planteamiento anterior las curvas salen raritas otra opción es
    % decir que vale lo mismo que el de circuito abierto y el de cortocircuito
    % con esa aproximación las curvas se ven mejor
    b_Vmp_cell = b_Voc_cell; % [V/ºC] No hemos encontrado datos en el data sheet. 
    a_Imp_cell = a_Isc_cell; % [A/ºC] No hemos encontrado datos en el data sheet.

    % Valores de referencia del data sheet
    G0 = 1000;   % [W/m^2]
    T0 = 25;     % [ºC]

    %% CONFIGURACIÓN ELÉCTRICA DEL ARRAY SOLAR

    Voc0 = Voc_cell_0 * Ns;
    Isc0 = Isc_cell_0 * Np;
    Vmp0 = Vmp_cell_0 * Ns;
    Imp0 = Imp_cell_0 * Np;
    
    b_Voc = b_Voc_cell * Ns;
    a_Isc = a_Isc_cell * Np;
    b_Vmp = b_Vmp_cell * Ns;
    a_Imp = a_Imp_cell * Np;


    %% Valores Curvas modificados por las temperaturas 

    Isc_T = (G/G0) * (Isc0 + a_Isc*(T - T0));
    Imp_T = (G/G0) * (Imp0 + a_Imp*(T - T0));

    Voc_T = Voc0 + b_Voc*(T - T0);
    Vmp_T = Vmp0 + b_Vmp*(T - T0);

    %% Potencia máxima
    eta_MPPT = 0.92;

    Pmp_panel = Vmp_T * Imp_T;
    Pbus_panel = eta_MPPT * Pmp_panel;

    %% Curvas modificadas
    % Se van a calcular por si se quiere plotear pero en realidad al usar
    % MPPT no hace falta y esta sección se podría comentar

    V_PS = linspace(0, Voc_T, 300);

    idx1 = (V_PS >= 0) & (V_PS <= Vmp_T);
    idx2 = (V_PS > Vmp_T) & (V_PS <= Voc_T);

    I_PS(idx1) = Isc_T .* ...
        (1 - (1 - Imp_T/Isc_T) .* ...
        (V_PS(idx1)./Vmp_T).^(Imp_T/(Isc_T - Imp_T)));

    phi = (Isc_T/Imp_T) * ...
          (Isc_T/(Isc_T - Imp_T)) * ...
          ((Voc_T - Vmp_T)/Voc_T);

    I_PS(idx2) = Imp_T .* (Vmp_T ./ V_PS(idx2)) .* ...
        (1 - ((V_PS(idx2) - Vmp_T)./(Voc_T - Vmp_T)).^phi);

end