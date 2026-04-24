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

L0_ctrl = 4.0;
L0_fgr  = 4.0;
A0_ctrl = 5.91;
A0_fgr  = 5.64;

%% --- 1. LEER PARAMETROS DEMIRAY ---
archivo = 'Resumen_datos_Procesados.xlsx';
params  = readmatrix(archivo, 'Sheet', 'Parametros', 'Range', 'D6:E7');
a_ctrl  = params(1,1);
b_ctrl  = params(2,1);
a_fgr   = params(1,2);
b_fgr   = params(2,2);

fprintf('=== Parametros Demiray ===\n')
fprintf('UA_Control: a = %.4f MPa,  b = %.4f\n', a_ctrl, b_ctrl)
fprintf('UA_FGR:     a = %.4f MPa,  b = %.4f\n', a_fgr,  b_fgr)

%% --- 2. LEER DATOS EXPERIMENTALES ---
disp_ctrl   = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'AE3:AE2792');
fuerza_ctrl = readmatrix(archivo, 'Sheet', 'AU_N',   'Range', 'AH3:AH2792');
disp_fgr    = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'AE3:AE2227');
fuerza_fgr  = readmatrix(archivo, 'Sheet', 'AU_FGR', 'Range', 'AH3:AH2227');

%% --- 3. STRETCH Y CAUCHY EXPERIMENTAL ---
lambda_ctrl = (L0_ctrl + disp_ctrl) ./ L0_ctrl;
lambda_fgr  = (L0_fgr  + disp_fgr)  ./ L0_fgr;

sigma_ctrl  = (fuerza_ctrl ./ A0_ctrl) .* lambda_ctrl * 1000;  % [kPa]
sigma_fgr   = (fuerza_fgr  ./ A0_fgr)  .* lambda_fgr  * 1000;  % [kPa]

fprintf('\nλ_max ctrl=%.3f,  λ_max fgr=%.3f\n', max(lambda_ctrl), max(lambda_fgr))

%% --- 4. MODELO DEMIRAY CORREGIDO ---
% Formula correcta (Utrera, ec. 2.8): b/2 en el exponente
% σ = a*(λ²-1/λ) * exp(b/2*(λ²+2/λ-3))
lambda_vec = linspace(1.0, 2.0, 1000);

sigma_dem_ctrl = a_ctrl .* (lambda_vec.^2 - 1./lambda_vec) .* ...
                 exp((b_ctrl/2) .* (lambda_vec.^2 + 2./lambda_vec - 3)) * 1000;  % [kPa]

sigma_dem_fgr  = a_fgr  .* (lambda_vec.^2 - 1./lambda_vec) .* ...
                 exp((b_fgr/2)  .* (lambda_vec.^2 + 2./lambda_vec - 3)) * 1000;  % [kPa]

%% --- 5. MAXIMO ESFUERZO DE DISTENSION ---
[s_max_ctrl, idx_c] = max(sigma_dem_ctrl);
[s_max_fgr,  idx_f] = max(sigma_dem_fgr);

fprintf('\n=== Maximo Esfuerzo de Distension (Demiray) ===\n')
fprintf('UA_Control: σ_max = %.2f kPa  en λ = %.4f\n', s_max_ctrl, lambda_vec(idx_c))
fprintf('UA_FGR:     σ_max = %.2f kPa  en λ = %.4f\n', s_max_fgr,  lambda_vec(idx_f))

%% --- 6. GRAFICO ---
figure('Position', [100 100 850 580]);
hold on; box on;

plot(lambda_ctrl, sigma_ctrl, 'o', 'Color', 'r', ...
     'MarkerSize', 3, 'MarkerFaceColor', 'none', 'DisplayName', 'UA\_Control (exp)')
plot(lambda_fgr,  sigma_fgr,  's', 'Color', 'b', ...
     'MarkerSize', 3, 'MarkerFaceColor', 'none', 'DisplayName', 'UA\_FGR (exp)')
plot(lambda_vec, sigma_dem_ctrl, '-',  'Color', 'r', ...
     'LineWidth', 2, 'DisplayName', 'UA\_Control (Demiray)')
plot(lambda_vec, sigma_dem_fgr,  '--', 'Color', 'b', ...
     'LineWidth', 2, 'DisplayName', 'UA\_FGR (Demiray)')

xline(1.4, 'k--', 'LineWidth', 1); xline(1.7, 'k--', 'LineWidth', 1)
text(1.05, max(sigma_fgr)*0.92, 'Zone(1)', 'FontSize', 10)
text(1.45, max(sigma_fgr)*0.92, 'Zone(2)', 'FontSize', 10)
text(1.72, max(sigma_fgr)*0.92, 'Zone(3)', 'FontSize', 10)

xlim([1.0 2.0])
xlabel('Stretch (\lambda, u.a.)',      'FontSize', 13)
ylabel('Cauchy Stress (\sigma, kPa)', 'FontSize', 13)
title('Curva Stress-Strain - UA Utrera', 'FontSize', 13)
legend('Location', 'northwest', 'FontSize', 10)
grid on; hold off;

saveas(gcf, 'stress_strain_Utrera.png')
saveas(gcf, 'stress_strain_Utrera.fig')

%% --- 7. MODULOS ELASTICOS (3 ZONAS, 4 CURVAS) ---
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
