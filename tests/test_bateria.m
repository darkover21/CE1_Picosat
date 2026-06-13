function test_bateria()
%% ===== OPENSPEC =====
% @spec        test_bateria
% @purpose     Test unitario del integrador de batería (SOC vs corriente).
% @inputs      (ninguna)
% @outputs     imprime PASS/FAIL por comprobación.
% @assumes     Convención I>0 carga / I<0 descarga. Con descarga constante el
%              SOC debe disminuir monótonamente y cumplir el balance de carga
%              dSOC = I*dt/(3600*C_Ah).
% @changed     2026-06-13 creado en FASE 2.5.
% =====================

    this_dir = fileparts(mfilename('fullpath'));
    root = fileparts(this_dir);
    addpath(root);
    addpath(fullfile(root, 'funciones'));

    fprintf('== test_bateria ==\n');

    batteryParams = importarParametrosBateria('dummy.txt');
    ns = batteryParams.Ns; np = batteryParams.Np;

    % --- Descarga a corriente constante ---
    I_desc = -0.5;     % [A] descarga
    dt = 1;            % [s]
    N  = 600;          % pasos (600 s)
    soc0 = 0.80;

    soc = soc0;
    Vrc = 0;
    soc_hist = zeros(N+1,1);
    soc_hist(1) = soc;
    monotona = true;

    for k = 1:N
        [~, soc_next, Vrc] = simularBateriaDinamica1RC( ...
            batteryParams, soc, Vrc, I_desc, dt, ns, np);
        if soc_next > soc + 1e-12
            monotona = false;   % no debería subir nunca en descarga
        end
        soc = soc_next;
        soc_hist(k+1) = soc;
    end

    % --- Comprobaciones ---
    check(soc < soc0, ...
        sprintf('SOC disminuye con descarga: %.5f -> %.5f', soc0, soc));
    check(monotona, 'SOC es monótono decreciente durante toda la descarga');

    % Balance de carga esperado
    dSOC_esperado = I_desc * (dt*N) / (3600 * batteryParams.C_Ah);
    soc_esperado  = soc0 + dSOC_esperado;
    tol = 1e-6;
    check(abs(soc - soc_esperado) < tol, ...
        sprintf('SOC final %.6f ~= esperado %.6f (dSOC=%.6f)', ...
                soc, soc_esperado, dSOC_esperado));

    fprintf('\n');
end

function check(cond, msg)
    if cond
        fprintf('  PASS: %s\n', msg);
    else
        fprintf('  FAIL: %s\n', msg);
    end
    assert(cond, msg);
end
