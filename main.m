%% ===== OPENSPEC =====
% @spec        main
% @purpose     Script principal del simulador EPS del PocketQube 2P: define
%              parámetros (vía config_eps), construye el entorno (eclipse,
%              temperatura, iluminación, batería, consumo), lanza las
%              simulaciones y genera las gráficas y comparativas.
% @inputs      (script) lee config_eps() y los EclipseLocator de datos_gmat.
% @outputs     res, tablas comparativas (orbital y fallos de paneles), figuras.
% @assumes     - Todos los parámetros físicos vienen de [[config_eps]].
%              - Los umbrales de modo EPS son SOC/OCV (ver [[seleccionar_modo_eps]]).
%              - LTAN2 reutiliza el GMAT de LTAN1 -> casos marcados no validados.
% @changed     2026-06-13 FASE 1/2: config centralizada, validación GMAT por
%              caso, casos de fallo requeridos por el enunciado, flag MPPT,
%              eliminado el duplicado local de seleccionar_estado_paneles.
% =====================
%
%% =======================================================================
%  MATLAB es top. Top prioridades de softwares que borrar del mundo.
%  Hecho este comentario, empiezo el main de 0 porque así tengo más control
%  de flujo jiji, besos y abrazos a todos.
%
%  Vale incluyo: Voy a añadir "Localizador" en las funciones que puedan
%  cambiarse / ampliarse. Faltan bastantes.
%
% 
%
%
%% ----------------------- 10/06 por la tarde ---------------------------
% Mikel y Mateo: Hemos separado las variables de G para cada uno de los
% paneles por separado (misma nomenclatura que en el codigo de Mikel de
% iluminaçao). Se ha definido los paneles Z+ y Z- como X+ y X- para ser mas
% claros con la nomenclatura que se suele usar en estos casos. Fuck
% enunciado we do what we want.

%Hemos implementado el codigo de Mikel de iluminación. Se ha definido un
%vector de estado de los paneles, que define en todo momento el estado del
%panel. (mas info donde toque)
% 
%  =======================================================================
clc; clear; close all;
addpath('funciones'); % Si las queréis poner abajo ponedlas abajo
                      % Yo personalmente dividiría en módulos, me resulta
                      % más fácil a la hora de cambios y trazabilidad, pero
                      % si el flow de trabajo es ir por libre haciendo
                      % cosas (Que es un poco lo más cómodo y la manera de
                      % cooperar entre todos) tal vez meter los .m de cada
                      % funcion simplifica.

%% ----------------------- 1. PARÁMETROS DE MISIÓN -----------------------
% carpeta datos_gmat es ahora mismo la que en drive es "TEST_GMAT_DATA".
% a veces me da por seguir PEP8 para nomenclatura de carpetas y archivos
% y cosas. 

%al final cambio cosas


% caso_gmat = '10_30_SSO';

% FASE 2: todos los parámetros físicos vienen de config_eps().
config = config_eps();

% Datos del word de documentación (ahora centralizados en config_eps).
mu      = config.mission.mu;      % [km^3/s^2]
SMA     = config.mission.SMA;     % [km]
h_orb   = config.mission.h_orb;   % [km] (necesario para el cálculo de iluminación)
T_orb   = config.mission.T_orb;   % [s] ~ 5786 s
N_orb   = config.mission.N_orb;   % mínimo 10 periodos (enunciado)
dt      = config.mission.dt;      % [s] paso temporal (bastante fino ahora mismo)
t       = (0:dt:N_orb*T_orb)';    % vector temporal [s]
Nt      = numel(t);

% Datos de los casos orbitales.
% El enunciado pide 4 casos: 2 LTAN x 2 velocidades angulares constantes.
% Como de momento el LTAN no entra directamente en la función de iluminación,
% se representa mediante delta_RAAN_deg. Cuando estén los valores buenos de
% GMAT / LTAN, solo habría que cambiarlos aquí.

% ---- Configuración de RAAN por LTAN (FASE 1, ítem 3) ----
% PENDIENTE: reemplazar con el valor real del GMAT una vez definido el LTAN.
% Mientras tanto son valores provisionales.
delta_RAAN_LTAN1_deg = 0;     % [deg] provisional para LTAN 1
delta_RAAN_LTAN2_deg = 90;    % [deg] provisional para LTAN 2

% ---- Archivos GMAT por LTAN (FASE 1, ítem 2) ----
% PENDIENTE: LTAN2 necesita su propio EclipseLocator1.txt. De momento
% reutiliza el de LTAN1, por lo que sus casos NO están validados.
gmat_LTAN1 = "10_30_SSO";
gmat_LTAN2 = "10_30_SSO";     % PENDIENTE: sustituir por el GMAT propio de LTAN2

% La validez del GMAT de LTAN2 depende de que apunte a un archivo distinto
% al de LTAN1 (es decir, que tenga su propio EclipseLocator).
gmat_LTAN2_validado = (gmat_LTAN2 ~= gmat_LTAN1);
if ~gmat_LTAN2_validado
    warning('main:gmatLTAN2NoValidado', ...
        ['LTAN2 reutiliza el archivo GMAT de LTAN1 ("%s"). Los casos LTAN2 ' ...
         'NO están validados: genera un EclipseLocator1.txt propio para LTAN2.'], ...
        char(gmat_LTAN2));
end

casos_orbitales = struct([]);

casos_orbitales(1).nombre = "LTAN1_w0";
casos_orbitales(1).caso_gmat = gmat_LTAN1;
casos_orbitales(1).delta_RAAN_deg = delta_RAAN_LTAN1_deg;
casos_orbitales(1).w_spin = 0;              %[rad/s] caso sin giro
casos_orbitales(1).gmat_validado = true;    % GMAT real disponible para LTAN1

casos_orbitales(2).nombre = "LTAN1_w01";
casos_orbitales(2).caso_gmat = gmat_LTAN1;
casos_orbitales(2).delta_RAAN_deg = delta_RAAN_LTAN1_deg;
casos_orbitales(2).w_spin = 0.1;            %[rad/s] giro lento, T_spin ~ 63 s
casos_orbitales(2).gmat_validado = true;

casos_orbitales(3).nombre = "LTAN2_w0";
casos_orbitales(3).caso_gmat = gmat_LTAN2;
casos_orbitales(3).delta_RAAN_deg = delta_RAAN_LTAN2_deg;
casos_orbitales(3).w_spin = 0;              %[rad/s] caso sin giro
casos_orbitales(3).gmat_validado = gmat_LTAN2_validado;

casos_orbitales(4).nombre = "LTAN2_w01";
casos_orbitales(4).caso_gmat = gmat_LTAN2;
casos_orbitales(4).delta_RAAN_deg = delta_RAAN_LTAN2_deg;
casos_orbitales(4).w_spin = 0.1;            %[rad/s] giro lento, T_spin ~ 63 s
casos_orbitales(4).gmat_validado = gmat_LTAN2_validado;

% Caso principal para que el main siga funcionando como hasta ahora.
% Si se quiere cambiar el caso base, solo hay que cambiar el índice ( ).

caso_principal = casos_orbitales(1);


% Datos del caso particular.
caso_gmat = char(caso_principal.caso_gmat);
delta_RAAN_deg   = caso_principal.delta_RAAN_deg;            %[deg]; antes había 60; (CAMBIAR AL VALOR REAL DE LA ORBITA!!!!!!)
w_spin           = caso_principal.w_spin;             %[rad/s]; antes había 1; (DE NUEVO, VALOR GENERICO!!!!!!!)

%(MATEO): Se podria añadir una forma de obtener el RAAN directamente de la
%hora solar o incluso importado desde el caso de GMAT. De momento se pone
%un valor genérico. !!!OJO CAMBIAR!!!!

% Época de inicio (debe coincidir con el EclipseLocator de GMAT)
t_start_str = '01 Jul 2027 08:52:00';
date = datetime(t_start_str, 'InputFormat', 'dd MMM yyyy HH:mm:ss', 'Locale', 'en_US');   %Para extraer dia mes y año facilmente 


%% ------------------------1.1 ESTADO DE LOS PANELES ---------------------
%Se ha definido un vector que define el estado del panel: si es "1" el
%panel funciona correctamente y si es "0" el panel está roto. Esto se
%utiliza junto al cálculo de la G de cada panel para calcular la potencia
%generada en todo momento, permitiendo evaluar fallos de paneles. Faltaría
%implementar un punto intermedio "0.5" que evalue el panel con una celula
%menos (1S1P). 

% Segunda versión (César) 11/06 10.30am: Se ha pasado de establecer
% manualmente los paneles que fallan a hacelo mediante una función (seleccionar_estado_paneles)

        % Orden de paneles:
        %   [X+ , X- , Y+ , Y-]
        %
        % Valor del estado:
        %   1   -> panel nominal, 1S2P
        %   0.5 -> panel degradado, equivalente a 1S1P
        %   0   -> panel completamente fallado
        % Las diferentes opciones son:

                % caso_paneles = "fallo_celda_Xp";
                % caso_paneles = "fallo_celda_Xn";
                % caso_paneles = "fallo_celda_Yp";
                % caso_paneles = "fallo_celda_Yn";
                % 
                % caso_paneles = "fallo_panel_Xp";
                % caso_paneles = "fallo_panel_Xn";
                % caso_paneles = "fallo_panel_Yp";
                % caso_paneles = "fallo_panel_Yn";



% Aquí se puede seleccionar el caso que se quiera de forma manual
caso_paneles = "nominal";

Panel_state = seleccionar_estado_paneles(caso_paneles);

% En caso de que se quieran analizar todos los casos automaticamente:


% ------------------------------------------------------------
% Comparativa automática de fallos
% ------------------------------------------------------------
% Si se pone a true, además del caso principal se simulan
% automáticamente todos los casos indicados en casos_paneles_comparativa.

% FASE 1, ítem 4: el enunciado exige analizar (a) fallo de 2 celdas en
% paneles distintos y (b) fallo de 1 panel completo. Se habilita por defecto.
hacer_comparativa_paneles = true;

% Casos exactos requeridos por el enunciado.
casos_paneles_requeridos = [ ...
    "nominal", ...
    "fallo_dos_celdas_Xp_Yp", ...   % (a) 2 celdas en paneles distintos: X+ y Y+
    "fallo_dos_celdas_Xp_Yn", ...   % (a) 2 celdas en paneles distintos: X+ y Y-
    "fallo_panel_Xp", ...           % (b) 1 panel completo: X+
    "fallo_panel_Yn"];              % (b) 1 panel completo: Y-

casos_paneles_comparativa = casos_paneles_requeridos;



%% ----------------------- 2. ENTORNO: ECLIPSE Y TEMPERATURA -------------
%La vd esto me lo ha hecho Claude me puede dar pereza programarme a mano un
%parser de gmat lo siento suficiente tengo con (e)satan y patran
gmat_path = fullfile('datos_gmat', caso_gmat);
try
    t_end_str   = datestr(datenum(t_start_str,'dd mmm yyyy HH:MM:SS') ...
                          + (N_orb*T_orb)/86400, 'dd mmm yyyy HH:MM:SS');
    eclipse_mask = get_eclipse_mask(gmat_path, dt, t_start_str, t_end_str);
    % Ajusta longitud a Nt por si el grid GMAT difiere en 1 muestra
    eclipse_mask = ajustar_longitud(eclipse_mask, Nt);
    fprintf('Eclipse leído de GMAT (%s).\n', caso_gmat);
catch ME
    warning('No se pudo leer GMAT (%s). Uso eclipse sintético.', ME.message);
    % Fallback sintético: ~35%% de eclipse por órbita, para que el main corra
    frac_ecl = 0.35;
    fase = mod(t, T_orb)/T_orb;
    eclipse_mask = double(fase > (1-frac_ecl));
end
in_eclipse = logical(eclipse_mask);
 
% Temperatura del panel. En ºC, en [-25,65].   %%TemperaturaPanelLocalizador
T_panel = calcular_temperatura_panel(in_eclipse, dt);

%% ----------------------- 3. BATERÍA ------------------------------------
% BateríaLocalizador    
[batteryParams, ~] = importarParametrosBateria('resultados_ajuste_dinamico.txt');
ns_bat = batteryParams.Ns;   % 1S1P (se fuerza dentro de la función)
np_bat = batteryParams.Np;

%% ----------------------- 4 CONSUMO DE LAS CARGAS ----------------------
% PerfilConsumoLocalizador
% perfil_consumo devuelve potencia ÚTIL 
[P_CPU, P_Rx, P_Tx, ~] = perfil_consumo(t);

% Recuerdo: La potencia a la salida de los reguladores NO es la potencia
% consumida por batería. La que consume es Potencia Equivalente - Potencia
% Generada. La potencia equivalente se calcula, como primera aproximación,
% como Pútil_bus_x/eficiencia_DCDC_bus_x. Esa eficiencia en realidad no es
% trivial: Si el DCDC es un COTS de estos de plug and play pues está medio
% medido. Si es una pcb propia con un síncrono (lo que hicimos para el
% trabajo) depende de absolutamente todo: Modo de operación, frecuencia de
% conmutación, voltaje de entrada y de salida, intensidades, temperaturas.
% Es un movidote. Así es la vida chicos.

%% --------------------- 4.1 ILUMINACION DE LOS PANELES -----------------
% IluminaciónLocalizador
%Calcula la G de cada panel por separado teniendo en cuenta su iluminación.

[G_px, G_nx, G_py, G_ny, G_total] = Iluminacion_act_efe(t, h_orb, delta_RAAN_deg, w_spin, day(date), month(date), year(date));
G_paneles = [G_px; G_nx; G_py; G_ny]; 

%% ----------------------- 5. CONSTANTES DE LOS REGULADORES --------------
% FASE 2: centralizadas en config_eps().
eta_DCDC = config.reguladores.eta_DCDC;     % DC/DC
Vo_RL    = config.reguladores.Vo_RL;        % [V]
G0       = config.reguladores.G0;           % [W/m^2] constante solar (LEO)

%% ----------------------- 6. PREPARAR SIMULACIÓN ------------------------

simParams.Nt = Nt;
simParams.dt = dt;

simParams.T_panel = T_panel;
simParams.G_paneles = G_paneles;
simParams.Panel_state = Panel_state;

simParams.P_CPU = P_CPU;
simParams.P_Rx  = P_Rx;
simParams.P_Tx  = P_Tx;

simParams.eta_DCDC = eta_DCDC;
simParams.Vo_RL = Vo_RL;

simParams.batteryParams = batteryParams;
simParams.ns_bat = ns_bat;
simParams.np_bat = np_bat;

% FASE 2: umbrales de los modos EPS (SOC + OCV) centralizados en config_eps.
% Ya NO se usa el antiguo simParams.V_min_admisible = 3.3 sobre la tensión
% de bornes (causaba Safe espurio con SOC alto por la caída I*Rint).
simParams.cfg_modos = config.modos_eps;

% FASE 2.6: seguimiento del MPP. false -> eta_MPPT=0.92 constante;
% true -> MPPT Incremental Conductance dinámico por panel.
simParams.usar_mppt_dinamico = false;


%% ----------------------- 6.1 COMPARATIVA ORBITAL -----------------------
% Si se pone a true, se simulan los 4 casos orbitales definidos arriba
% y se identifica el peor caso según el SOC mínimo.

hacer_comparativa_orbital = true;

if hacer_comparativa_orbital
    [tabla_casos, resultados_casos, peor_caso] = comparar_casos_orbitales( ...
        casos_orbitales, simParams, t, h_orb, date);
end


%% ----------------------- 7. SIMULACIÓN ---------------------------------
res = simular_caso_eps(simParams);
fprintf('SOC max = %.4f\n', max(res.soc_bat));
fprintf('SOC min = %.4f\n', min(res.soc_bat));

fprintf('Vbat min = %.4f V\n', min(res.V_bat));
fprintf('Tiempo en nominal = %.2f %%\n', 100*sum(res.modo_eps == 0)/numel(res.modo_eps));
fprintf('Tiempo en degradado = %.2f %%\n', 100*sum(res.modo_eps == 1)/numel(res.modo_eps));
fprintf('Tiempo en safe = %.2f %%\n', 100*sum(res.modo_eps == 2)/numel(res.modo_eps));
% Cesar 11/06 11.00am: En el caso de que se quieran simular todos los fallos automaticamente, hay
% que especificar que "hacer_comparativa_paneles=true" (línea 113), si se
% establece "false", lo de abajo no se ejecuta

% ------------------------------------------------------------
% Comparativa automática de casos de fallo de paneles
% ------------------------------------------------------------

if hacer_comparativa_paneles

    resultados_paneles = struct();

    n_casos = numel(casos_paneles_comparativa);

    Caso = strings(n_casos,1);
    E_gen_Wh = zeros(n_casos,1);
    E_cons_Wh = zeros(n_casos,1);
    Balance_Wh = zeros(n_casos,1);
    SOC_min = zeros(n_casos,1);
    SOC_final = zeros(n_casos,1);
    Vbat_min = zeros(n_casos,1);

    for k = 1:n_casos

        caso_actual = casos_paneles_comparativa(k);

        % Crear una copia de simParams para no modificar el caso principal
        simParams_k = simParams;
        simParams_k.Panel_state = seleccionar_estado_paneles(caso_actual);

        % Simular caso
        res_k = simular_caso_eps(simParams_k);

        % Guardar resultado completo
        nombre_campo = char(matlab.lang.makeValidName(caso_actual));
        resultados_paneles.(nombre_campo) = res_k;

        % Calcular valores de comparación
        Caso(k) = caso_actual;
        E_gen_Wh(k) = trapz(t, res_k.W_gen) / 3600;
        E_cons_Wh(k) = trapz(t, res_k.W_bus) / 3600;
        Balance_Wh(k) = E_gen_Wh(k) - E_cons_Wh(k);
        SOC_min(k) = min(res_k.soc_bat);
        SOC_final(k) = res_k.soc_bat(end);
        Vbat_min(k) = min(res_k.V_bat);

    end

    tabla_paneles = table( ...
        Caso, ...
        E_gen_Wh, ...
        E_cons_Wh, ...
        Balance_Wh, ...
        SOC_min, ...
        SOC_final, ...
        Vbat_min);

    disp(' ');
    disp('===== COMPARATIVA DE FALLOS DE PANELES =====');
    disp(tabla_paneles);

    % Para sacar graficas automaticas comparando el SOC de todos los
    % fallos:

        figure('Name','Comparativa SOC - fallos de paneles','Color','w');
    hold on; grid on;

    for k = 1:n_casos

        caso_actual = casos_paneles_comparativa(k);
        nombre_campo = char(matlab.lang.makeValidName(caso_actual));

        plot(t/3600, resultados_paneles.(nombre_campo).soc_bat, ...
            'LineWidth', 1.1);

    end

    xlabel('Tiempo [h]');
    ylabel('SOC [-]');
    title('Comparativa del SOC para distintos fallos de paneles');
    legend(casos_paneles_comparativa, 'Location', 'best');


end

% Finaliza simulacion y representación (en gráficas) automatica de fallos en paneles



% Recuperar variables desde la estructura res para que las gráficas antiguas
% sigan funcionando sin tener que modificarlas todavía
W_gen      = res.W_gen;
W_bus      = res.W_bus;
I_CPU_bus  = res.I_CPU_bus;
I_Rx_bus   = res.I_Rx_bus;
I_Tx_bus   = res.I_Tx_bus;
W_bat      = res.W_bat;
I_bat      = res.I_bat;
V_bat      = res.V_bat;
soc_bat    = res.soc_bat;
Vrc_bat    = res.Vrc_bat;
W_disip    = res.W_disip;
W_dump        = res.W_dump;
W_disip_total = res.W_disip_total;
modo_safe  = res.modo_safe;
modo_eps   = res.modo_eps;

P_CPU_real = res.P_CPU_real;
P_Rx_real  = res.P_Rx_real;
P_Tx_real  = res.P_Tx_real;

Pbus_panel = res.Pbus_panel;

% ------------------------------------------------------------
% Postprocesado por panel
% ------------------------------------------------------------
% Se calcula la energia generada por cada panel a partir de la potencia
% entregada al bus por cada MPPT.

nombres_paneles = ["X+"; "X-"; "Y+"; "Y-"];

E_panel_Wh = zeros(4,1);

for j = 1:4
    E_panel_Wh(j) = trapz(t, Pbus_panel(:,j)) / 3600;
end

porcentaje_panel = 100 * E_panel_Wh / sum(E_panel_Wh);

tabla_energia_paneles = table( ...
    nombres_paneles, ...
    E_panel_Wh, ...
    porcentaje_panel, ...
    'VariableNames', {'Panel','Energia_Wh','Porcentaje'});
disp(' ');
disp('===== ENERGÍA GENERADA POR PANEL =====');
disp(tabla_energia_paneles);

%% ----------------------- 8. GRÁFICAS -----------------------------------
t_h = t/3600;
figure('Name','Balance de potencia PQ','Color','w','Position',[100 80 1100 850]);

subplot(4,1,1);
area(t_h, in_eclipse, 'FaceColor',[0.49 0.18 0.56],'EdgeColor','none','FaceAlpha',0.5);
ylim([0 1.2]); yticks([0 1]); yticklabels({'Sol','Eclipse'});
title('Eclipse'); grid on;

subplot(4,1,2);
plot(t_h, W_gen,'b','LineWidth',1.1); hold on;
plot(t_h, W_bus,'r','LineWidth',1.1);
ylabel('P [W]'); legend('Generada (bus)','Consumida (bus)','Location','best');
title('Producción vs. consumo'); grid on;

subplot(4,1,3);
plot(t_h, I_CPU_bus*1e3,'LineWidth',1.0); hold on;
plot(t_h, I_Rx_bus*1e3,'LineWidth',1.0);
plot(t_h, I_Tx_bus*1e3,'LineWidth',1.0);
plot(t_h, I_bat*1e3,'k','LineWidth',1.0);
ylabel('I [mA]'); legend('I_{CPU}','I_{Rx}','I_{Tx}','I_{bat}','Location','best');
title('Corrientes de las cargas y de la batería'); grid on;

subplot(4,1,4);
yyaxis left;  plot(t_h, V_bat,'LineWidth',1.2); ylabel('V_{bat} [V]');
hold on; yline(config.modos_eps.V_min_ocv,'--', ...
    sprintf('OCV_{min}=%.2f V', config.modos_eps.V_min_ocv));
yyaxis right; plot(t_h, soc_bat,'LineWidth',1.0); ylabel('SOC [-]');
xlabel('Tiempo [h]'); title('Tensión y SOC de la batería'); grid on;

figure('Name','Temperatura y potencia disipada','Color','w','Position',[140 120 900 500]);
subplot(2,1,1); plot(t_h, T_panel,'LineWidth',1.1); ylabel('T_{panel} [ºC]');
title('Temperatura del panel'); grid on;
subplot(2,1,2);
plot(t_h, W_disip*1e3,'LineWidth',1.1); hold on;
plot(t_h, W_dump*1e3,'LineWidth',1.1);
plot(t_h, W_disip_total*1e3,'k','LineWidth',1.3);

ylabel('Potencia [mW]');
xlabel('Tiempo [h]');
legend('Reguladores','Excedente solar','Total','Location','best');
title('Potencia disipada / no aprovechada');
grid on;

% ------------------------------------------------------------
% Potencia generada por cada panel
% ------------------------------------------------------------
figure('Name','Potencia generada por panel','Color','w','Position',[160 140 900 500]);

plot(t_h, Pbus_panel(:,1)*1e3,'LineWidth',1.1); hold on;
plot(t_h, Pbus_panel(:,2)*1e3,'LineWidth',1.1);
plot(t_h, Pbus_panel(:,3)*1e3,'LineWidth',1.1);
plot(t_h, Pbus_panel(:,4)*1e3,'LineWidth',1.1);

xlabel('Tiempo [h]');
ylabel('Potencia [mW]');
title('Potencia generada por cada panel');
legend(nombres_paneles, 'Location', 'best');
grid on;


figure('Name','Modo de operacion EPS','Color','w','Position',[180 150 900 350]);

stairs(t_h, modo_eps, 'LineWidth', 1.2);
grid on;

yticks([0 1 2]);
yticklabels({'Nominal','Degradado','Safe'});

xlabel('Tiempo [h]');
ylabel('Modo EPS');
title('Modo de operación del EPS');

figure('Name','Consumo util con modos EPS','Color','w','Position',[200 180 900 450]);

plot(t_h, P_CPU_real*1e3, 'LineWidth', 1.1); hold on;
plot(t_h, P_Rx_real*1e3, 'LineWidth', 1.1);
plot(t_h, P_Tx_real*1e3, 'LineWidth', 1.1);

grid on;
xlabel('Tiempo [h]');
ylabel('Potencia util [mW]');
legend('CPU','Rx','Tx','Location','best');
title('Consumo util aplicado tras la seleccion de modo EPS');

figure('Name','Zoom consumo util en modo safe','Color','w','Position',[220 200 900 450]);

stairs(t_h, P_CPU_real*1e3, 'LineWidth', 1.1); hold on;
stairs(t_h, P_Rx_real*1e3, 'LineWidth', 1.1);
stairs(t_h, P_Tx_real*1e3, 'LineWidth', 1.1);

grid on;
xlabel('Tiempo [h]');
ylabel('Potencia util [mW]');
legend('CPU','Rx','Tx','Location','best');
title('Zoom del consumo util durante modo safe');

xlim([4.2 4.5]);

% ------------------------------------------------------------
% Energia total generada por cada panel
% ------------------------------------------------------------
figure('Name','Energia generada por panel','Color','w','Position',[180 160 750 450]);

bar(E_panel_Wh);
set(gca, 'XTick', 1:4);
set(gca, 'XTickLabel', nombres_paneles);

ylabel('Energia [Wh]');
title('Energia total generada por cada panel');
grid on;

%% ======================= FUNCIONES LOCALES =============================
function f = factor_iluminacion_paneles(~)
% factor_iluminacion_paneles  Media de cos(ángulo de incidencia) sobre los
% 4 paneles laterales (Y+,Y-,Z+,Z-), valor en [0,1].
%
% >>> PENDIENTE DE MODELAR (no está en las funciones entregadas):
%     - Dirección del Sol en ejes cuerpo a lo largo de la órbita (depende
%       del LTAN y de la época).
%     - Actitud: X tangente al campo B (dipolo inclinado 11º) y giro libre
%       en torno a X -> proyección del Sol sobre Y± y Z±.
%     Mientras tanto se devuelve 1 para que el main corra. SUSTITUIR.
    f = 1.0;
end

function v = ajustar_longitud(v, N)
% Recorta o rellena (con el último valor) un vector hasta longitud N.
    v = v(:);
    if numel(v) >= N
        v = v(1:N);
    else
        v = [v; repmat(v(end), N-numel(v), 1)];
    end
end

% NOTA: seleccionar_estado_paneles se define ahora como funcion propia en
% funciones/seleccionar_estado_paneles.m (fuente unica, con los casos de
% fallo de dos celdas requeridos). Se elimino la copia local que la duplicaba
% y el 'end' sobrante que quedaba al final del fichero.
