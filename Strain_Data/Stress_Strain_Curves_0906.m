clear; clc;
set(groot,'defaultTextInterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')

L0_ctrl = 4.0;  L0_fgr = 4.0;
A0_ctrl = 5.91; A0_fgr = 5.64;

archivo = 'Resumen_datos_Procesados.xlsx';

%% 1. Parámetros Demiray
params = readmatrix(archivo, 'Sheet', 'Parametros', 'Range', 'D6:E7');
a_ctrl = params(1,1); b_ctrl = params(2,1);
a_fgr  = params(1,2); b_fgr  = params(2,2);

%% 2. Leer 5 especímenes individuales
% Desplazamiento: cols O:S (idx 14:18) | Fuerza: cols W:AA (idx 22:26)
disp_ind_ctrl = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'O3:S4016');
fza_ind_ctrl  = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'W3:AA4016');
disp_ind_fgr  = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'O3:S2939');
fza_ind_fgr   = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'W3:AA2939');

%% 3. Lambda y sigma [kPa] por espécimen
lambda_ind_ctrl = (L0_ctrl + disp_ind_ctrl) ./ L0_ctrl;  % (N×5)
lambda_ind_fgr  = (L0_fgr  + disp_ind_fgr)  ./ L0_fgr;
sigma_ind_ctrl  = (fza_ind_ctrl  ./ A0_ctrl) .* lambda_ind_ctrl * 1000;
sigma_ind_fgr   = (fza_ind_fgr   ./ A0_fgr)  .* lambda_ind_fgr  * 1000;

%% 4. Grilla común: de 1.0 al mínimo de los máximos de cada espécimen
lmax_ctrl = min(max(lambda_ind_ctrl, [], 1, 'omitnan'));
lmax_fgr  = min(max(lambda_ind_fgr,  [], 1, 'omitnan'));

Ng        = 50;
grid_ctrl = linspace(1.0, lmax_ctrl, Ng);
grid_fgr  = linspace(1.0, lmax_fgr,  Ng);

%% 5. Interpolar sigma de cada espécimen sobre grilla común
sigma_grid_ctrl = NaN(Ng, 5);
sigma_grid_fgr  = NaN(Ng, 5);

for k = 1:5
    % Control
    lk   = lambda_ind_ctrl(:,k);
    sk   = sigma_ind_ctrl(:,k);
    mask = ~isnan(lk) & ~isnan(sk);
    if sum(mask) > 2
        sigma_grid_ctrl(:,k) = interp1(lk(mask), sk(mask), grid_ctrl, 'linear', NaN);
    end
    % FGR
    lk   = lambda_ind_fgr(:,k);
    sk   = sigma_ind_fgr(:,k);
    mask = ~isnan(lk) & ~isnan(sk);
    if sum(mask) > 2
        sigma_grid_fgr(:,k) = interp1(lk(mask), sk(mask), grid_fgr, 'linear', NaN);
    end
end

%% 6. Media y SD punto a punto entre los 5 especímenes
mu_ctrl = mean(sigma_grid_ctrl, 2, 'omitnan');
sd_ctrl = std(sigma_grid_ctrl,  0, 2, 'omitnan');
mu_fgr  = mean(sigma_grid_fgr,  2, 'omitnan');
sd_fgr  = std(sigma_grid_fgr,   0, 2, 'omitnan');

%% 7. Modelo Demiray
lambda_vec     = linspace(1.0, 2.0, 300);
%sigma_dem_ctrl = a_ctrl .* (lambda_vec.^2 - 1./lambda_vec) .* exp((b_ctrl/2) .* (lambda_vec.^2 + 2./lambda_vec - 3)) * 1000;
%sigma_dem_fgr  = a_fgr  .* (lambda_vec.^2 - 1./lambda_vec) .* exp((b_fgr/2)  .* (lambda_vec.^2 + 2./lambda_vec - 3)) * 1000;
sigma_dem_ctrl = a_ctrl .* (grid_ctrl.^2 - 1./grid_ctrl) .* exp((b_ctrl/2) .* (grid_ctrl.^2 + 2./grid_ctrl - 3)) * 1000;
sigma_dem_fgr  = a_fgr  .* (grid_fgr.^2  - 1./grid_fgr)  .* exp((b_fgr/2)  .* (grid_fgr.^2  + 2./grid_fgr  - 3)) * 1000;

%% 7b. Curva promedio de ESFUERZO ACTIVO (6 arterias umbilicales, miografía de alambre)
% Mismo procedimiento que en analisis_tension_activa.m (sección 9):
% ajuste parabólico individual -> interpolación en grilla común -> media

lambda_2008 = [1.18, 1.3627, 1.5441, 1.6347, 1.7254];
Ta_2008_UA1 = [5.8, 6.29, 6.08, 7.3, 7.99];
Ta_2008_UA2 = [8.58, 9.41, 9.86, 14.09, 8.53];

lambda_2016 = [1.1248, 1.2496, 1.3743, 1.4367, 1.4991];
Ta_2016_UA1 = [4.9, 11.73, 13.8, 13.8, 13.72];
Ta_2016_UA2 = [1.74, 4.16, 5.3, 5.43, 5.37];

lambda_2022 = [1.1814, 1.3627, 1.5441, 1.7254, 1.9067];
Ta_2022_UA1 = [0.33, 0.62, 2.83, 6.42, 5.38];
Ta_2022_UA2 = [0.01, 0.87, 2.02, 4.7, 4.36];

l_axial = 1.5;   % mm - longitud axial del segmento de anillo

lambda_act = {lambda_2008, lambda_2008, lambda_2016, lambda_2016, lambda_2022, lambda_2022};
Ta_act     = {Ta_2008_UA1, Ta_2008_UA2, Ta_2016_UA1, Ta_2016_UA2, Ta_2022_UA1, Ta_2022_UA2};

nArt_act = numel(lambda_act);
coef_act = cell(1, nArt_act);
for i = 1:nArt_act
    sigma_i = Ta_act{i} / (2 * l_axial);   % mN/mm^2 = kPa
    coef_act{i} = polyfit(lambda_act{i}, sigma_i, 2);
end

lambda_min_act = max(cellfun(@min, lambda_act));
lambda_max_act = min(cellfun(@max, lambda_act));
grid_act = linspace(lambda_min_act, lambda_max_act, Ng);

sigma_grid_act = zeros(nArt_act, Ng);
for i = 1:nArt_act
    sigma_grid_act(i,:) = polyval(coef_act{i}, grid_act);
end
sigma_mean_act = mean(sigma_grid_act, 1);

% --- Extensión hasta lambda = 2 para ver el comportamiento extrapolado ---
lambda_ext_max = 1.8;
grid_act_ext   = linspace(lambda_min_act, lambda_ext_max, 200);

sigma_grid_act_ext = zeros(nArt_act, numel(grid_act_ext));
for i = 1:nArt_act
    sigma_grid_act_ext(i,:) = polyval(coef_act{i}, grid_act_ext);
end

% Promedio también extendido hasta lambda = 2 (para graficar la curva completa)
sigma_mean_act_ext = mean(sigma_grid_act_ext, 1);

% lambda en el que cada parábola individual cruza el eje x (raíz mayor)
% sigma = a*l^2 + b*l + c = 0  ->  raíces con roots()
lambda_cruce = NaN(1, nArt_act);
for i = 1:nArt_act
    r = roots(coef_act{i});
    r = r(imag(r) == 0);              % solo raíces reales
    r = r(r > lambda_min_act);        % solo después del rango de datos
    if ~isempty(r)
        lambda_cruce(i) = min(r);     % la más cercana, donde empieza a caer a 0/negativo
    end
end

fprintf('--- Lambda donde cada parábola cruza sigma_a = 0 (extrapolación) ---\n');
for i = 1:nArt_act
    nombre_i = {'2008-UA1','2008-UA2','2016-UA1','2016-UA2','2022-UA1','2022-UA2'};
    if ~isnan(lambda_cruce(i))
        fprintf('%-10s lambda_max_dato = %.3f | lambda_cruce_x = %.3f\n', ...
            nombre_i{i}, max(lambda_act{i}), lambda_cruce(i));
    else
        fprintf('%-10s lambda_max_dato = %.3f | no cruza el eje x en el rango evaluado\n', ...
            nombre_i{i}, max(lambda_act{i}));
    end
end
fprintf('\n');

%% 8. Figura
c_ctrl     = [0.80 0.10 0.10];
c_fgr      = [0.10 0.30 0.80];
c_ctrl_drk = [0.50 0.00 0.00];
c_fgr_drk  = [0.00 0.05 0.45];

% Vectores fila para fill
gc = grid_ctrl(:)';  mc = mu_ctrl(:)';  sc = sd_ctrl(:)';
gf = grid_fgr(:)';   mf = mu_fgr(:)';   sf = sd_fgr(:)';

figure('Position', [80 80 900 580]);
hold on; box on;

% --- Banda SD (nube) ---
%fill([gc, fliplr(gc)], [mc+sc, fliplr(mc-sc)], c_ctrl,'FaceAlpha', 0.20, 'EdgeColor', c_ctrl, 'EdgeAlpha', 0.40,'LineWidth', 0.5, 'HandleVisibility', 'off')

%fill([gf, fliplr(gf)], [mf+sf, fliplr(mf-sf)], c_fgr,'FaceAlpha', 0.20, 'EdgeColor', c_fgr, 'EdgeAlpha', 0.40,'LineWidth', 0.5, 'HandleVisibility', 'off')

% --- Curva media experimental ---
%plot(gc, mc, 'o-', 'Color','r', 'LineWidth', 1,'DisplayName', 'UA Control (exp, media $\pm$ SD)')
%plot(gf, mf, 'o-', 'Color','b',  'LineWidth', 1,'DisplayName', 'UA FGR (exp, media $\pm$ SD)')

% --- Modelo Demiray ---
%plot(lambda_vec, sigma_dem_ctrl, '-', 'Color','r', 'LineWidth', 1,'DisplayName', 'UA Control (Demiray)')
%plot(lambda_vec, sigma_dem_fgr,  '-', 'Color','b',  'LineWidth', 1,'DisplayName', 'UA FGR (Demiray)')
plot(grid_ctrl, sigma_dem_ctrl, '-', 'Color', 'r', 'LineWidth', 1, 'DisplayName', 'UA Control (Demiray), n=5')
plot(grid_fgr,  sigma_dem_fgr,  '-', 'Color', 'b', 'LineWidth', 1, 'DisplayName', 'UA FGR (Demiray), n=5')

yyaxis left
xlim([1.0, max(lmax_ctrl, lmax_fgr)])
%xlim([1.0,1.9])
ylim([0, 300])
xlabel('$\lambda$', 'FontSize', 14)
ylabel('$\sigma$ Passive stress [kPa]', 'FontSize', 14)

% --- Curva promedio de esfuerzo activo (6 arterias, miografía de alambre) - EJE DERECHO ---
yyaxis right

% Curva promedio extendida hasta lambda=2 (verde discontinuo grueso)
plot(grid_act_ext, sigma_mean_act_ext, '-.', 'Color', 'k','DisplayName', 'Active stress, n=6')

ylabel('$\sigma_a$ Active stress [kPa]', 'FontSize', 14, 'Color', 'k')
ax = gca;
ax.YAxis(2).Color = [0.2 0.2 0.2];

xline(1.4, '--k', 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(1.6, '--k', 'LineWidth', 0.5, 'HandleVisibility', 'off');

legend('Location', 'northwest', 'FontSize', 11)


%% 7c. Módulo elástico de Demiray entre lambda = 1.4 y 1.6

lam1 = 1.4;
lam2 = 1.6;

% Función Demiray como anónima (para evaluarla en cualquier lambda)
sigma_demiray = @(lam, a, b) a .* (lam.^2 - 1./lam) .* exp((b/2) .* (lam.^2 + 2./lam - 3)) * 1000;

% --- Módulo SECANTE: (sigma2 - sigma1) / (lam2 - lam1) ---
sigma1_ctrl = sigma_demiray(lam1, a_ctrl, b_ctrl);
sigma2_ctrl = sigma_demiray(lam2, a_ctrl, b_ctrl);
E_secante_ctrl = (sigma2_ctrl - sigma1_ctrl) / (lam2 - lam1);

sigma1_fgr = sigma_demiray(lam1, a_fgr, b_fgr);
sigma2_fgr = sigma_demiray(lam2, a_fgr, b_fgr);
E_secante_fgr = (sigma2_fgr - sigma1_fgr) / (lam2 - lam1);

% --- Módulo TANGENTE promedio: derivada analítica dsigma/dlambda, promediada en [1.4,1.6] ---
% dsigma/dlambda de Demiray (derivada calculada simbólicamente):
% sigma = a*(l^2 - 1/l)*exp((b/2)*(l^2 + 2/l - 3))
% dsigma/dl = a*[ (2l + 1/l^2)*exp(...) + (l^2 - 1/l)*exp(...)*(b/2)*(2l - 2/l^2) ]

dsigma_demiray = @(lam, a, b) a .* ( (2*lam + 1./lam.^2) + (lam.^2 - 1./lam).*(b).*(lam - 1./lam.^2) ) ...
                  .* exp((b/2).*(lam.^2 + 2./lam - 3)) * 1000;

lam_fino = linspace(lam1, lam2, 200);

E_tan_ctrl_vec = dsigma_demiray(lam_fino, a_ctrl, b_ctrl);
E_tan_fgr_vec  = dsigma_demiray(lam_fino, a_fgr,  b_fgr);

E_tangente_ctrl = mean(E_tan_ctrl_vec);
E_tangente_fgr  = mean(E_tan_fgr_vec);

% --- Reporte en consola ---
fprintf('\n========== MÓDULO ELÁSTICO DEMIRAY [lambda = %.1f a %.1f] ==========\n', lam1, lam2);
fprintf('%-12s %15s %15s\n', 'Grupo', 'E secante', 'E tangente (avg)');
fprintf('%-12s %15.3f %15.3f\n', 'Control', E_secante_ctrl, E_tangente_ctrl);
fprintf('%-12s %15.3f %15.3f\n', 'FGR',     E_secante_fgr,  E_tangente_fgr);
fprintf('(unidades: kPa, ya que sigma está en kPa y lambda es adimensional)\n');
fprintf('========================================================================\n\n');
