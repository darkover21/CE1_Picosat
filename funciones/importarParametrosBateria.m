function [batteryParams, batteryMetadata] = importarParametrosBateria(archivo_parametros_bateria)

    % ============================================================
    % importarParametrosBateria
    %
    % Se mantiene el nombre de la función para no cambiar el main.
    % En el trabajo anterior esta función leía un .txt con los
    % parámetros ajustados de un modelo dinámico 1RC para una batería
    % Samsung INR18650.
    %
    % Para este trabajo se redefine internamente para devolver los
    % parámetros de la batería LiFePO4 del PocketQube.
    %
    % Convención usada en el main:
    %   I_actual > 0  -> carga
    %   I_actual < 0  -> descarga
    % ============================================================

    batteryParams = struct();

    % ------------------------------------------------------------
    % Datos principales de la celda LiFePO4
    % ------------------------------------------------------------
    batteryParams.name = 'ACL9011 LiFePO4';

    batteryParams.Ns = 1;
    batteryParams.Np = 1;

    batteryParams.V_nom = 3.2;          % [V]
    batteryParams.C_Ah  = 1.5;          % [Ah]
    batteryParams.E_Wh  = batteryParams.V_nom * batteryParams.C_Ah;

    % Límites de tensión
    batteryParams.V_max = 3.65;          % [V] tensión máxima de carga 
    batteryParams.V_cutoff = 2.5;       % [V] corte absoluto de descarga


    % ------------------------------------------------------------
    % Criterio de profundidad máxima de descarga
    % ------------------------------------------------------------
    % Se adopta una DoD máxima del 40 %. Para una batería de 1500 mAh,
    % esto equivale a permitir una descarga máxima de 600 mAh.
    %
    % DoD = 1 - SOC
    
    batteryParams.DoD_max = 0.40;                         % [-]
    batteryParams.Q_desc_max_Ah = batteryParams.DoD_max * batteryParams.C_Ah;  % [Ah]
    batteryParams.soc_min_operativo = 1 - batteryParams.DoD_max;               % [-]
    
    % Umbral de recuperación para salir del modo seguro
    batteryParams.soc_recovery = 0.80;                    % [-]
    
        % Estado inicial recomendado
        batteryParams.soc_init = 0.8;       % [-]

    % ------------------------------------------------------------
    % Parámetros eléctricos equivalentes
    % ------------------------------------------------------------
    % Resistencia interna aproximada de celda.
    % Este valor se puede ajustar posteriormente si se digitaliza la curva
    % del datasheet o se dispone de datos experimentales.
    batteryParams.Rint = 60e-3;          % VALOR DEL DATASHEET

    % Se mantiene el modelo 1RC para conservar la estructura anterior.
    % Si no se desea dinámica RC, basta con poner R1 = 0. PONEMOS QUE SON
    % CERO PORQUE EN DATASHEET NO HAY DESCARGA DINAMICAS, Y POR TANTO ESTOS
    % PARAMETROS NO LOS PODEMOS SACAR
    batteryParams.R1 = 0;            % [Ohm]
    batteryParams.C1 = 0;            % [F]

    % ------------------------------------------------------------
    % Curva OCV-SOC aproximada para LiFePO4
    % ------------------------------------------------------------
    % Curva obtenida de forma aproximada a partir de las curvas de
    % descarga del datasheet. Se toma como referencia la curva de
    % descarga a baja tasa, ya que es la más próxima a una curva OCV.
    %
    % SOC = 1 corresponde a batería cargada.
    % SOC = 0 corresponde al final de descarga.
    
    batteryParams.soc_data = [ ...
        0.00 0.05 0.10 0.20 0.40 0.60 0.80 0.90 0.95 1.00];
    
    batteryParams.voc_data = [ ...
        2.50 2.85 3.05 3.18 3.24 3.28 3.31 3.33 3.38 3.55];



    % Tensión aproximada correspondiente al SOC mínimo elegido
    batteryParams.V_min_operativo = interp1( ...
        batteryParams.soc_data, ...
        batteryParams.voc_data, ...
        batteryParams.soc_min_operativo, ...
        'linear');
    
    % Tensión aproximada de recuperación
    batteryParams.V_recovery = interp1( ...
        batteryParams.soc_data, ...
        batteryParams.voc_data, ...
        batteryParams.soc_recovery, ...
        'linear');




    % ------------------------------------------------------------
    % Metadatos
    % ------------------------------------------------------------
    batteryMetadata = struct();
    batteryMetadata.archivoFuente = archivo_parametros_bateria;
    batteryMetadata.modelo = 'LiFePO4 1S1P - modelo OCV(SOC) + Rint + 1RC';
    batteryMetadata.fechaGeneracion = datetime('now');

    % Guardado opcional para trazabilidad
    save('battery_import.mat', 'batteryParams', 'batteryMetadata');

    fid_battery = fopen('battery.txt', 'w');
    if fid_battery ~= -1
        fprintf(fid_battery, 'Modelo bateria: %s\n', batteryParams.name);
        fprintf(fid_battery, 'Configuracion: %dS%dP\n', batteryParams.Ns, batteryParams.Np);
        fprintf(fid_battery, 'Capacidad [Ah]: %.4f\n', batteryParams.C_Ah);
        fprintf(fid_battery, 'V_nom [V]: %.4f\n', batteryParams.V_nom);
        fprintf(fid_battery, 'V_min_operativo [V]: %.4f\n', batteryParams.V_min_operativo);
        fprintf(fid_battery, 'V_cutoff [V]: %.4f\n', batteryParams.V_cutoff);
        fprintf(fid_battery, 'V_max [V]: %.4f\n', batteryParams.V_max);
        fprintf(fid_battery, 'Rint [Ohm]: %.6f\n', batteryParams.Rint);
        fprintf(fid_battery, 'R1 [Ohm]: %.6f\n', batteryParams.R1);
        fprintf(fid_battery, 'C1 [F]: %.6f\n', batteryParams.C1);
        fclose(fid_battery);
    end

end