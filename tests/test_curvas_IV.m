function test_curvas_IV()
%% ===== OPENSPEC =====
% @spec        test_curvas_IV
% @purpose     Test unitario del modelo Pindado-Cubas en condiciones STC.
% @inputs      (ninguna)
% @outputs     imprime PASS/FAIL por comprobación.
% @assumes     A T=25 C y G=1000 W/m^2 (condiciones de referencia del datasheet)
%              Pmp = Vmp*Imp y Pbus_panel = 0.92*Vmp*Imp (eta_MPPT=0.92).
% @changed     2026-06-13 creado en FASE 2.5.
% =====================

    this_dir = fileparts(mfilename('fullpath'));
    root = fileparts(this_dir);
    addpath(root);
    addpath(fullfile(root, 'funciones'));

    fprintf('== test_curvas_IV ==\n');

    tol = 1e-9;
    eta_MPPT = 0.92;

    % Datos de la celda SM141K06L en condiciones de referencia (T0=25, G0=1000)
    Vmp_cell = 3.35;       % [V]
    Imp_cell = 55.1e-3;    % [A]

    % Panel nominal 1S2P
    Ns = 1; Np = 2;
    Vmp = Vmp_cell * Ns;
    Imp = Imp_cell * Np;

    [Pmp, Pbus, V_PS, I_PS] = curvas_IV_Temperatura(25, 1000, Ns, Np);

    Pmp_esperada  = Vmp * Imp;
    Pbus_esperada = eta_MPPT * Vmp * Imp;

    check(abs(Pmp - Pmp_esperada) < tol, ...
        sprintf('Pmp = %.6f W  (esperado %.6f W)', Pmp, Pmp_esperada));
    check(abs(Pbus - Pbus_esperada) < tol, ...
        sprintf('Pbus_panel = %.6f W ~= 0.92*Vmp*Imp = %.6f W', Pbus, Pbus_esperada));
    check(abs(Pbus - eta_MPPT*Pmp) < tol, ...
        'Pbus_panel = eta_MPPT * Pmp');

    % La curva I-V debe ser coherente (no negativa, Voc > Vmp)
    check(all(I_PS >= -tol), 'Corriente de la curva I-V no negativa');
    check(max(V_PS) > Vmp, 'Voc > Vmp en la curva generada');

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
