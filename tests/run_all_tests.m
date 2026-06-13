function run_all_tests()
%% ===== OPENSPEC =====
% @spec        run_all_tests
% @purpose     Ejecuta todos los tests unitarios del simulador EPS y resume
%              cuántos pasan / fallan.
% @inputs      (ninguna)
% @outputs     imprime el resultado de cada test y un resumen final.
% @changed     2026-06-13 creado en FASE 2.5.
% =====================

    this_dir = fileparts(mfilename('fullpath'));
    addpath(this_dir);

    tests = {@test_seleccionar_modo_eps, @test_curvas_IV, @test_bateria};

    n_ok = 0; n_fail = 0;
    for k = 1:numel(tests)
        try
            tests{k}();
            n_ok = n_ok + 1;
        catch ME
            n_fail = n_fail + 1;
            fprintf(2, '  >> %s FALLÓ: %s\n\n', func2str(tests{k}), ME.message);
        end
    end

    fprintf('===== RESUMEN TESTS: %d OK, %d con fallos (%d total) =====\n', ...
        n_ok, n_fail, numel(tests));
end
