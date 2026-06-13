function [G_px, G_nx, G_py, G_ny, G_total] = Iluminacion_act_efe(t_vec, h, delta_RAAN_deg, w_spin, dia, mes, ano)
                                                                 % [s],[km],[º],          [rad/s], [dia mes año]

    %% ENTRADAS PARA LA FUNCIÓN GLOBAL
    dt = t_vec(2) - t_vec(1);
    t_sim = t_vec(end);
    n_steps = length(t_vec);

    %% WMM 2020: no puede usar fechas posteriores a 2025
    if ano > 2025
        warning('WMM:DateOutOfRange', ...
            'La fecha %04d-%02d-%02d supera la validez del WMM; se usará una fecha equivalente en 2024.', ...
            ano, mes, dia);
        ano_wmm = 2024;
    else
        ano_wmm = ano;
    end
    decimalYear_wmm = decyear(ano_wmm, mes, dia);

    %% PARÁMETROS DEL SISTEMA
    % Constantes orbitales
    G_solar = 1361;           % Constante solar [W/m^2]
    Re = 6371;                % Radio de la Tierra [km]
    mu = 398600;              % Parámetro gravitacional terrestre [km^3/s^2]
    J2 = 1.0827e-3;           % Coeficiente de perturbación J2
    r = Re + h;               % Radio orbital [km]

    delta_RAAN = deg2rad(delta_RAAN_deg); % RAAN [radianes]

    %% CÁLCULO DE PARÁMETROS ORBITALES
    % Periodo orbital
    T = 2 * pi * sqrt(r^3 / mu);   % [s]
    T_hours = T / 3600;            % [h]

    % Velocidad angular media
    n = sqrt(mu / r^3);            % [rad/s]

    % Inclinación para órbita heliosíncrona
    % Precesión del RAAN debe ser: dOmega/dt = 2*pi/(365.25*86400) rad/s
    % dOmega/dt = -1.5 * n * J2 * (Re/r)^2 * cos(i)
    % Para heliosíncrona: dOmega/dt = 2*pi/(365.25*86400)

    omega_precesion = 2 * pi / (365.25 * 86400);  % [rad/s]
    cos_i = omega_precesion / (-1.5 * n * J2 * (Re/r)^2);
    i = acos(cos_i);              % [rad]
    i_deg = rad2deg(i);           % [grados]

    % Inicialización de vectores de Iluminación
    G_px = zeros(1, n_steps);  % Iluminación cara +X
    G_nx = zeros(1, n_steps);  % Iluminación cara -X
    G_py = zeros(1, n_steps);  % Iluminación cara +Y
    G_ny = zeros(1, n_steps);  % Iluminación cara -Y
    G_total = zeros(1, n_steps);
    eclipse_flag = zeros(1, n_steps);

    % Vectores normales de las caras en ejes cuerpo (RSW)
    n_px = [1; 0; 0];   % +X
    n_nx = [-1; 0; 0];  % -X
    n_py = [0; 1; 0];   % +Y
    n_ny = [0; -1; 0];  % -Y

    %% CÁLCULO DEL VECTOR SOL MEDIANTE EFEMÉRIDES SIMPLIFICADAS

    % Día Juliano (simplificado)
    % Días desde el 1 de enero del ano 2000 (J2000.0)
    % J2000.0 = 1 de enero de 2000, 12:00 TT
    dias_meses = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    dias_desde_inicio_ano = dias_meses(mes) + dia;

    % Ajuste por anos bisiestos
    if mod(ano, 4) == 0 && mes > 2
        dias_desde_inicio_ano = dias_desde_inicio_ano + 1;
    end

    % Días desde J2000.0
    anos_desde_2000 = ano - 2000;
    anos_bisiestos = floor(anos_desde_2000 / 4);
    dias_J2000 = anos_desde_2000 * 365 + anos_bisiestos + dias_desde_inicio_ano - 1;

    % Modelo simplificado de efemérides solares
    % Anomalía media del Sol (grados)
    M_sol = 357.528 + 0.9856003 * dias_J2000;
    M_sol = mod(M_sol, 360);  % Normalizar a [0, 360]

    % Longitud media del Sol (grados)
    L_sol = 280.460 + 0.9856474 * dias_J2000;
    L_sol = mod(L_sol, 360);

    % Longitud eclíptica verdadera (corrección simplificada)
    lambda_sol = L_sol + 1.915 * sind(M_sol) + 0.020 * sind(2*M_sol);
    lambda_sol = mod(lambda_sol, 360);

    % Oblicuidad de la eclíptica (grados)
    epsilon = 23.439 - 0.0000004 * dias_J2000;

    % Vector Sol en coordenadas ECI
    r_sol_x = cosd(lambda_sol);
    r_sol_y = sind(lambda_sol) * cosd(epsilon);
    r_sol_z = sind(lambda_sol) * sind(epsilon);

    r_sol_ECI = [r_sol_x; r_sol_y; r_sol_z];
    r_sol_ECI = r_sol_ECI / norm(r_sol_ECI);  % Normalizar
    % Greenwich Mean Sidereal Time en el instante inicial (UTC 00:00)
    JD_0 = 367 * ano - floor(7 * (ano + floor((mes + 9) / 12)) / 4) + ...
        floor(275 * mes / 9) + dia + 1721013.5;
    T_UT1_0 = (JD_0 - 2451545.0) / 36525;
    gmst_deg_0 = mod(280.46061837 + 360.98564736629 * (JD_0 - 2451545.0) + ...
        0.000387933 * T_UT1_0^2 - T_UT1_0^3 / 38710000, 360);
    theta_g0 = deg2rad(gmst_deg_0);
    omega_earth = 7.2921150e-5;  % [rad/s]

    %% CÁLCULO DE LA ASCENSIÓN RECTA DEL SOL Y NUEVO RAAN
    % Ascensión Recta del Sol (RA_sol) en radianes
    RA_sol = atan2(r_sol_y, r_sol_x);  % [rad]
    RA_sol_deg = rad2deg(RA_sol);      % [deg]

    % RAAN de la órbita heliosíncrona
    RAAN = RA_sol + delta_RAAN;     % RAAN = RA_sol + 60°
    RAAN_deg = rad2deg(RAAN);      % [deg]

    %% SIMULACIÓN TEMPORAL CON SPIN

    % Vectores normales de las caras en ejes cuerpo (antes del spin)
    n_px_body = [1; 0; 0];   % +X
    n_nx_body = [-1; 0; 0];  % -X
    n_py_body = [0; 1; 0];   % +Y
    n_ny_body = [0; -1; 0];  % -Y

    % Semi-ángulo del cono de sombra
    rho = asin(Re / r);

    %% BUCLE PRINCIPAL CON SPIN
    for k = 1:n_steps
        t = t_vec(k);
        
        % Anomalía verdadera (órbita circular: nu = M = n*t)
        nu = n * t;
        
        % === POSICIÓN Y VELOCIDAD EXACTAS EN ECI (ECUACIONES PARAMÉTRICAS) ===
        % Posición del satélite en ECI
        r_sat_ECI = [r * (cos(RAAN)*cos(nu) - sin(RAAN)*sin(nu)*cos(i));
                    r * (sin(RAAN)*cos(nu) + cos(RAAN)*sin(nu)*cos(i));
                    r * sin(nu)*sin(i)];
        
        % Velocidad del satélite en ECI
        v_sat_ECI = [r*n*(-cos(RAAN)*sin(nu) - sin(RAAN)*cos(nu)*cos(i));
                    r*n*(-sin(RAAN)*sin(nu) + cos(RAAN)*cos(nu)*cos(i));
                    r*n*cos(nu)*sin(i)];
        
        % === CÁLCULO DE ECLIPSE (usando lógica geométrica en ECI) ===
        
        % Semi-ángulo del cono de sombra de la Tierra
        theta_eclipse = asin(Re / r);
        
        % Ángulo entre vector satélite y vector Sol
        cos_angle = dot(r_sat_ECI, r_sol_ECI) / (norm(r_sat_ECI) * norm(r_sol_ECI));
        angle_sat_sol = acos(cos_angle);
        
        % El satélite está en eclipse si está en el lado nocturno
        % y dentro del cono de sombra
        if cos_angle < 0 && abs(pi - angle_sat_sol) < theta_eclipse
            in_eclipse = true;
            eclipse_flag(k) = 1;
        else
            in_eclipse = false;
        end
        
        % === VECTORES BASE DEL SISTEMA RSW EN ECI ===
        % R_unit = r_sat_ECI / norm(r_sat_ECI);   % Radial (hacia afuera)
        % W_vec = cross(r_sat_ECI, v_sat_ECI);    % Momento angular
        % W_unit = W_vec / norm(W_vec);               % Normal al plano orbital
        % S_unit = cross(W_unit, R_unit);             % Along-track (velocidad)
        % porque necesito un triedro ortonormal, y para órbitas no circulares,
        % la velocidad no será perpendicular al vector radial

        % === MATRIZ ECI A EJES CUERPO BASE (X=velocidad, Y=-normal, Z=nadir) ===
        % C_ECI_to_Body = [S_unit';
        %                 -W_unit';
        %                 -R_unit'];
        
        % === MATRIZ ECI A EJES CUERPO BASE (X=pseudovelocidad, Y=pseudonormal, Z=campo magnetico) ===
        theta_g = theta_g0 + omega_earth * t;
        C_ECI_to_ECEF = [cos(theta_g),  sin(theta_g), 0;
                        -sin(theta_g),  cos(theta_g), 0;
                        0,             0,            1];
        r_sat_ECEF = C_ECI_to_ECEF * r_sat_ECI;
        latitude = rad2deg(atan2(r_sat_ECEF(3), hypot(r_sat_ECEF(1), r_sat_ECEF(2))));
        longitude = rad2deg(atan2(r_sat_ECEF(2), r_sat_ECEF(1)));
        longitude = mod(longitude + 180, 360) - 180;

        % 1. Salida real del WMM (el vector está en NED, no en ECI)
        [B_NED, H, D, I, F] = wrldmagm(h*1E3, latitude, longitude, decimalYear_wmm, 2020);

        % 2. Pasar a radianes para la matriz de rotación local
        lat_rad = deg2rad(latitude);
        lon_rad = deg2rad(longitude);

        % 3. Matriz de rotación de NED a ECEF
        C_NED_to_ECEF = [-sin(lat_rad)*cos(lon_rad), -sin(lon_rad), -cos(lat_rad)*cos(lon_rad);
                        -sin(lat_rad)*sin(lon_rad),  cos(lon_rad), -cos(lat_rad)*sin(lon_rad);
                        cos(lat_rad),               0,            -sin(lat_rad)];

        B_ECEF = C_NED_to_ECEF * B_NED;

        % 4. Matriz de rotación de ECEF a ECI (Traspuesta de la que ya calculaste)
        C_ECEF_to_ECI = C_ECI_to_ECEF';

        % 5. Vector magnético final, ahora sí, en ECI
        Z_B_ECI_real = C_ECEF_to_ECI * B_ECEF;

        % Ahora ya puedes normalizar y cruzar con seguridad
        Z_B_ECI_unit = Z_B_ECI_real / norm(Z_B_ECI_real);
        X_aux = cross(Z_B_ECI_unit, r_sat_ECI);
        X_aux_unit = X_aux / norm(X_aux);
        Y_unit = cross(Z_B_ECI_unit, X_aux_unit);

        C_ECI_to_Body = [X_aux_unit';
                        Y_unit';
                        Z_B_ECI_unit'];
        
        % Vector Sol en ejes cuerpo base (sin spin)
        r_sol_body_base = C_ECI_to_Body * r_sol_ECI;
        
        % === APLICAR SPIN (rotación sobre eje Z del cuerpo) ===
        theta_spin = w_spin * t;
        R_spin = [cos(theta_spin), sin(theta_spin), 0;
                -sin(theta_spin),  cos(theta_spin), 0;
                0,                0,               1];
        
        % Vector Sol en ejes cuerpo con spin
        r_sol_body_spin = R_spin * r_sol_body_base;
        
        % === CÁLCULO DE ILUMINACIÓN POR CARA ===
        if ~in_eclipse
            % Potencia cara +X
            cos_px = max(0, dot(n_px_body, r_sol_body_spin));
            G_px(k) = G_solar * cos_px;
            
            % Potencia cara -X
            cos_nx = max(0, dot(n_nx_body, r_sol_body_spin));
            G_nx(k) = G_solar * cos_nx;
            
            % Potencia cara +Y
            cos_py = max(0, dot(n_py_body, r_sol_body_spin));
            G_py(k) = G_solar * cos_py;
            
            % Potencia cara -Y
            cos_ny = max(0, dot(n_ny_body, r_sol_body_spin));
            G_ny(k) = G_solar * cos_ny;
        end
        
        % Potencia total instantánea
        G_total(k) = G_px(k) + G_nx(k) + G_py(k) + G_ny(k);
    end

end
