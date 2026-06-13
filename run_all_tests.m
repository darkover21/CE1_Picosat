function run_all_tests()
%RUN_ALL_TESTS Ejecuta todos los tests unitarios del simulador EPS.
%
%% openspec
% @function run_all_tests
% @version 1.1
% @changed 2026-06-13 — Movido a la raíz del proyecto para poder ejecutarse con
%          "run_all_tests" desde la raíz (constraint); cabecera openspec (Fase 3).
% @returns (ninguno; imprime el resultado de cada test y un resumen final)
% @throws (no propaga; captura los fallos de cada test y los cuenta)
% @example
%   run_all_tests();   % desde la raíz del proyecto
% @see test_seleccionar_modo_eps, test_curvas_IV, test_bateria
%
% Añade funciones/ y tests/ al path (relativos a la ubicación de este fichero),
% por lo que funciona ejecutándose desde la raíz del proyecto.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'funciones'));
    addpath(fullfile(root, 'tests'));

    tests = {@test_seleccionar_modo_eps, @test_curvas_IV, @test_bateria};

    n_ok = 0;
    n_fail = 0;
    for k = 1:numel(tests)
        try
            tests{k}();
            n_ok = n_ok + 1;
        catch ME
            n_fail = n_fail + 1;
            fprintf(2, '  >> %s FALLO: %s\n\n', func2str(tests{k}), ME.message);
        end
    end

    fprintf('===== RESUMEN TESTS: %d OK, %d con fallos (%d total) =====\n', ...
        n_ok, n_fail, numel(tests));
end

%% MODIFICADO POR AGENTE — 2026-06-13 — Runner movido a la raíz del proyecto y documentado con cabecera openspec.
