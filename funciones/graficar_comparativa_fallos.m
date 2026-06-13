function graficar_comparativa_fallos(t, resultados_paneles, casos)
% Genera las gráficas y tabla comparativa de los distintos casos de fallo de paneles.
%
% ENTRADAS
%   t : vector temporal [s]
%   resultados_paneles : struct con un campo por caso simulado,
%                        cada campo contiene la estructura res de
%                        simular_caso_eps
%   casos: vector de strings con los nombres de los casos (deben coincidir con los campos de resultados_paneles)

    t_h      = t / 3600;
    n_casos  = numel(casos);

    %% 1. Gráfica comparativa de SOC 
    figure('Name','Comparativa SOC - fallos de paneles', ...
           'Color','w','Position',[100 80 900 400]);
    hold on; grid on;

    for k = 1:n_casos
        campo = char(matlab.lang.makeValidName(casos(k)));
        plot(t_h, resultados_paneles.(campo).soc_bat, 'LineWidth', 1.1);
    end

    xlabel('Tiempo [h]');
    ylabel('SOC [-]');
    title('Comparativa del SOC para distintos fallos de paneles');
    legend(casos, 'Location','best');
    ylim([0 1.05]);

    %% 2. Gráfica comparativa de potencia generada 
    figure('Name','Comparativa W\_gen - fallos de paneles', ...
           'Color','w','Position',[140 120 900 400]);
    hold on; grid on;

    for k = 1:n_casos
        campo = char(matlab.lang.makeValidName(casos(k)));
        plot(t_h, resultados_paneles.(campo).W_gen * 1e3, 'LineWidth', 1.1);
    end

    xlabel('Tiempo [h]');
    ylabel('P_{gen} [mW]');
    title('Comparativa de potencia generada para distintos fallos de paneles');
    legend(casos, 'Location','best');

    %% 3. Gráfica comparativa de tensión de batería 
    figure('Name','Comparativa V\_bat - fallos de paneles', ...
           'Color','w','Position',[180 160 900 400]);
    hold on; grid on;

    for k = 1:n_casos
        campo = char(matlab.lang.makeValidName(casos(k)));
        plot(t_h, resultados_paneles.(campo).V_bat, 'LineWidth', 1.1);
    end

    yline(3.3, 'k--', 'V_{min} = 3.3 V', 'LineWidth', 1.0);
    xlabel('Tiempo [h]');
    ylabel('V_{bat} [V]');
    title('Comparativa de tensión de batería para distintos fallos de paneles');
    legend(casos, 'Location','best');

    %% 4. Tabla resumen para el informe 
    Caso       = strings(n_casos, 1);
    E_gen_Wh   = zeros(n_casos, 1);
    E_cons_Wh  = zeros(n_casos, 1);
    Balance_Wh = zeros(n_casos, 1);
    SOC_min    = zeros(n_casos, 1);
    SOC_final  = zeros(n_casos, 1);
    Vbat_min   = zeros(n_casos, 1);

    dt = t(2) - t(1);

    for k = 1:n_casos
        campo = char(matlab.lang.makeValidName(casos(k)));
        r = resultados_paneles.(campo);

        Caso(k)       = casos(k);
        E_gen_Wh(k)   = trapz(t, r.W_gen)  / 3600;
        E_cons_Wh(k)  = trapz(t, r.W_bus)  / 3600;
        Balance_Wh(k) = E_gen_Wh(k) - E_cons_Wh(k);
        SOC_min(k)    = min(r.soc_bat);
        SOC_final(k)  = r.soc_bat(end);
        Vbat_min(k)   = min(r.V_bat);
    end

    tabla = table(Caso, E_gen_Wh, E_cons_Wh, Balance_Wh, SOC_min, SOC_final, Vbat_min);

    fprintf('\n===== COMPARATIVA DE FALLOS DE PANELES =====\n');
    disp(tabla);

end