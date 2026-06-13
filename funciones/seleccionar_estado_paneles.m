function Panel_state = seleccionar_estado_paneles(caso_paneles)
%% ===== OPENSPEC =====
% @spec        seleccionar_estado_paneles
% @purpose     Traduce un nombre de escenario de fallo al vector de estado de
%              los 4 paneles laterales.
% @inputs      caso_paneles : string con el nombre del caso de fallo
% @outputs     Panel_state  : vector [1x4] [X+ X- Y+ Y-], valores {1, 0.5, 0}
% @assumes     1 = nominal (1S2P), 0.5 = una celda perdida (1S1P), 0 = panel
%              completo fallado. Caso desconocido -> error().
% @changed     2026-06-13 fuente única (se eliminó la copia local duplicada de
%              main.m); cubre los casos de fallo requeridos por el enunciado:
%              2 celdas en paneles distintos y 1 panel completo.
% =====================
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
            error('Caso de fallo no reconocido: "%s"', caso_paneles);

    end

end