clear; clc;
set(groot,'defaultTextInterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')

%% 0. Parametros y ruta del archivo
L0_ctrl = 4.0;  L0_fgr = 4.0;
A0_ctrl = 5.91; A0_fgr = 5.64;

archivo = fullfile(fileparts(mfilename('fullpath')), 'Strain_Data', 'Resumen_datos_raw_mod.xlsx');

%% 1. Leer 5 especimenes individuales
disp_ind_ctrl = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'A3:E2792');
fza_ind_ctrl  = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'G3:K2792');
disp_ind_fgr  = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'A3:E2226');
fza_ind_fgr   = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'G3:K2226');

%% 2. Lambda y sigma [kPa] por especimen (DATOS RAW)
lambda_ind_ctrl = (L0_ctrl + disp_ind_ctrl) ./ L0_ctrl;
lambda_ind_fgr  = (L0_fgr  + disp_ind_fgr)  ./ L0_fgr;
sigma_ind_ctrl  = (fza_ind_ctrl  ./ A0_ctrl) .* lambda_ind_ctrl * 1000;
sigma_ind_fgr   = (fza_ind_fgr   ./ A0_fgr)  .* lambda_ind_fgr  * 1000;

%% 3. Grilla comun
lmax_ctrl = min(max(lambda_ind_ctrl, [], 1, 'omitnan'));
lmax_fgr  = min(max(lambda_ind_fgr,  [], 1, 'omitnan'));

Ng        = 50;
grid_ctrl = linspace(1.0, lmax_ctrl, Ng);
grid_fgr  = linspace(1.0, lmax_fgr,  Ng);

%% 4. Parametros de Demiray FIJOS por grupo
% CORRECCION 1: en el script original estos parametros y la funcion
% demiray_model solo se definian en la seccion 6 (numeracion original),
% pero ya se usaban antes, en la seccion 4. Movidos aqui, antes de su
% primer uso.
a_ctrl_fijo = 0.014;  b_ctrl_fijo = 1.0;
a_fgr_fijo  = 0.02;   b_fgr_fijo  = 1.4;

demiray_model = @(a, b, lam) a .* (lam.^2 - 1./lam) .* exp((b/2) .* (lam.^2 + 2./lam - 3)) * 1000;

fprintf('--- Parametros Demiray FIJOS (grupo) ---\n');
fprintf('Control: a = %.4f, b = %.4f\n', a_ctrl_fijo, b_ctrl_fijo);
fprintf('FGR:     a = %.4f, b = %.4f\n\n', a_fgr_fijo, b_fgr_fijo);

sigma_dem_ctrl = demiray_model(a_ctrl_fijo, b_ctrl_fijo, grid_ctrl);
sigma_dem_fgr  = demiray_model(a_fgr_fijo,  b_fgr_fijo,  grid_fgr);

%% 5. Interpolar los DATOS RAW de cada especimen sobre la grilla comun (SIN Demiray)
% CORRECCION 2: el loop original decia "SIN Demiray" en el comentario
% pero adentro llamaba a demiray_model(), y escribia el resultado en
% sigma_dem_grid_ctrl, una variable que nunca se preasigno y que no es
% la misma que sigma_grid_ctrl_raw (la que si se preasigno como
% NaN(Ng,5) y la que usa el calculo de SEM en la seccion siguiente).
% Resultado: sigma_grid_ctrl_raw quedaba siempre en NaN.
% Aqui se interpola el esfuerzo RAW medido (sigma_ind_ctrl), no un
% modelo, y se agrega el loop para FGR, que faltaba por completo.
sigma_grid_ctrl_raw = NaN(Ng, 5);
sigma_grid_fgr_raw  = NaN(Ng, 5);

for k = 1:5
    lk = lambda_ind_ctrl(:,k);
    sk = sigma_ind_ctrl(:,k);
    mask = ~isnan(lk) & ~isnan(sk);
    if nnz(mask) >= 2
        sigma_grid_ctrl_raw(:,k) = interp1(lk(mask), sk(mask), grid_ctrl, 'linear', NaN);
    end
end

for k = 1:5
    lk = lambda_ind_fgr(:,k);
    sk = sigma_ind_fgr(:,k);
    mask = ~isnan(lk) & ~isnan(sk);
    if nnz(mask) >= 2
        sigma_grid_fgr_raw(:,k) = interp1(lk(mask), sk(mask), grid_fgr, 'linear', NaN);
    end
end

% Alias: la seccion de modulo elastico por zonas (mas abajo) usaba los
% nombres sigma_grid_ctrl / sigma_grid_fgr (sin "_raw"). Se deja el
% alias explicito en vez de renombrar todo, para que quede claro que es
% la misma matriz de datos RAW interpolados.
sigma_grid_ctrl = sigma_grid_ctrl_raw;
sigma_grid_fgr  = sigma_grid_fgr_raw;

%% 6. SEM de los datos RAW, punto a punto entre los 5 especimenes
sd_ctrl_raw  = std(sigma_grid_ctrl_raw, 0, 2, 'omitnan');
sd_fgr_raw   = std(sigma_grid_fgr_raw,  0, 2, 'omitnan');

sigma_sem_raw_ctrl = (sd_ctrl_raw(:)') / sqrt(5);
sigma_sem_raw_fgr  = (sd_fgr_raw(:)')  / sqrt(5);

%% 7. Bandera de especimen valido (reemplaza a_ctrl_ind / a_fgr_ind)
% CORRECCION 3, IMPORTANTE: la seccion de modulo por zonas usaba
% a_ctrl_ind(k) y a_fgr_ind(k) solo para decidir si el especimen k tenia
% datos validos, pero esas dos variables no se definian en ningun punto
% del archivo que compartiste. No invento aqui un ajuste de Demiray por
% especimen que no me pediste (eso seria agregar un metodo estadistico
% nuevo sin que tu lo hayas validado). En vez de eso, uso directamente
% si el especimen k tiene datos RAW interpolados en la grilla comun, que
% es la misma funcion de "filtro" que cumplia la variable original.
% Si en tu flujo real a_ctrl_ind SI era otra cosa (por ejemplo, un
% ajuste individual de Demiray con un proposito adicional), dimelo y lo
% cambiamos.
valid_ctrl = ~all(isnan(sigma_grid_ctrl_raw), 1);
valid_fgr  = ~all(isnan(sigma_grid_fgr_raw),  1);

%% 8. Curva de ESFUERZO ACTIVO (6 arterias, miografia de alambre)
% Sin cambios respecto al original: esto sigue pendiente de tu
% confirmacion sobre a que corresponden los codigos 2008/2016/2022 y si
% su lambda esta referido al mismo estado no cargado que el ensayo
% pasivo. Corregir el codigo no resuelve esa pregunta.
lambda_2008 = [1.18, 1.3627, 1.5441, 1.6347, 1.7254];
Ta_2008_UA1 = [5.8, 6.29, 6.08, 7.3, 7.99];
Ta_2008_UA2 = [8.58, 9.41, 9.86, 14.09, 8.53];

lambda_2016 = [1.1248, 1.2496, 1.3743, 1.4367, 1.4991];
Ta_2016_UA1 = [4.9, 11.73, 13.8, 13.8, 13.72];
Ta_2016_UA2 = [1.74, 4.16, 5.3, 5.43, 5.37];

lambda_2022 = [1.1814, 1.3627, 1.5441, 1.7254, 1.9067];
Ta_2022_UA1 = [0.33, 0.62, 2.83, 6.42, 5.38];
Ta_2022_UA2 = [0.01, 0.87, 2.02, 4.7, 4.36];

a0 = 1.5;
e0 = 0.25;

lambda_act = {lambda_2008, lambda_2008, lambda_2016, lambda_2016, lambda_2022, lambda_2022};
Ta_act     = {Ta_2008_UA1, Ta_2008_UA2, Ta_2016_UA1, Ta_2016_UA2, Ta_2022_UA1, Ta_2022_UA2};

nArt_act = numel(lambda_act);
coef_act = cell(1, nArt_act);
for i = 1:nArt_act
    sigma_i = (Ta_act{i} ./ (2 * a0 * e0)) .* lambda_act{i};
    coef_act{i} = polyfit(lambda_act{i}, sigma_i, 2);
end

lambda_min_act = max(cellfun(@min, lambda_act));
grid_act_ext = linspace(lambda_min_act, 2, 200);

sigma_grid_act_ext = zeros(nArt_act, numel(grid_act_ext));
for i = 1:nArt_act
    sigma_grid_act_ext(i,:) = polyval(coef_act{i}, grid_act_ext);
end
sigma_mean_act_ext = mean(sigma_grid_act_ext, 1);
sigma_sd_act_ext   = std(sigma_grid_act_ext, 0, 1);
sigma_sem_act_ext  = sigma_sd_act_ext / sqrt(nArt_act);

%% 9. Figura principal (Active stress + Passive stress)
c_ctrl = [0.7 0.7 0.7];
c_fgr  = [0.2 0.2 0.2];
gc = grid_ctrl(:)';
gf = grid_fgr(:)';

n_ext = numel(grid_act_ext);
n_markers = 20;
marker_idx = round(linspace(1, n_ext, n_markers));

figure('Position', [80 80 900 580]);
hold on; box on;

yyaxis left
fill([grid_act_ext,fliplr(grid_act_ext)],[sigma_mean_act_ext+sigma_sem_act_ext, fliplr(sigma_mean_act_ext-sigma_sem_act_ext)],[0.2 0.2 0.2],'FaceAlpha',0.09,'EdgeColor','none','HandleVisibility','off');
plot(grid_act_ext, sigma_mean_act_ext, '-s', 'Color','k','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerIndices',marker_idx,'LineWidth', 1,'DisplayName', 'UA Control (Polynomial fit, $\pm$ SEM)')
ylabel('Active stress ($\sigma_{a}$, kPa)', 'FontSize', 14, 'Color', 'k')
ylim([0,25]);

yyaxis right
fill([gc, fliplr(gc)], [sigma_dem_ctrl+sigma_sem_raw_ctrl, fliplr(sigma_dem_ctrl-sigma_sem_raw_ctrl)],c_ctrl, 'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off')
fill([gf, fliplr(gf)], [sigma_dem_fgr+sigma_sem_raw_fgr,  fliplr(sigma_dem_fgr-sigma_sem_raw_fgr)], c_fgr,  'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off')
plot(grid_ctrl, sigma_dem_ctrl, '-o', 'Color', 'k','MarkerFaceColor','w','MarkerEdgeColor','k', 'LineWidth', 1, 'DisplayName', 'UA Control (Demiray, $\pm$ SEM)')
plot(grid_fgr,  sigma_dem_fgr,  '-o','Color','k', 'MarkerFaceColor', 'k','MarkerEdgeColor','k', 'LineWidth', 1, 'DisplayName', 'UA FGR (Demiray, $\pm$ SEM)')

xlim([1.0, max(lmax_ctrl, lmax_fgr)])
ylim([0, 250])
xlabel('Stretch ($\lambda$, u.a)', 'FontSize', 14)
ylabel('Passive Stress ($\sigma_{p}$, kPa)', 'FontSize', 14)
ax = gca;
ax.YAxis(1).Color = [0.0 0.0 0.0];
ax.YAxis(2).Color = [0.0 0.0 0.0];
xline(1.451, '--k', 'LineWidth', 0.5, 'HandleVisibility', 'off');
xline(1.845, '--k', 'LineWidth', 0.5, 'HandleVisibility', 'off');
legend('Location', 'northwest', 'FontSize', 11,'Box','off');
%exportgraphics(gcf, 'Figure1_Active-vs-Passive_estress.tif', 'Resolution', 300);
%exportgraphics(gcf, 'Figure1_Active-vs-Passive_estress.pdf', 'ContentType', 'vector');

%% 10. Modulo elastico por zonas, metodo polyfit (regresion lineal)
z = [1.0, 1.451, 1.845, 2.0];
z3_fin_ctrl = min(lmax_ctrl, z(4));
z3_fin_fgr  = min(lmax_fgr,  z(4));

mask1c = (grid_ctrl >= z(1)) & (grid_ctrl <= z(2));
mask2c = (grid_ctrl >= z(2)) & (grid_ctrl <= z(3));
mask3c = (grid_ctrl >= z(3)) & (grid_ctrl <= z3_fin_ctrl);

mask1f = (grid_fgr >= z(1)) & (grid_fgr <= z(2));
mask2f = (grid_fgr >= z(2)) & (grid_fgr <= z(3));
mask3f = (grid_fgr >= z(3)) & (grid_fgr <= z3_fin_fgr);

% --- E de la curva PROMEDIO (Demiray fijo, polyfit por tramo) ---
p1 = polyfit(grid_ctrl(mask1c), sigma_dem_ctrl(mask1c), 1);
p2 = polyfit(grid_ctrl(mask2c), sigma_dem_ctrl(mask2c), 1);
p3 = polyfit(grid_ctrl(mask3c), sigma_dem_ctrl(mask3c), 1);
E_prom_ctrl_fit = [p1(1), p2(1), p3(1)];

p1 = polyfit(grid_fgr(mask1f), sigma_dem_fgr(mask1f), 1);
p2 = polyfit(grid_fgr(mask2f), sigma_dem_fgr(mask2f), 1);
p3 = polyfit(grid_fgr(mask3f), sigma_dem_fgr(mask3f), 1);
E_prom_fgr_fit = [p1(1), p2(1), p3(1)];

% --- E POR ESPECIMEN INDIVIDUAL (n=5), polyfit sobre datos RAW ---
% CORRECCION 4: se reemplaza el chequeo "if ~isnan(a_ctrl_ind(k))" por
% "if valid_ctrl(k)" (ver seccion 7), y sigma_grid_ctrl / sigma_grid_fgr
% ya estan definidas como alias de los datos RAW interpolados.
E_ind_ctrl_fit = NaN(5,3);
E_ind_fgr_fit  = NaN(5,3);

for k = 1:5
    if valid_ctrl(k)
        yk = sigma_grid_ctrl(:,k)';
        pk1 = polyfit(grid_ctrl(mask1c), yk(mask1c), 1); E_ind_ctrl_fit(k,1) = pk1(1);
        pk2 = polyfit(grid_ctrl(mask2c), yk(mask2c), 1); E_ind_ctrl_fit(k,2) = pk2(1);
        pk3 = polyfit(grid_ctrl(mask3c), yk(mask3c), 1); E_ind_ctrl_fit(k,3) = pk3(1);
    end
    if valid_fgr(k)
        yk = sigma_grid_fgr(:,k)';
        pk1 = polyfit(grid_fgr(mask1f), yk(mask1f), 1); E_ind_fgr_fit(k,1) = pk1(1);
        pk2 = polyfit(grid_fgr(mask2f), yk(mask2f), 1); E_ind_fgr_fit(k,2) = pk2(1);
        pk3 = polyfit(grid_fgr(mask3f), yk(mask3f), 1); E_ind_fgr_fit(k,3) = pk3(1);
    end
end

% --- SEM y significancia ---
sem_ctrl_fit = std(E_ind_ctrl_fit, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(E_ind_ctrl_fit),1));
sem_fgr_fit  = std(E_ind_fgr_fit,  0, 1, 'omitnan') ./ sqrt(sum(~isnan(E_ind_fgr_fit),1));

pvals_fit  = NaN(1,3);
tnames_fit = cell(1,3);

for j = 1:3
    xc = E_ind_ctrl_fit(~isnan(E_ind_ctrl_fit(:,j)), j);
    xf = E_ind_fgr_fit(~isnan(E_ind_fgr_fit(:,j)),  j);

    if length(xc) >= 4 && length(xf) >= 4
        [~, pnc] = lillietest(xc);
        [~, pnf] = lillietest(xf);

        if pnc > 0.05 && pnf > 0.05
            [~, pvals_fit(j)] = ttest2(xc, xf, 'Vartype', 'unequal');
            tnames_fit{j} = 't-Welch';
        else
            pvals_fit(j) = ranksum(xc, xf);
            tnames_fit{j} = 'Mann-Whitney';
        end
    else
        pvals_fit(j) = ranksum(xc, xf);
        tnames_fit{j} = 'Mann-Whitney (N<4)';
    end
end

sig_fit = cell(1,3);
for j = 1:3
    if     pvals_fit(j) < 0.001, sig_fit{j} = '***';
    elseif pvals_fit(j) < 0.01,  sig_fit{j} = '**';
    elseif pvals_fit(j) < 0.05,  sig_fit{j} = '*';
    else,                        sig_fit{j} = 'ns';
    end
end

%% 11. Histograma del modulo elastico por zonas
figure('Position', [100 100 700 550]);
hold on; box on;

x      = 1:3;
ancho  = 0.35;
offset = 0.20;
etiquetas_x = {'Zone 1', 'Zone 2', 'Zone 3'};

bar(x - offset, E_prom_ctrl_fit, ancho, 'FaceColor',[1.0 1.0 1.0],'EdgeColor','k','DisplayName','UA Control');
bar(x + offset, E_prom_fgr_fit,  ancho, 'FaceColor',[0.2 0.2 0.2],'EdgeColor','k','DisplayName','UA FGR');

errorbar(x - offset, E_prom_ctrl_fit, sem_ctrl_fit, 'k.', 'LineWidth',1.5, 'CapSize',8, 'HandleVisibility','off')
errorbar(x + offset, E_prom_fgr_fit,  sem_fgr_fit,  'k.', 'LineWidth',1.5, 'CapSize',8, 'HandleVisibility','off')

line_gap  = 30;
text_gap  = 15;

for j = 1:3
    y_max_barra = max([E_prom_ctrl_fit(j)+sem_ctrl_fit(j), E_prom_fgr_fit(j)+sem_fgr_fit(j)]);
    y_sig = y_max_barra + line_gap;
    plot([x(j)-offset, x(j)+offset], [y_sig y_sig], 'k-', 'LineWidth', 1, 'HandleVisibility','off')

    fs = 14;
    if strcmp(sig_fit{j},'ns'), fs = 11; end

    text(x(j), y_sig + text_gap, sig_fit{j}, 'FontSize',fs, 'HorizontalAlignment','center', 'FontWeight','bold', 'Color','k')
end

xticks(x)
xticklabels(etiquetas_x)
xlabel('Stretch Intervals', 'FontSize',13, 'Interpreter','Latex')
ylabel('Stretch Modulus ($E$, kPa)', 'FontSize',13, 'Interpreter','Latex')

ylim([0, max([E_prom_ctrl_fit+sem_ctrl_fit, E_prom_fgr_fit+sem_fgr_fit]) + line_gap + text_gap + 40])

str_box = {
    '\textbf{UA Control } ($E \pm$ SEM)';
    sprintf('  Zone 1: %.1f $\\pm$ %.1f', E_prom_ctrl_fit(1), sem_ctrl_fit(1));
    sprintf('  Zone 2: %.1f $\\pm$ %.1f', E_prom_ctrl_fit(2), sem_ctrl_fit(2));
    sprintf('  Zone 3: %.1f $\\pm$ %.1f', E_prom_ctrl_fit(3), sem_ctrl_fit(3));
    '';
    '\textbf{UA FGR } ($E \pm$ SEM)';
    sprintf('  Zone 1: %.1f $\\pm$ %.1f', E_prom_fgr_fit(1), sem_fgr_fit(1));
    sprintf('  Zone 2: %.1f $\\pm$ %.1f', E_prom_fgr_fit(2), sem_fgr_fit(2));
    sprintf('  Zone 3: %.1f $\\pm$ %.1f', E_prom_fgr_fit(3), sem_fgr_fit(3))
};

tb = text(0.03, 0.75, str_box, 'Units', 'normalized');
tb.Interpreter = 'latex';
tb.FontSize = 13;
tb.BackgroundColor = [0.98 0.98 0.98];
tb.EdgeColor = 'k';
tb.Margin = 5;
tb.VerticalAlignment = 'top';
legend('Location','northwest','FontSize',11,'Box','off')
hold off;
%exportgraphics(gcf, 'Figure2_E_Modulus.tif', 'Resolution', 300);
%exportgraphics(gcf, 'Figure2_E_Modulus.pdf', 'ContentType', 'vector');

%% 12. Modulo elastico de Demiray entre lambda = 1.55 y 1.75 (secante y tangente)
% CORRECCION 5: el original usaba a_ctrl, b_ctrl, a_fgr, b_fgr (sin
% sufijo "_fijo"), variables que no existen; se reemplaza por los
% nombres reales definidos en la seccion 4.
lam1 = 1.55;
lam2 = 1.75;

sigma_demiray = @(lam, a, b) a .* (lam.^2 - 1./lam) .* exp((b/2) .* (lam.^2 + 2./lam - 3)) * 1000;

sigma1_ctrl = sigma_demiray(lam1, a_ctrl_fijo, b_ctrl_fijo);
sigma2_ctrl = sigma_demiray(lam2, a_ctrl_fijo, b_ctrl_fijo);
E_secante_ctrl = (sigma2_ctrl - sigma1_ctrl) / (lam2 - lam1);

sigma1_fgr = sigma_demiray(lam1, a_fgr_fijo, b_fgr_fijo);
sigma2_fgr = sigma_demiray(lam2, a_fgr_fijo, b_fgr_fijo);
E_secante_fgr = (sigma2_fgr - sigma1_fgr) / (lam2 - lam1);

dsigma_demiray = @(lam, a, b) a .* ( (2*lam + 1./lam.^2) + (lam.^2 - 1./lam).*(b).*(lam - 1./lam.^2) ) ...
                  .* exp((b/2).*(lam.^2 + 2./lam - 3)) * 1000;

lam_fino = linspace(lam1, lam2, 200);

E_tan_ctrl_vec = dsigma_demiray(lam_fino, a_ctrl_fijo, b_ctrl_fijo);
E_tan_fgr_vec  = dsigma_demiray(lam_fino, a_fgr_fijo,  b_fgr_fijo);

E_tangente_ctrl = mean(E_tan_ctrl_vec);
E_tangente_fgr  = mean(E_tan_fgr_vec);

fprintf('\n========== MODULO ELASTICO DEMIRAY [lambda = %.2f a %.2f] ==========\n', lam1, lam2);
fprintf('%-12s %15s %15s\n', 'Grupo', 'E secante', 'E tangente (avg)');
fprintf('%-12s %15.3f %15.3f\n', 'Control', E_secante_ctrl, E_tangente_ctrl);
fprintf('%-12s %15.3f %15.3f\n', 'FGR',     E_secante_fgr,  E_tangente_fgr);
fprintf('(unidades: kPa, ya que sigma esta en kPa y lambda es adimensional)\n');
fprintf('==========================================================================\n\n');