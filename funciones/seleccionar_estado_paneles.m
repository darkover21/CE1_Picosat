function Panel_state = seleccionar_estado_paneles(caso_paneles)
%SELECCIONAR_ESTADO_PANELES Vector de estado de los paneles por escenario de fallo.
%
%% openspec
% @function seleccionar_estado_paneles
% @version 1.1
% @changed 2026-06-13 — Fuente única (se eliminó la copia local duplicada de main.m);
%          cubre los casos de fallo requeridos por el enunciado (2 celdas en paneles
%          distintos y 1 panel completo). Cabecera openspec (Fase 3).
% @param caso_paneles {string} [-] — Nombre del caso de fallo (p.ej. "nominal",
%          "fallo_dos_celdas_Xp_Yp", "fallo_panel_Yn")
% @returns Panel_state {double 1x4} [-] — Estado [X+ X- Y+ Y-] con valores
%          1 (nominal 1S2P), 0.5 (una celda perdida, 1S1P) o 0 (panel fallado)
% @throws seleccionar_estado_paneles:casoNoReconocido — si el caso no existe
% @example
%   ps = seleccionar_estado_paneles("fallo_panel_Yn");   % -> [1 1 1 0]
% @see simular_caso_eps, comparar_casos_orbitales
%
% Devuelve el vector de estado de los paneles solares según el caso de fallo seleccionado.
%
% ENTRADA: caso_paneles : string con el nombre del caso de fallo
%
% SALIDA: Panel_state  : vector [1x4] con el estado de cada panel
%                  Orden: [X+ , X- , Y+ , Y-]
%                  Valores:
%                    1   -> panel nominal (1S2P)
%                    0.5 -> panel degradado, una celda fallada (1S1P)
%                    0   -> panel completamente fallado
%
% CASOS DISPONIBLES
%   "nominal"                -> todos los paneles operativos
%   "fallo_celda_Xp"         -> celda fallada en panel X+
%   "fallo_celda_Xn"         -> celda fallada en panel X-
%   "fallo_celda_Yp"         -> celda fallada en panel Y+
%   "fallo_celda_Yn"         -> celda fallada en panel Y-
%   "fallo_dos_celdas_Xp_Yp" -> celda fallada en X+ y en Y+
%   "fallo_dos_celdas_Xp_Yn" -> celda fallada en X+ y en Y-
%   "fallo_dos_celdas_Xn_Yp" -> celda fallada en X- y en Y+
%   "fallo_dos_celdas_Xn_Yn" -> celda fallada en X- y en Y-
%   "fallo_dos_celdas_Xp_Xn" -> celda fallada en X+ y en X-
%   "fallo_dos_celdas_Yp_Yn" -> celda fallada en Y+ y en Y-
%   "fallo_panel_Xp"         -> panel X+ completamente fallado
%   "fallo_panel_Xn"         -> panel X- completamente fallado
%   "fallo_panel_Yp"         -> panel Y+ completamente fallado
%   "fallo_panel_Yn"         -> panel Y- completamente fallado

    caso_paneles = string(caso_paneles);

    switch caso_paneles

        % ---- Caso nominal ----
        case "nominal"
            Panel_state = [1, 1, 1, 1];

        % ---- Fallo de una celda ----
        case "fallo_celda_Xp"
            Panel_state = [0.5, 1, 1, 1];

        case "fallo_celda_Xn"
            Panel_state = [1, 0.5, 1, 1];

        case "fallo_celda_Yp"
            Panel_state = [1, 1, 0.5, 1];

        case "fallo_celda_Yn"
            Panel_state = [1, 1, 1, 0.5];

        % ---- Fallo de dos celdas en distintos paneles ----
        case "fallo_dos_celdas_Xp_Yp"
            Panel_state = [0.5, 1, 0.5, 1];

        case "fallo_dos_celdas_Xp_Yn"
            Panel_state = [0.5, 1, 1, 0.5];

        case "fallo_dos_celdas_Xn_Yp"
            Panel_state = [1, 0.5, 0.5, 1];

        case "fallo_dos_celdas_Xn_Yn"
            Panel_state = [1, 0.5, 1, 0.5];

        case "fallo_dos_celdas_Xp_Xn"
            Panel_state = [0.5, 0.5, 1, 1];

        case "fallo_dos_celdas_Yp_Yn"
            Panel_state = [1, 1, 0.5, 0.5];

        % ---- Fallo de panel completo ----
        case "fallo_panel_Xp"
            Panel_state = [0, 1, 1, 1];

        case "fallo_panel_Xn"
            Panel_state = [1, 0, 1, 1];

        case "fallo_panel_Yp"
            Panel_state = [1, 1, 0, 1];

        case "fallo_panel_Yn"
            Panel_state = [1, 1, 1, 0];

        otherwise
            error('seleccionar_estado_paneles:casoNoReconocido', ...
                'Caso de fallo no reconocido: "%s". Revisa el nombre del escenario.', caso_paneles);

    end

end

%% MODIFICADO POR AGENTE — 2026-06-13 — Casos de fallo de dos celdas, identificador de error y cabecera openspec.