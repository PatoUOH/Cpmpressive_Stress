clear; clc;
set(groot,'defaultTextInterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')
 
L0_ctrl = 4.0;  L0_fgr = 4.0;
A0_ctrl = 5.91; A0_fgr = 5.64;
 
archivo = 'Resumen_datos_raw_mod.xlsx';
 
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
 
%% 4. INTERPOLAR LOS DATOS RAW de cada ensayo sobre la grilla comun (SIN Demiray)
sigma_grid_ctrl_raw = NaN(Ng, 5);
sigma_grid_fgr_raw  = NaN(Ng, 5);
 
for k = 1:5
    lk = lambda_ind_ctrl(:,k);     % lambda REAL del ensayo k (distinto entre ensayos)
    mask = ~isnan(lk);
    sigma_dem_k = demiray_model(a_ctrl_fijo, b_ctrl_fijo, lk(mask));  % Demiray evaluado AHI
    sigma_dem_grid_ctrl(:,k) = interp1(lk(mask), sigma_dem_k, grid_ctrl, 'linear', NaN);
end
 
%% 5. SEM de los datos RAW, punto a punto entre los 5 ensayos
sd_ctrl_raw  = std(sigma_grid_ctrl_raw, 0, 2, 'omitnan');
sd_fgr_raw   = std(sigma_grid_fgr_raw,  0, 2, 'omitnan');
 
sigma_sem_raw_ctrl = (sd_ctrl_raw(:)') / sqrt(5);
sigma_sem_raw_fgr  = (sd_fgr_raw(:)')  / sqrt(5);
 
%% 6. CURVA DE DEMIRAY UNICA, con parametros FIJOS por grupo
a_ctrl_fijo = 0.014;  b_ctrl_fijo = 1.0;
a_fgr_fijo  = 0.02;   b_fgr_fijo  = 1.4;
 
demiray_model = @(a, b, lam) a .* (lam.^2 - 1./lam) .* exp((b/2) .* (lam.^2 + 2./lam - 3)) * 1000;
 
sigma_dem_ctrl = demiray_model(a_ctrl_fijo, b_ctrl_fijo, grid_ctrl);
sigma_dem_fgr  = demiray_model(a_fgr_fijo,  b_fgr_fijo,  grid_fgr);
 
fprintf('--- Parametros Demiray FIJOS ---\n');
fprintf('Control: a = %.4f, b = %.4f\n', a_ctrl_fijo, b_ctrl_fijo);
fprintf('FGR:     a = %.4f, b = %.4f\n\n', a_fgr_fijo, b_fgr_fijo);
 
%% 7. Curva de ESFUERZO ACTIVO (6 arterias, miografia de alambre) - sin cambios
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
    sigma_i = (Ta_act{i} ./ (2 * a0 * e0)) .*  lambda_act{i};
    coef_act{i} = polyfit(lambda_act{i}, sigma_i, 2);
end
 
lambda_min_act = max(cellfun(@min, lambda_act));
grid_act_ext = linspace(lambda_min_act, 2, 200);
 
sigma_grid_act_ext = zeros(nArt_act, numel(grid_act_ext));
for i = 1:nArt_act
    sigma_grid_act_ext(i,:) = polyval(coef_act{i}, grid_act_ext);
end
sigma_mean_act_ext = mean(sigma_grid_act_ext, 1);
sigma_sd_act_ext  = std(sigma_grid_act_ext, 0, 1);
sigma_sem_act_ext = sigma_sd_act_ext / sqrt(nArt_act);
 
%% 8. Figura principal (Active stress + Passive stress)
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
% --- Banda SEM viene de los DATOS RAW, la linea central viene de DEMIRAY con (a,b) fijo ---
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

%% 9. MODULO ELASTICO POR ZONAS — METODO POLYFIT (regresion lineal)
z = [1.0, 1.451, 1.845, 2.0];
z3_fin_ctrl = min(lmax_ctrl, z(4));
z3_fin_fgr  = min(lmax_fgr,  z(4));

mask1c = (grid_ctrl >= z(1)) & (grid_ctrl <= z(2));
mask2c = (grid_ctrl >= z(2)) & (grid_ctrl <= z(3));
mask3c = (grid_ctrl >= z(3)) & (grid_ctrl <= z3_fin_ctrl);

mask1f = (grid_fgr >= z(1)) & (grid_fgr <= z(2));
mask2f = (grid_fgr >= z(2)) & (grid_fgr <= z(3));
mask3f = (grid_fgr >= z(3)) & (grid_fgr <= z3_fin_fgr);

% --- E de la curva PROMEDIO (POLYFIT) ---
p1 = polyfit(grid_ctrl(mask1c), sigma_dem_ctrl(mask1c), 1);
p2 = polyfit(grid_ctrl(mask2c), sigma_dem_ctrl(mask2c), 1);
p3 = polyfit(grid_ctrl(mask3c), sigma_dem_ctrl(mask3c), 1);
E_prom_ctrl_fit = [p1(1), p2(1), p3(1)];

p1 = polyfit(grid_fgr(mask1f), sigma_dem_fgr(mask1f), 1);
p2 = polyfit(grid_fgr(mask2f), sigma_dem_fgr(mask2f), 1);
p3 = polyfit(grid_fgr(mask3f), sigma_dem_fgr(mask3f), 1);
E_prom_fgr_fit = [p1(1), p2(1), p3(1)];

% --- E POR ENSAYO INDIVIDUAL (n=5), POLYFIT ---
E_ind_ctrl_fit = NaN(5,3);
E_ind_fgr_fit  = NaN(5,3);

for k = 1:5
    if ~isnan(a_ctrl_ind(k))
        yk = sigma_grid_ctrl(:,k)';
        pk1 = polyfit(grid_ctrl(mask1c), yk(mask1c), 1); E_ind_ctrl_fit(k,1) = pk1(1);
        pk2 = polyfit(grid_ctrl(mask2c), yk(mask2c), 1); E_ind_ctrl_fit(k,2) = pk2(1);
        pk3 = polyfit(grid_ctrl(mask3c), yk(mask3c), 1); E_ind_ctrl_fit(k,3) = pk3(1);
    end
    if ~isnan(a_fgr_ind(k))
        yk = sigma_grid_fgr(:,k)';
        pk1 = polyfit(grid_fgr(mask1f), yk(mask1f), 1); E_ind_fgr_fit(k,1) = pk1(1);
        pk2 = polyfit(grid_fgr(mask2f), yk(mask2f), 1); E_ind_fgr_fit(k,2) = pk2(1);
        pk3 = polyfit(grid_fgr(mask3f), yk(mask3f), 1); E_ind_fgr_fit(k,3) = pk3(1);
    end
end

% --- SEM y significancia (POLYFIT) ---
sem_ctrl_fit = std(E_ind_ctrl_fit, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(E_ind_ctrl_fit),1));
sem_fgr_fit  = std(E_ind_fgr_fit,  0, 1, 'omitnan') ./ sqrt(sum(~isnan(E_ind_fgr_fit),1));

pvals_fit  = NaN(1,3);
tnames_fit = cell(1,3);

for j = 1:3
    % Extraer datos eliminando NaN
    xc = E_ind_ctrl_fit(~isnan(E_ind_ctrl_fit(:,j)), j);
    xf = E_ind_fgr_fit(~isnan(E_ind_fgr_fit(:,j)),  j);
    
    % Evitar errores si el tamaño de muestra es muy pequeño (Lilliefors requiere al menos 4 datos)
    if length(xc) >= 4 && length(xf) >= 4
        % Usar el test de Lilliefors en lugar de K-S estandarizado manual
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
        % Fallback de seguridad si N < 4 (no se puede evaluar normalidad con rigor)
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

%% 10. Histograma — SOLO POLYFIT
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

% --- Configuración de distancias fijas ---
line_gap  = 30; % Distancia fija desde la barra más alta hasta la línea horizontal (en kPa)
text_gap  = 15; % Distancia fija desde la línea horizontal hasta el texto (en kPa)

for j = 1:3
    % 1. Encontrar el punto más alto de la zona actual (barra + error)
    y_max_barra = max([E_prom_ctrl_fit(j)+sem_ctrl_fit(j), E_prom_fgr_fit(j)+sem_fgr_fit(j)]);
    
    % 2. Calcular la posición de la línea sumando el gap fijo
    y_sig = y_max_barra + line_gap;
    
    % 3. Graficar la línea horizontal
    plot([x(j)-offset, x(j)+offset], [y_sig y_sig], 'k-', 'LineWidth', 1, 'HandleVisibility','off')
    
    % 4. Formato del texto
    fs = 14;
    if strcmp(sig_fit{j},'ns'), fs = 11; end
    
    % 5. Graficar el texto sobre la línea usando el segundo gap fijo
    text(x(j), y_sig + text_gap, sig_fit{j}, 'FontSize',fs, 'HorizontalAlignment','center', 'FontWeight','bold', 'Color','k')
end

xticks(x)
xticklabels(etiquetas_x)
xlabel('Stretch Intervals', 'FontSize',13, 'Interpreter','Latex')
ylabel('Stretch Modulus ($E$, kPa)', 'FontSize',13, 'Interpreter','Latex')

% Se actualiza el límite superior considerando ambos gaps fijos para que no se corte el texto
ylim([0, max([E_prom_ctrl_fit+sem_ctrl_fit, E_prom_fgr_fit+sem_fgr_fit]) + line_gap + text_gap + 40])

% --- Cuadro resumen nidificado (Control vs FGR) ---
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
% ---------------------------------------------------------
legend('Location','northwest','FontSize',11,'Box','off')
hold off;
%exportgraphics(gcf, 'Figure2_E_Modulus.tif', 'Resolution', 300);
%exportgraphics(gcf, 'Figure2_E_Modulus.pdf', 'ContentType', 'vector');

%% 7c. Módulo elástico de Demiray entre lambda = 1.4 y 1.6

lam1 = 1.55;
lam2 = 1.75;

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
