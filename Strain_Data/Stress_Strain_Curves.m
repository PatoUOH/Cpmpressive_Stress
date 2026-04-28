%Analisis den datos disponibles en "Demiray_Arenas-Gonzalez"
filename = "Demiray_Arenas-Gonzalez.xlsx";
data = readmatrix(filename, 'NumHeaderLines',1);

Strain = data(:,1); %Columna 1 u.a.
UA_Control = data(:,2:6); %Columnas 2-6 control en MPa
UA_FGR= data(:,7:11); %Columnas 7-11 FGR en MPa

figure(1);
subplot(2,1,1);hold on;
for i = 1:5
plot(Strain, UA_Control(:,i),'Color','r');
end
hold off; grid on;
subplot(2,1,2);hold on;
for i = 1:5
plot(Strain, UA_FGR(:,i),'Color','b');
end
hold off; grid on;

%Unidades en MPa%
%mean_control = mean(UA_Control,2); %Promedio fila a fila Control en MPa
%mean_FGR = mean(UA_FGR,2); %Idem en MPa

%Unidades en kPa%
mean_control = mean(UA_Control,2)*1000; %Promedio fila a fila Control en MPa
mean_FGR = mean(UA_FGR,2)*1000; %Idem en MPa


figure(2);hold on;
plot(Strain, mean_control,'r-s','DisplayName','UA\_Control (Mean)');
plot(Strain,mean_FGR,'b-o','DisplayName','UA\_FGR (Mean)');
xlabel('Strain');ylabel('Stress');legend('show','location','best');grid on; hold off;

%{
Analisis de Resumen datos_Procesados.xlsx de Utrera. En la hoja 1 estan los parametros Demiray. Donde en la celda D2 tengo el parametro a (MPa) y en D3 tengo el parametro b (u.a.) para UA_control. Y en la celda E2 tengo el parametro a (MPa) y en E3 tengo el parametro b (u.a.) para UA_FGR.
Pasamos a la hoja 4 (AU_Control), para los datos promedio de UA_Control, tenemos que el desplazamiento promedio cominza desde la celda AE3 y llega hasta la celda AE2792. Para la Fuerza promedio tengo una duda, ya que desde AG3 hasta AG2792 tengo que realizan el promedio usando desde las columnas Q3:U3 hasta Q2792:U2792, desde la columna AH3:AH2792 calcula el promedio desde W3:AA3 hasta W2792:AA:2792 que corresponde a la fuerza tare y despues desde la columna AI3:AI2792 calculan DESVEST.M(W3:AA3)/RAIZ(5). Entonces creo que debo trabajar con la columna AH cierto?
En la hoja 5 (AU_FGR) es similar a lo mencionado anteriormente, solamente que las columnas llegan hasta 2227.
Haciendo el cambio correspondiente, debo confirmar si la columna de Fuerza promedio AH deberia ser desde I3:M3 (ahi si considero las 5 columnas de Fuerza)
Debo aplicar el modelo Demiray entonces para poder determinar el maximo esfuerzo de distencion para tener ahora la curva stress-strain
%}

clear; clc;

%Activar interprete Latex
set(groot,'defaultTextInterpreter','latex')
set(groot,'defaultAxesTickLabelInterpreter','latex')
set(groot,'defaultLegendInterpreter','latex')

L0_ctrl = 4.0;
L0_fgr  = 4.0;
A0_ctrl = 5.91;
A0_fgr  = 5.64;

%1. Leer los parámetros Demiray del archivo Resumen_datos_Procesados.xlsx
archivo = 'Resumen_datos_Procesados.xlsx';
params  = readmatrix(archivo, 'Sheet', 'Parametros', 'Range', 'D6:E7');
a_ctrl  = params(1,1);
b_ctrl  = params(2,1);
a_fgr   = params(1,2);
b_fgr   = params(2,2);

%fprintf('=== Parametros Demiray ===\n')
%fprintf('UA_Control: a = %.4f MPa,  b = %.4f\n', a_ctrl, b_ctrl)
%fprintf('UA_FGR:     a = %.4f MPa,  b = %.4f\n', a_fgr,  b_fgr)

%2. Leer los datos experimentales para condiciones AU_N => control, AU_FGR => FGR, disp_ctrl es la columna de desplazamiento y fuerza_ctrl es la columna de fuerza aplicada para la condición control, disp_fgr es la columna de desplazamiento y fuerza_fgr es la columna de fuerza aplicada para la condición FGR, 
disp_ctrl   = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'AE3:AE2792');
fuerza_ctrl = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'AH3:AH2792');
disp_fgr    = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'AE3:AE2227');
fuerza_fgr  = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'AH3:AH2227');

%%3. Stretch (\lambda) experimental
%L0=largo inicial (valor prefijado)
lambda_ctrl = (L0_ctrl + disp_ctrl) ./ L0_ctrl;
lambda_fgr  = (L0_fgr  + disp_fgr)  ./ L0_fgr;

sigma_ctrl  = (fuerza_ctrl ./ A0_ctrl) .* lambda_ctrl * 1000;  % [kPa]
sigma_fgr   = (fuerza_fgr  ./ A0_fgr)  .* lambda_fgr  * 1000;  % [kPa]

fprintf('\nλ_max ctrl=%.3f,  λ_max fgr=%.3f\n', max(lambda_ctrl), max(lambda_fgr))

%4. Modelo Demiray
% Utrera, ec. 2.8: b/2 en el exponente
% σ = a*(λ²-1/λ) * exp(b/2*(λ²+2/λ-3))
lambda_vec = linspace(1.0, 2.0, 1000);

sigma_dem_ctrl = a_ctrl .* (lambda_vec.^2 - 1./lambda_vec) .* exp((b_ctrl/2) .* (lambda_vec.^2 + 2./lambda_vec - 3)) * 1000;  % [kPa]

sigma_dem_fgr  = a_fgr  .* (lambda_vec.^2 - 1./lambda_vec) .* exp((b_fgr/2)  .* (lambda_vec.^2 + 2./lambda_vec - 3)) * 1000;  % [kPa]

%5. Máximo esfuerzo de distensión
[s_max_ctrl, idx_c] = max(sigma_dem_ctrl);
[s_max_fgr,  idx_f] = max(sigma_dem_fgr);

%fprintf('\n=== Maximo Esfuerzo de Distension (Demiray) ===\n')
%fprintf('UA_Control: σ_max = %.2f kPa  en λ = %.4f\n', s_max_ctrl, lambda_vec(idx_c))
%fprintf('UA_FGR:     σ_max = %.2f kPa  en λ = %.4f\n', s_max_fgr,  lambda_vec(idx_f))

%Plots
%Para los datos experimentales mostrare menos puntos para no saturar la curva resultante
N = 20;
lambda_ctrl_idx = 1:N:length(lambda_ctrl);
lambda_fgr_idx = 1:N:length(lambda_fgr);
figure('Position', [100 100 850 580]);
hold on; box on;
%Plot datos reales
plot(lambda_ctrl(lambda_ctrl_idx), sigma_ctrl(lambda_ctrl_idx), 'o-', 'Color', 'r', 'DisplayName', 'UA\_Control (exp)')
plot(lambda_fgr(lambda_fgr_idx),  sigma_fgr(lambda_fgr_idx),  's-', 'Color', 'b', 'DisplayName', 'UA\_FGR (exp)')
%Plot Modelo Demiray
plot(lambda_vec, sigma_dem_ctrl, '-',  'Color', 'r','DisplayName', 'UA\_Control (Demiray)')
plot(lambda_vec, sigma_dem_fgr,  '--', 'Color', 'b','DisplayName', 'UA\_FGR (Demiray)')

%Zonas de interés (Z1: sub-estiramiento; Z2: fisiológico; Z3: sobre-estiramiento)
xline(1.5, 'k--', 'LineWidth', 1,'HandleVisibility','off'); xline(1.8, 'k--', 'LineWidth', 1,'HandleVisibility','off') %Zone1: [1-1.4); Zone2: [1.5-1.8); Zone3: [1.8-2)
text(1.22, -30, 'Zone(1)', 'FontSize', 10)
text(1.62, -30, 'Zone(2)', 'FontSize', 10)
text(1.87, -30, 'Zone(3)', 'FontSize', 10)

xlim([1.0 2.0]);ylim([-50 350]);
xlabel('Stretch $(\lambda$, u.a.)','FontSize', 13)
ylabel('Cauchy Stress $(\sigma$, kPa)','FontSize', 13)
legend('Location', 'best', 'FontSize', 10)
grid on; hold off;

%% 8. Modulo elastico aparente
% Limites de zonas
z = [1.0, 1.5, 1.8, 2.0];

% Funcion: modulo secante por teorema del valor medio
get_E = @(lv, sv, l1, l2) ...
    (sv(find(abs(lv - l2) == min(abs(lv - l2)), 1)) - ...
     sv(find(abs(lv - l1) == min(abs(lv - l1)), 1))) / (l2 - l1);

% Funcion: recta secante entre dos limites de zona
line_secante = @(lv, sv, l1, l2) deal( ...
    [l1, l2], ...
    [sv(find(abs(lv-l1)==min(abs(lv-l1)),1)), ...
     sv(find(abs(lv-l2)==min(abs(lv-l2)),1))] );

% Funcion: subzona recorta vectores al rango [l1,l2]
subzona = @(lv, sv, l1, l2) deal(lv(lv>=l1 & lv<=l2), sv(lv>=l1 & lv<=l2));

% Funcion: modulo + incertidumbre por regresion lineal (polyfit)
% calc_E = @(lv_z, sv_z) deal( ...
%     polyfit(lv_z, sv_z, 1) * [1;0], ...
%     sqrt( sum((sv_z - polyval(polyfit(lv_z,sv_z,1), lv_z)).^2) / ...
%           (length(lv_z)-2) / sum((lv_z-mean(lv_z)).^2) ) );
calc_E = @(lv_z, sv_z) deal( ...
    (sv_z(end) - sv_z(1)) / (lv_z(end) - lv_z(1)), ...   % modulo secante
    std(diff(sv_z) ./ diff(lv_z)) );    

% Limite real de Z3 segun datos disponibles
lam_max_ctrl = max(lambda_ctrl);
lam_max_fgr  = max(lambda_fgr);
z3_fin_ctrl  = min(lam_max_ctrl, z(4));
z3_fin_fgr   = min(lam_max_fgr,  z(4));

% Calcular modulos secantes (para rectas)
E.ctrl_exp = [get_E(lambda_ctrl, sigma_ctrl,     z(1), z(2)), ...
              get_E(lambda_ctrl, sigma_ctrl,     z(2), z(3)), ...
              get_E(lambda_ctrl, sigma_ctrl,     z(3), z3_fin_ctrl)];
E.fgr_exp  = [get_E(lambda_fgr,  sigma_fgr,     z(1), z(2)), ...
              get_E(lambda_fgr,  sigma_fgr,     z(2), z(3)), ...
              get_E(lambda_fgr,  sigma_fgr,     z(3), z3_fin_fgr)];
E.ctrl_dem = [get_E(lambda_vec, sigma_dem_ctrl, z(1), z(2)), ...
              get_E(lambda_vec, sigma_dem_ctrl, z(2), z(3)), ...
              get_E(lambda_vec, sigma_dem_ctrl, z(3), z(4))];
E.fgr_dem  = [get_E(lambda_vec, sigma_dem_fgr,  z(1), z(2)), ...
              get_E(lambda_vec, sigma_dem_fgr,  z(2), z(3)), ...
              get_E(lambda_vec, sigma_dem_fgr,  z(3), z(4))];

% Calcular modulos con incertidumbre (para etiquetas)
[lv_z,sv_z]=subzona(lambda_ctrl,sigma_ctrl,z(1),z(2)); [E1c, S1c] =calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_ctrl,sigma_ctrl,z(2),z(3)); [E2c, S2c] =calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_ctrl,sigma_ctrl,z(3),z3_fin_ctrl); [E3c,S3c]=calc_E(lv_z,sv_z);

[lv_z,sv_z]=subzona(lambda_fgr, sigma_fgr, z(1),z(2)); [E1f, S1f] =calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_fgr, sigma_fgr, z(2),z(3)); [E2f, S2f] =calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_fgr, sigma_fgr, z(3),z3_fin_fgr);  [E3f,S3f]=calc_E(lv_z,sv_z);

[lv_z,sv_z]=subzona(lambda_vec,sigma_dem_ctrl,z(1),z(2)); [E1cd,S1cd]=calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_vec,sigma_dem_ctrl,z(2),z(3)); [E2cd,S2cd]=calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_vec,sigma_dem_ctrl,z(3),z(4)); [E3cd,S3cd]=calc_E(lv_z,sv_z);

[lv_z,sv_z]=subzona(lambda_vec,sigma_dem_fgr, z(1),z(2)); [E1fd,S1fd]=calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_vec,sigma_dem_fgr, z(2),z(3)); [E2fd,S2fd]=calc_E(lv_z,sv_z);
[lv_z,sv_z]=subzona(lambda_vec,sigma_dem_fgr, z(3),z(4)); [E3fd,S3fd]=calc_E(lv_z,sv_z);

% Tabla resumen
% fprintf('\n=================================================================\n')
% fprintf('     MODULO ELASTICO APARENTE +- error estandar [kPa]           \n')
% fprintf('=================================================================\n')
% fprintf('%-24s  %-20s  %-20s  %-20s\n','Curva','Z1 [1.0-1.5]','Z2 [1.5-1.8]','Z3 [1.8-2.0]')
% fprintf('-----------------------------------------------------------------\n')
% fprintf('%-24s  %6.1f +- %5.1f  %6.1f +- %5.1f  %6.1f +- %5.1f\n','UA_Control (exp)',    E1c,S1c,   E2c,S2c,   E3c,S3c)
% fprintf('%-24s  %6.1f +- %5.1f  %6.1f +- %5.1f  %6.1f +- %5.1f\n','UA_FGR     (exp)',    E1f,S1f,   E2f,S2f,   E3f,S3f)
% fprintf('%-24s  %6.1f +- %5.1f  %6.1f +- %5.1f  %6.1f +- %5.1f\n','UA_Control (Demiray)',E1cd,S1cd, E2cd,S2cd, E3cd,S3cd)
% fprintf('%-24s  %6.1f +- %5.1f  %6.1f +- %5.1f  %6.1f +- %5.1f\n','UA_FGR     (Demiray)',E1fd,S1fd, E2fd,S2fd, E3fd,S3fd)
% fprintf('=================================================================\n')
% fprintf('Target hidrogel (exp, Zona 2):\n')
% fprintf('  UA_Control -> E_Z2 = %.1f +- %.1f kPa\n', E2c, S2c)
% fprintf('  UA_FGR     -> E_Z2 = %.1f +- %.1f kPa\n', E2f, S2f)
% fprintf('=================================================================\n')

%% Grafico
N = 20;
lambda_ctrl_idx = 1:N:length(lambda_ctrl);
lambda_fgr_idx  = 1:N:length(lambda_fgr);

figure('Position', [100 100 950 600]);
hold on; box on;

% Datos experimentales
plot(lambda_ctrl(lambda_ctrl_idx), sigma_ctrl(lambda_ctrl_idx), 'o', ...
     'Color','r','MarkerSize',4,'MarkerFaceColor','none','DisplayName','UA\_Control (exp)')
plot(lambda_fgr(lambda_fgr_idx),   sigma_fgr(lambda_fgr_idx),   's', ...
     'Color','b','MarkerSize',4,'MarkerFaceColor','none','DisplayName','UA\_FGR (exp)')

% Curvas Demiray
plot(lambda_vec, sigma_dem_ctrl, '-',  'Color','r','LineWidth',2,'DisplayName','UA\_Control (Demiray)')
plot(lambda_vec, sigma_dem_fgr,  '--', 'Color','b','LineWidth',2,'DisplayName','UA\_FGR (Demiray)')

% Rectas secantes: solido = experimental, punteado = Demiray
zonas_ctrl = {[z(1) z(2)], [z(2) z(3)], [z(3) z3_fin_ctrl]};
zonas_fgr  = {[z(1) z(2)], [z(2) z(3)], [z(3) z3_fin_fgr]};
zonas_dem  = {[z(1) z(2)], [z(2) z(3)], [z(3) z(4)]};

for k = 1:3
    [lx,ly]=line_secante(lambda_ctrl,sigma_ctrl,    zonas_ctrl{k}(1),zonas_ctrl{k}(2));
    plot(lx,ly,'k-', 'LineWidth',0.5,'HandleVisibility','off')
    [lx,ly]=line_secante(lambda_fgr, sigma_fgr,     zonas_fgr{k}(1), zonas_fgr{k}(2));
    plot(lx,ly,'k-', 'LineWidth',0.5,'HandleVisibility','off')
    [lx,ly]=line_secante(lambda_vec, sigma_dem_ctrl, zonas_dem{k}(1), zonas_dem{k}(2));
    plot(lx,ly,'k:', 'LineWidth',0.5,'HandleVisibility','off')
    [lx,ly]=line_secante(lambda_vec, sigma_dem_fgr,  zonas_dem{k}(1), zonas_dem{k}(2));
    plot(lx,ly,'k:', 'LineWidth',0.5,'HandleVisibility','off')
end

% Lineas de zona
xline(1.5,'k--','LineWidth',1,'HandleVisibility','off');
xline(1.8,'k--','LineWidth',1,'HandleVisibility','off');

% Etiquetas zona + modulos con +-
% Zone 1
text(1.22, -30,  'Zone(1)',  'FontSize',10)
text(1.22, -52,  sprintf('$E_{exp}^{ctrl}$=%.0f$\\pm$%.0f kPa', E1c, S1c),   'FontSize',8,'Color','r')
text(1.22, -72,  sprintf('$E_{exp}^{FGR}$=%.0f$\\pm$%.0f kPa',  E1f, S1f),   'FontSize',8,'Color','b')
text(1.22, -92,  sprintf('$E_{Dem}^{ctrl}$=%.0f$\\pm$%.0f kPa', E1cd,S1cd),  'FontSize',8,'Color',[0.6 0 0])
text(1.22, -112, sprintf('$E_{Dem}^{FGR}$=%.0f$\\pm$%.0f kPa',  E1fd,S1fd),  'FontSize',8,'Color',[0 0 0.6])
% Zone 2
text(1.62, -30,  'Zone(2)',  'FontSize',10)
text(1.62, -52,  sprintf('$E_{exp}^{ctrl}$=%.0f$\\pm$%.0f kPa', E2c, S2c),   'FontSize',8,'Color','r')
text(1.62, -72,  sprintf('$E_{exp}^{FGR}$=%.0f$\\pm$%.0f kPa',  E2f, S2f),   'FontSize',8,'Color','b')
text(1.62, -92,  sprintf('$E_{Dem}^{ctrl}$=%.0f$\\pm$%.0f kPa', E2cd,S2cd),  'FontSize',8,'Color',[0.6 0 0])
text(1.62, -112, sprintf('$E_{Dem}^{FGR}$=%.0f$\\pm$%.0f kPa',  E2fd,S2fd),  'FontSize',8,'Color',[0 0 0.6])
% Zone 3
text(1.87, -30,  'Zone(3)',  'FontSize',10)
text(1.87, -52,  sprintf('$E_{exp}^{ctrl}$=%.0f$\\pm$%.0f kPa', E3c, S3c),   'FontSize',8,'Color','r')
text(1.87, -72,  sprintf('$E_{exp}^{FGR}$=%.0f$\\pm$%.0f kPa',  E3f, S3f),   'FontSize',8,'Color','b')
text(1.87, -92,  sprintf('$E_{Dem}^{ctrl}$=%.0f$\\pm$%.0f kPa', E3cd,S3cd),  'FontSize',8,'Color',[0.6 0 0])
text(1.87, -112, sprintf('$E_{Dem}^{FGR}$=%.0f$\\pm$%.0f kPa',  E3fd,S3fd),  'FontSize',8,'Color',[0 0 0.6])

xlim([1.0 2.0]); ylim([-150 350])
xlabel('Stretch $(\lambda$, u.a.)',      'FontSize',13)
ylabel('Cauchy Stress $(\sigma$, kPa)', 'FontSize',13)
legend('Location','northwest',           'FontSize',10)
grid on; hold off;
              

%saveas(gcf, 'stress_strain_Utrera.png')
%saveas(gcf, 'stress_strain_Utrera.fig')

%7. Calcular el ajuste entre el Modelo Demiray los datos reales
%Interpolación de Demiray en los puntos experimentales
sigma_dem_ctrl_i = interp1(lambda_vec, sigma_dem_ctrl, lambda_ctrl,'linear',NaN);
sigma_dem_fgr_i = interp1(lambda_vec, sigma_dem_fgr, lambda_fgr,'linear',NaN);
%Mascara sigma > 1 [kPa] para evitar división por cero cerca de lambda
mk_ctrl = isfinite(sigma_dem_ctrl_i) & sigma_ctrl > 1;
mk_fgr = isfinite(sigma_dem_fgr_i) & sigma_fgr > 1;
%Residuos absolutos
res_ctrl = sigma_dem_ctrl_i(mk_ctrl) - sigma_ctrl(mk_ctrl);
res_fgr = sigma_dem_fgr_i(mk_fgr) - sigma_fgr(mk_fgr);
%Error relativo
err_ctrl = res_ctrl ./ sigma_ctrl(mk_ctrl)*100;
err_fgr = res_fgr ./ sigma_fgr(mk_fgr)*100;
%RMSE
rmse_ctrl = sqrt(mean(res_ctrl.^2));
rmse_fgr = sqrt(mean(res_fgr.^2));
%r^2
r2_ctrl = 1-sum(res_ctrl.^2)/sum((sigma_ctrl(mk_ctrl)-mean(sigma_ctrl(mk_ctrl))).^2);
r2_fgr = 1-sum(res_fgr.^2)/sum((sigma_fgr(mk_fgr)-mean(sigma_fgr(mk_fgr))).^2);
%Ajuste de bondad Demiray
fprintf('UA_control: RMSE = %.2f [kPa] r^2 = %.4f\n',rmse_ctrl,r2_ctrl)
fprintf('UA_FGR: RMSE = %.2f [kPa] r^2 = %.4f\n',rmse_fgr,r2_fgr)
%Figure2
%Análisis estadístico
figure('Position',[100 100 1200 420]);
%Residuos absolutos
subplot(131);hold on; box on;
plot(lambda_ctrl(mk_ctrl), res_ctrl,'.','Color','r','MarkerSize',3,'DisplayName','UA\_Control')
plot(lambda_fgr(mk_fgr), res_fgr,'.','Color','b','MarkerSize',3,'DisplayName','UA\_FGR')
yline(0,  'k-',  'LineWidth', 1,   'HandleVisibility', 'off')
yline( rmse_ctrl, '--', 'Color', 'r', 'LineWidth', 0.8, 'HandleVisibility', 'off')
yline(-rmse_ctrl, '--', 'Color', 'r', 'LineWidth', 0.8, 'HandleVisibility', 'off')
yline( rmse_fgr,  '--', 'Color', 'b', 'LineWidth', 0.8, 'HandleVisibility', 'off')
yline(-rmse_fgr,  '--', 'Color', 'b', 'LineWidth', 0.8, 'HandleVisibility', 'off')
xline(1.5, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off')
xline(1.8, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off')
xlim([1.0 2.0])
xlabel('Stretch $(\lambda)$',            'FontSize', 11)
ylabel('$\sigma_{Dem} - \sigma_{exp}$ (kPa)', 'FontSize', 11)
title('Residuos absolutos',              'FontSize', 11)
legend('Location', 'northwest',          'FontSize', 9)
grid on; hold off;
%Error relativo
subplot(132);hold on; box on;
win = 80;
err_ctrl_sm = movmean(err_ctrl,win);
err_fgr_sm = movmean(err_fgr,win);
plot(lambda_ctrl(mk_ctrl), err_ctrl_sm, '-', 'Color', 'r','LineWidth', 1.8, 'DisplayName', 'UA\_Control')
plot(lambda_fgr(mk_fgr),  err_fgr_sm,  '-', 'Color','b','LineWidth', 1.8, 'DisplayName', 'UA\_FGR')
yline( 0,  'k-',  'LineWidth', 1,   'HandleVisibility', 'off')
yline( 20, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off')
yline(-20, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off')
xline(1.5, 'k:', 'LineWidth', 0.8,  'HandleVisibility', 'off')
xline(1.8, 'k:', 'LineWidth', 0.8,  'HandleVisibility', 'off')
xlim([1.0 2.0]); ylim([-80 80])
xlabel('Stretch $(\lambda)$',  'FontSize', 11)
ylabel('Error relativo (\%)', 'FontSize', 11)
title('Error relativo (suavizado)', 'FontSize', 11)
text(1.52, 70, '$\pm 20\%$', 'FontSize', 9, 'Color', [0.4 0.4 0.4])
legend('Location', 'northeast', 'FontSize', 9)
grid on; hold off;
%sigma_exp vs sigma_dem
subplot(133);hold on; box on;
scatter(sigma_ctrl(mk_ctrl), sigma_dem_ctrl_i(mk_ctrl), 4, 'r', 'filled', 'MarkerFaceAlpha', 0.3,'DisplayName', sprintf('UA\\_Control  $R^2$=%.3f', r2_ctrl))
scatter(sigma_fgr(mk_fgr),  sigma_dem_fgr_i(mk_fgr),  4, 'b', 'filled', 'MarkerFaceAlpha', 0.3,'DisplayName', sprintf('UA\\_FGR  $R^2$=%.3f', r2_fgr))
lims = [0 max([sigma_ctrl(mk_ctrl); sigma_fgr(mk_fgr)])];
plot(lims, lims, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off')
xlabel('$\sigma_{exp}$ (kPa)',    'FontSize', 11)
ylabel('$\sigma_{Demiray}$ (kPa)', 'FontSize', 11)
title('Identidad exp vs Demiray', 'FontSize', 11)
legend('Location', 'northwest',   'FontSize', 9)
axis equal; grid on; hold off;




%N. Módulos elásticos aparentes
get_E = @(lv, sv, l1, l2) ...
    (sv(find(abs(lv-l2)==min(abs(lv-l2)),1)) - ...
     sv(find(abs(lv-l1)==min(abs(lv-l1)),1))) / (l2-l1);

z1a=1.0; z1b=1.4; z2a=1.4; z2b=1.7; z3a=1.7;
lam_max_ctrl = max(lambda_ctrl);
lam_max_fgr  = max(lambda_fgr);
lam_max_dem  = lambda_vec(end);

E1_ctrl_exp = get_E(lambda_ctrl, sigma_ctrl, z1a, z1b);
E2_ctrl_exp = get_E(lambda_ctrl, sigma_ctrl, z2a, z2b);
E3_ctrl_exp = get_E(lambda_ctrl, sigma_ctrl, z3a, lam_max_ctrl);

E1_fgr_exp  = get_E(lambda_fgr,  sigma_fgr,  z1a, z1b);
E2_fgr_exp  = get_E(lambda_fgr,  sigma_fgr,  z2a, z2b);
E3_fgr_exp  = get_E(lambda_fgr,  sigma_fgr,  z3a, lam_max_fgr);

E1_ctrl_dem = get_E(lambda_vec, sigma_dem_ctrl, z1a, z1b);
E2_ctrl_dem = get_E(lambda_vec, sigma_dem_ctrl, z2a, z2b);
E3_ctrl_dem = get_E(lambda_vec, sigma_dem_ctrl, z3a, lam_max_dem);

E1_fgr_dem  = get_E(lambda_vec, sigma_dem_fgr,  z1a, z1b);
E2_fgr_dem  = get_E(lambda_vec, sigma_dem_fgr,  z2a, z2b);
E3_fgr_dem  = get_E(lambda_vec, sigma_dem_fgr,  z3a, lam_max_dem);

%% --- 8. TABLA RESUMEN ---
fprintf('\n================================================================\n')
fprintf('           MODULOS ELASTICOS APARENTES [kPa]                   \n')
fprintf('================================================================\n')
fprintf('%-26s %11s %12s %12s\n','Curva','E1(1.0-1.4)','E2(1.4-1.7)', ...
        sprintf('E3(1.7-%.2f)',lam_max_ctrl))
fprintf('----------------------------------------------------------------\n')
fprintf('%-26s %11.1f %12.1f %12.1f\n','UA_Control (exp)',    E1_ctrl_exp,E2_ctrl_exp,E3_ctrl_exp)
fprintf('%-26s %11.1f %12.1f %12.1f\n','UA_FGR     (exp)',    E1_fgr_exp, E2_fgr_exp, E3_fgr_exp)
fprintf('%-26s %11.1f %12.1f %12.1f\n','UA_Control (Demiray)',E1_ctrl_dem,E2_ctrl_dem,E3_ctrl_dem)
fprintf('%-26s %11.1f %12.1f %12.1f\n','UA_FGR     (Demiray)',E1_fgr_dem, E2_fgr_dem, E3_fgr_dem)
fprintf('================================================================\n')
fprintf('Referencia Utrera:\n')
fprintf('UA_Control: E1=53.0   E2=125.4   E3=266.2 kPa\n')
fprintf('UA_FGR:     E1=56.2   E2=275.1   E3=576.6 kPa\n')
fprintf('================================================================\n')
