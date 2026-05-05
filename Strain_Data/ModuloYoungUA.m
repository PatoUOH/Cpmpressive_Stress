%%%%%%%%%%%%Primera parte inicio%%%%%%%%%%%%%%%%%
%cd /Users/patricio/Desktop/Doctorado/Dr.Krause/DatosAbstract/

Datos_UAGenerical = 'Demiray_Arenas-Gonzalez.xlsx';
Strain = readtable(Datos_UAGenerical, 'Sheet','Umbilicales', 'Range', 'A2:A67');

%Stress UA normal
Stress_UAN1 = readtable(Datos_UAGenerical, 'Range', 'B2:B67');
Stress_UAN2 = readtable(Datos_UAGenerical, 'Range', 'C2:C67');
Stress_UAN3 = readtable(Datos_UAGenerical, 'Range', 'D2:D67');
Stress_UAN4 = readtable(Datos_UAGenerical, 'Range', 'E2:E67');
Stress_UAN5 = readtable(Datos_UAGenerical, 'Range', 'F2:F67');

%Stress UA FGR
Stress_UAFGR1 = readtable(Datos_UAGenerical, 'Range', 'G2:G67');
Stress_UAFGR2 = readtable(Datos_UAGenerical, 'Range', 'H2:H67');
Stress_UAFGR3 = readtable(Datos_UAGenerical, 'Range', 'I2:I67');
Stress_UAFGR4 = readtable(Datos_UAGenerical, 'Range', 'J2:J67');
Stress_UAFGR5 = readtable(Datos_UAGenerical, 'Range', 'K2:K67');

Strain = Strain{:,1};
Stress_UAN1 = Stress_UAN1{:,1};
Stress_UAN2 = Stress_UAN2{:,1};
Stress_UAN3 = Stress_UAN3{:,1};
Stress_UAN4 = Stress_UAN4{:,1};
Stress_UAN5 = Stress_UAN5{:,1};
Stress_UAFGR1 = Stress_UAFGR1{:,1};
Stress_UAFGR2 = Stress_UAFGR2{:,1};
Stress_UAFGR3 = Stress_UAFGR3{:,1};
Stress_UAFGR4 = Stress_UAFGR4{:,1};
Stress_UAFGR5 = Stress_UAFGR5{:,1};
%%%%%%%%%%%%Primera parte final%%%%%%%%%%%%%%%%%

%Promedio y el error estándar para Stress_UAN y Stress_UAFGR
%%%%%%%%%%%Segunda parte inicio%%%%%%%%%%%%%%%
Mean_Stress_UAN = mean([Stress_UAN1, Stress_UAN2, Stress_UAN3, Stress_UAN4, Stress_UAN5], 2);
SE_Stress_UAN = std([Stress_UAN1, Stress_UAN2, Stress_UAN3, Stress_UAN4, Stress_UAN5], 0, 2) / sqrt(5);

Mean_Stress_UAFGR = mean([Stress_UAFGR1, Stress_UAFGR2, Stress_UAFGR3, Stress_UAFGR4, Stress_UAFGR5], 2);
SE_Stress_UAFGR = std([Stress_UAFGR1, Stress_UAFGR2, Stress_UAFGR3, Stress_UAFGR4, Stress_UAFGR5], 0, 2) / sqrt(5);
%%%%%%%%%%%Segunda parte finakl%%%%%%%%%%%%%%%


%%%%%%%%%%%Tercera parte inicio%%%%%%%%%%%%%%%
% Con este código muestro el promedio de las muestras UAN y UAFGR y su errorbar hacia arriba
figure;
% Error hacia arriba (positivo)
errorbar(Strain, Mean_Stress_UAN * 1000, zeros(size(SE_Stress_UAN * 1000)), SE_Stress_UAN * 1000, 'o-', 'MarkerSize', 6, 'Color', 'r');
hold on;
errorbar(Strain, Mean_Stress_UAFGR * 1000, zeros(size(SE_Stress_UAFGR * 1000)), SE_Stress_UAFGR * 1000, 'square-', 'MarkerSize', 6, 'Color', 'b');

% Etiquetas y títulos
xlabel('Stretch $(\lambda)$', 'FontSize', 16, 'Interpreter', 'Latex');
ylabel('Cauchy Stress ($\sigma$,KPa)', 'FontSize', 16, 'Interpreter', 'Latex');
legend({'UA Control', 'UA FGR'}, 'Location', 'northwest');

% Configuraciones adicionales
grid on; ylim([0 350]);

%Primera derivada de la curva stress-strain
dSS_UAN = gradient(Mean_Stress_UAN*1000,Strain);
dSS_UAFGR = gradient(Mean_Stress_UAFGR*1000,Strain);
figure;plot(Strain, dSS_UAN,'o-','MarkerSize',6,'Color','r');grid on;
hold on;
plot(Strain,dSS_UAFGR,'square-','MarkerSize',6,'Color','b');
hold off

%Definición de zonas de interes
z1 = (Strain >=1)&(Strain <= 1.34);
z2 = (Strain >1.34)&(Strain <= 1.49);
z3 = (Strain >1.49);
%Se utiliza polyfit para ajustar una recta: p = [pendiente, intercepto] para UAN
p_z1UAN = polyfit(Strain(z1), Mean_Stress_UAN(z1)*1000,1);
p_z2UAN = polyfit(Strain(z2), Mean_Stress_UAN(z2)*1000,1);
p_z3UAN = polyfit(Strain(z3), Mean_Stress_UAN(z3)*1000,1);
%Extraer las pendientes
p_z1UAN = p_z1UAN(1);
p_z2UAN = p_z2UAN(1);
p_z3UAN = p_z3UAN(1);
fprintf('Módulo Young UAN [KPa] zona 1: %.2f \n', p_z1UAN);
fprintf('Módulo Young UAN [KPa] zona 2: %.2f \n', p_z2UAN);
fprintf('Módulo Young UAN [KPa] zona 3: %.2f \n', p_z3UAN);

%Se utiliza polyfit para ajustar una recta: p = [pendiente, intercepto] para UAFGR
p_z1UAFGR = polyfit(Strain(z1), Mean_Stress_UAFGR(z1)*1000,1);
p_z2UAFGR = polyfit(Strain(z2), Mean_Stress_UAFGR(z2)*1000,1);
p_z3UAFGR = polyfit(Strain(z3), Mean_Stress_UAFGR(z3)*1000,1);
%Extraer las pendientes
p_z1UAFGR = p_z1UAFGR(1);
p_z2UAFGR = p_z2UAFGR(1);
p_z3UAFGR = p_z3UAFGR(1);
fprintf('Módulo Young UAFGR [KPa] zona 1: %.2f \n', p_z1UAFGR);
fprintf('Módulo Young UAFGR [KPa] zona 2: %.2f \n', p_z2UAFGR);
fprintf('Módulo Young UAFGR [KPa] zona 3: %.2f \n', p_z3UAFGR);

%Visualizar el polyfit en las figuras Stress-Strain
figure;hold on;
plot(Strain, Mean_Stress_UAN*1000, 'o-', 'MarkerSize', 6,'Color','r', 'DisplayName', 'Datos UAN');


%%%%%%%%%%%%%%%%%%Continuar este codigo%%%%%%%%%
% Visualización de polyfit para UAN
figure;
hold on;
% Graficar los datos originales de UAN (convertidos a Pa)
plot(Strain, Mean_Stress_UAN*1000, 'ro', 'MarkerSize', 6, 'DisplayName', 'Datos UAN');

% Ajuste y gráfica para la zona 1
x_z1 = Strain(z1);
p_z1 = polyfit(x_z1, Mean_Stress_UAN(z1)*1000, 1); % Ajuste lineal
y_z1 = polyval(p_z1, x_z1);                         % Valores ajustados
plot(x_z1, y_z1, 'r-', 'LineWidth', 2, 'DisplayName', 'Ajuste Zona 1');

% Ajuste y gráfica para la zona 2
x_z2 = Strain(z2);
p_z2 = polyfit(x_z2, Mean_Stress_UAN(z2)*1000, 1);
y_z2 = polyval(p_z2, x_z2);
plot(x_z2, y_z2, 'g-', 'LineWidth', 2, 'DisplayName', 'Ajuste Zona 2');

% Ajuste y gráfica para la zona 3
x_z3 = Strain(z3);
p_z3 = polyfit(x_z3, Mean_Stress_UAN(z3)*1000, 1);
y_z3 = polyval(p_z3, x_z3);
plot(x_z3, y_z3, 'b-', 'LineWidth', 2, 'DisplayName', 'Ajuste Zona 3');

% Etiquetas y leyenda
xlabel('Strain (\lambda)', 'FontSize', 14);
ylabel('Stress (Pa)', 'FontSize', 14);
title('Ajuste Polyfit en Zonas para UAN', 'FontSize', 16);
legend('show');
grid on;
hold off;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




%hold off;
%%%%%%%%%%%Tercera parte final%%%%%%%%%%%%%%%

% Cálculo de los valores p utilizando ttest2 para comparar las muestras UAN y UAFGR
% Asegúrate de tener definidas las variables Strain, Mean_Stress_UAN, Mean_Stress_UAFGR, SE_Stress_UAN, SE_Stress_UAFGR
% Y también las muestras individuales de Stress_UAN y Stress_UAFGR

% Cálculo de valores p para cada punto de Strain
p_values_t_student = zeros(1, length(Strain)); % Inicializar matriz de p-values

for i = 1:length(Strain)
    % Realiza el t-test para comparar los valores de cada muestra en Stress_UAN y Stress_UAFGR
    % 'Vartype', 'unequal' se usa si asumes varianzas desiguales entre los grupos
    [~, p_values_t_student(i)] = ttest2([Stress_UAN1(i), Stress_UAN2(i), Stress_UAN3(i), Stress_UAN4(i), Stress_UAN5(i)], ...
        [Stress_UAFGR1(i), Stress_UAFGR2(i), Stress_UAFGR3(i), Stress_UAFGR4(i), Stress_UAFGR5(i)], ...
        'Vartype', 'unequal');
end

% Gráfico de los promedios con errorbars hacia arriba
figure;
% Error hacia arriba (positivo) para UA Control
errorbar(Strain, Mean_Stress_UAN * 1000, zeros(size(SE_Stress_UAN * 1000)), SE_Stress_UAN * 1000, ...
    'o-', 'MarkerSize', 6, 'Color', 'r');
hold on;

% Error hacia arriba (positivo) para UA FGR
errorbar(Strain, Mean_Stress_UAFGR * 1000, zeros(size(SE_Stress_UAFGR * 1000)), SE_Stress_UAFGR * 1000, ...
    'square-', 'MarkerSize', 6, 'Color', 'b');

% Etiquetas y títulos
xlabel('Stretch $(\lambda)$', 'FontSize', 16, 'Interpreter', 'Latex');
ylabel('Cauchy Stress ($\sigma$, KPa)', 'FontSize', 16, 'Interpreter', 'Latex');
legend({'UA Control', 'UA FGR'}, 'Location', 'northwest');
grid on; ylim([0 250]);

%Mostrar p < 0.01 en el gráfico
for i = 1:length(p_values_t_student)
    if p_values_t_student(i) < 0.01
        %Coloca el símbolo ** donde p < 0.01
        text(Strain(i), max(Mean_Stress_UAN(i), Mean_Stress_UAFGR(i)) * 1000 + 10, '***', ...
            'FontSize', 16, 'Color', 'k', 'HorizontalAlignment', 'center');
    end
end

%Imprimir los valores p para revisión
disp('Valores p para cada punto de Strain:');
disp(p_values_t_student);

%%%%%%%%Análisis ANOVA%%%%%%%%%%%%
% Cálculo de valores p utilizando ANOVA para cada punto de Strain
p_values_ANOVA = zeros(1, length(Strain)); % Inicializar matriz de p-values

for i = 1:length(Strain)
    % Organiza los datos en un solo vector
    group_data = [Stress_UAN1(i), Stress_UAN2(i), Stress_UAN3(i), Stress_UAN4(i), Stress_UAN5(i), ...
        Stress_UAFGR1(i), Stress_UAFGR2(i), Stress_UAFGR3(i), Stress_UAFGR4(i), Stress_UAFGR5(i)];
    
    % Crear el grupo de etiquetas (Control vs FGR)
    group_labels = [repmat({'Control'}, 1, 5), repmat({'FGR'}, 1, 5)];
    % Realizar ANOVA de una vía
    p_values_ANOVA(i) = anova1(group_data, group_labels, 'off');  % 'off' desactiva la visualización del gráfico ANOVA
end

% Imprimir los valores p para revisión
disp('Valores p para cada punto de Strain utilizando ANOVA:');
disp(p_values_ANOVA);

figure;
errorbar(Strain, Mean_Stress_UAN * 1000, zeros(size(SE_Stress_UAN * 1000)), SE_Stress_UAN * 1000, ...
    'o-', 'MarkerSize', 6, 'Color', 'r');
hold on;
errorbar(Strain, Mean_Stress_UAFGR * 1000, zeros(size(SE_Stress_UAFGR * 1000)), SE_Stress_UAFGR * 1000, ...
    'square-', 'MarkerSize', 6, 'Color', 'b');
xlabel('Stretch $(\lambda)$', 'FontSize', 16, 'Interpreter', 'Latex');
ylabel('Cauchy Stress ($\sigma$, KPa)', 'FontSize', 16, 'Interpreter', 'Latex');
legend({'UA Control', 'UA FGR'}, 'Location', 'northwest');
grid on; ylim([0 350]);

% Mostrar significancia basada en los valores p
for i = 1:length(p_values_ANOVA)
    if p_values_ANOVA(i) < 0.001
        % Coloca *** para p < 0.001
        text(Strain(i), max(Mean_Stress_UAN(i), Mean_Stress_UAFGR(i)) * 1000 + 10, '***', ...
            'FontSize', 16, 'Color', 'k', 'HorizontalAlignment', 'center');
    elseif p_values_ANOVA(i) < 0.01
        % Coloca ** para p < 0.01
        text(Strain(i), max(Mean_Stress_UAN(i), Mean_Stress_UAFGR(i)) * 1000 + 10, '**', ...
            'FontSize', 16, 'Color', 'k', 'HorizontalAlignment', 'center');
    elseif p_values_ANOVA(i) < 0.05
        % Coloca * para p < 0.05
        text(Strain(i), max(Mean_Stress_UAN(i), Mean_Stress_UAFGR(i)) * 1000 + 10, '*', ...
            'FontSize', 16, 'Color', 'k', 'HorizontalAlignment', 'center');
    end
end


hold off;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%La función que representa la curva de: Active Stress de Claudio es: f(lam) = -38.31.*lam.^(2)+130.25.*lam-89.5, donde el eje y corresponde a Active Stress [KPa] y el eje x corresponde a Stretch [u.a.]
%Ahora, para generar el primer gráfico de las zonas generadas por distintos módulo de Young, dependen de la función de Claudio y del modelo de Demiray para generar las curvas de Stress vs Strain (Stretch)
lambda = [1:0.1:2]; %Valores de estiramiento
f_lam = -38.31.*lambda.^(2)+130.25.*lambda-89.5; %Función que modela el active stress

yyaxis left;
figure;plot(lambda, f_lam,'ksquare-');yticks(0:5:30);hold on; ylabel('Active Stress [KPa]','FontSize',16,'Interpreter','Latex');xlabel('Stretch ($\lambda$)', 'FontSize', 16, 'Interpreter', 'Latex');
set(gca,'ycolor','k');plot([1.7 1.7], [0 21.2091], 'k--', 'LineWidth', 0.5);%plot([1.8 1.8], [0 20.8256], 'k--', 'LineWidth', 0.5);

%Valores de a y b para Arterias Umbilicales Control con Residual Stress. Datos proporcionados por Andres y Claudio
aUAN = 35.6718E-3;
bUAN = 0.5820;

%Valores de a y b para Arterias Umbilicales FGR con Residual Stress. Datos proporcionados por Andres y Claudio
aUAFGR = 68.7864E-3;
bUAFGR = 0.5865;

%Modelo Demiray para UAN (Naverrete. A, et al. 2022)
DemN = (lambda.^(2)-(1./lambda)).*aUAN.*(exp((bUAN/2).*(lambda.^(2)+(2./lambda)-3)));

%Modelo Demiray para UAFGR (Naverrete. A, et al. 2022)
DemFGR = (lambda.^(2)-(1./lambda)).*aUAFGR.*(exp((bUAFGR/2).*(lambda.^(2)+(2./lambda)-3)));

yyaxis right;
plot(lambda, DemFGR*1000, 'r-o', 'LineWidth',1);ylabel('Passive Stress [KPa]','FontSize',16,'Interpreter','Latex');
set(gca,'ycolor','r');

lambda_fill = lambda(lambda >= 1.4 & lambda <= 1.8);
DemN_fill = DemN(lambda >= 1.4 & lambda <= 1.8) * 1000; %Pa a KPa
x_fill = [lambda_fill, fliplr(lambda_fill)];
y_fill = [DemN_fill, zeros(size(DemN_fill))];
%Rellenar el área bajo la curva en el rango especificado
fill(x_fill, y_fill, 'b', 'FaceAlpha', 0.4, 'EdgeColor', 'none');

lambda_fill2 = lambda(lambda >= 1 & lambda <=1.4);
DemN_fill2 = DemN(lambda >= 1 & lambda <= 1.4) * 1000; %Pa a Kpa
x_fill2 = [lambda_fill2, fliplr(lambda_fill2)];
y_fill2 = [DemN_fill2, zeros(size(DemN_fill2))];
fill(x_fill2, y_fill2, 'r', 'FaceAlpha',0.2,'EdgeColor','none')

%Pendiente: encontrar intersección de DemN y f_lam en el rango [1.8, 2]
lambda_fill3 = lambda(lambda >= 1.8 & lambda <= 2);
DemN_fill3 = DemN(lambda >= 1.8 & lambda <= 2) * 1000; %Pa a Kpa
f_lamfill3 = f_lam(lambda >=1.8 & lambda <= 2);
x_fill3 = [lambda_fill3, fliplr(lambda_fill3)];
y_fill3 = [DemN_fill3, zeros(size(DemN_fill3-f_lamfill3))];
fill(x_fill3, y_fill3, 'r', 'FaceAlpha',0.6,'EdgeColor','none')

% Agregar texto en la zona 1
text(1.26, 20, 'Zone(1)', 'FontSize', 11, 'Color', 'k','Interpreter','Latex');
% Agregar texto en la zona 2
text(1.55, 20, 'Zone(2)', 'FontSize', 11, 'Color', 'k','Interpreter','Latex');
% Agregar texto en la zona 3
text(1.85, 20, 'Zone(3)', 'FontSize', 11, 'Color', 'k','Interpreter','Latex');

hold on
EcRectZ1 = 124.3913.*lambda(1:5)-124.3913;
plot(lambda(1:5), EcRectZ1, 'k-');
EcRectZ2 = 230.3185.*lambda(5:9)-272.6903;
plot(lambda(5:9), EcRectZ2, 'k-');
EcRectZ3 = 407.76.*lambda(9:11)-592.084;
plot(lambda(9:11), EcRectZ3, 'k-');

%%%%%%%%%%%%%Figura 3%%%%%%%%%%%%%%%%%%

%Definir los intervalos de Strain
intervals = [1, 1.4; 1.4, 1.7; 1.7, max(meanlambdaUAN)];
%Inicializar vector para guardar los p-values
p_values_intervals = zeros(1, 3);  % Uno por cada intervalo
%Iterar sobre los intervalos para calcular los p-values
for j = 1:3
    %Extraer los índices de Strain que pertenecen a cada intervalo
    idx = find(meanlambdaUAN >= intervals(j,1) & meanlambdaUAN <= intervals(j,2));
    %Extraer los valores correspondientes de los promedios en ese intervalo
    mean_UAN_intervals = meanForceUAN(idx);
    mean_UAFGR_intervals = meanForceUAFGR(idx);
    %Realizar el t-test entre los promedios en ese intervalo
    [~, p_values_intervals(j)] = ttest2(Mean_Stress_UAN_interval, Mean_Stress_UAFGR_interval, 'Vartype', 'unequal');
end

% Mostrar los p-values calculados
disp('Valores p para cada intervalo de Strain:');
disp('Intervalo 1.0 - 1.3:');
disp(p_values_intervals(1));
disp('Intervalo 1.3 - 1.5:');
disp(p_values_intervals(2));
disp('Intervalo 1.5 en adelante:');
disp(p_values_intervals(3));


%Definir los promedios para cada intervalo
mean_stress_UAN_intervals = [mean_UAN_intervals(1), mean_UAN_intervals(2), mean_UAN_intervals(3)] * 1000;
mean_stress_UAFGR_intervals = [mean_UAFGR_intervals(1), mean_UAFGR_intervals(2), mean_UAFGR_intervals(3)] * 1000;

% Crear los datos para el gráfico de barras
X = categorical({'Zone(1)', 'Zone(2)', 'Zone(3)'});
X = reordercats(X, {'Zone(1)', 'Zone(2)', 'Zone(3)'});
bar_data = [mean_stress_UAN_intervals; mean_stress_UAFGR_intervals];

% Crear el gráfico de barras con separación entre las barras
figure;
b = bar(X, bar_data, 'grouped', 'BarWidth', 0.8);  % Ajustar el 'BarWidth' para separar las barras

% Cambiar los colores de las barras: UA Control (rojo) y UA FGR (azul)
b(1).FaceColor = 'r';  % UA Control en rojo
b(2).FaceColor = 'b';  % UA FGR en azul

% Añadir etiquetas
xlabel('Stretch Intervals','FontSize', 16, 'Interpreter', 'Latex');
ylabel('Young Modulus ($\sigma$, KPa)', 'FontSize', 16,'Interpreter', 'Latex');
ylim([0 200]);


% Definir las desviaciones estándar de los promedios
SE_Stress_UAN_intervals = [SE_Stress_UAN(1), SE_Stress_UAN(2), SE_Stress_UAN(3)] * 1000;
SE_Stress_UAFGR_intervals = [SE_Stress_UAFGR(1), SE_Stress_UAFGR(2), SE_Stress_UAFGR(3)] * 1000;

% Añadir las barras de error a cada barra del gráfico
hold on;

% Error para las barras de UA Control
errorbar(b(1).XEndPoints, mean_stress_UAN_intervals, SE_Stress_UAN_intervals, 'k', 'linestyle', 'none', 'LineWidth', 1.5);
% Error para las barras de UA FGR
errorbar(b(2).XEndPoints, mean_stress_UAFGR_intervals, SE_Stress_UAFGR_intervals, 'k', 'linestyle', 'none', 'LineWidth', 1.5);
legend({'UA Control', 'UA FGR'}, 'Location', 'northwest');
% Mostrar la significancia entre UA Control y UA FGR en cada intervalo
for j = 1:3
    % Posición de las barras (medias) en el eje X
    x1 = b(1).XEndPoints(j); % Barra UA Control
    x2 = b(2).XEndPoints(j); % Barra UA FGR
    
    % Posición en el eje Y donde colocar el símbolo de significancia
    max_height = max(mean_stress_UAN_intervals(j), mean_stress_UAFGR_intervals(j)) + 10;
    
    % Colocar el símbolo de significancia basado en el p-value de ese intervalo
    if p_values_intervals(j) < 0.001
        % Significancia muy alta (p < 0.001) - Usamos '***'
        text(mean([x1, x2]), max_height, '***', 'FontSize', 16, 'HorizontalAlignment', 'center');
    elseif p_values_intervals(j) < 0.01
        % Significancia alta (p < 0.01) - Usamos '**'
        text(mean([x1, x2]), max_height, '**', 'FontSize', 16, 'HorizontalAlignment', 'center');
    elseif p_values_intervals(j) < 0.05
        % Significancia moderada (p < 0.05) - Usamos '*'
        text(mean([x1, x2]), max_height, '*', 'FontSize', 16, 'HorizontalAlignment', 'center');
    end
end

hold off;

%Calculo del \pm
%Definir los tres intervalos de lambda
interval1 = lambda(lambda >= 1 & lambda <= 1.4);
DemN_interval1 = DemN(lambda >= 1 & lambda <= 1.4) * 1000; %Pa a KPa
mean_DemN_interval1 = mean(DemN_interval1); %Promedio para el intervalo 1
SD_DemN_interval1 = std(DemN_interval1); %Desviación estándar para el intervalo 1
interval2 = lambda(lambda > 1.4 & lambda <= 1.8);
DemN_interval2 = DemN(lambda > 1.4 & lambda <= 1.8) * 1000;
mean_DemN_interval2 = mean(DemN_interval2); %Promedio para el intervalo 2
SD_DemN_interval2 = std(DemN_interval2); %Desviación estándar para el intervalo 2
interval3 = lambda(lambda > 1.8 & lambda <= 2);
DemN_interval3 = DemN(lambda > 1.8 & lambda <= 2) * 1000;
mean_DemN_interval3 = mean(DemN_interval3); %Promedio para el intervalo 3
SD_DemN_interval3 = std(DemN_interval3); %Desviación estándar para el intervalo 3

% Mostrar los resultados de los promedios y SD para cada intervalo
disp('Promedio y desviación estándar de DemN*1000 para el intervalo [1, 1.4]:');
disp(['Promedio: ', num2str(mean_DemN_interval1), ', SD: ', num2str(SD_DemN_interval1)]);

disp('Promedio y desviación estándar de DemN*1000 para el intervalo [1.4, 1.8]:');
disp(['Promedio: ', num2str(mean_DemN_interval2), ', SD: ', num2str(SD_DemN_interval2)]);

disp('Promedio y desviación estándar de DemN*1000 para el intervalo [1.8, 2]:');
disp(['Promedio: ', num2str(mean_DemN_interval3), ', SD: ', num2str(SD_DemN_interval3)]);

% Definir los tres intervalos de lambda
interval1 = lambda(lambda >= 1 & lambda <= 1.4);
mean_lambda_interval1 = mean(interval1); %Promedio para el intervalo 1
SD_lambda_interval1 = std(interval1); %Desviación estándar para el intervalo 1
interval2 = lambda(lambda > 1.4 & lambda <= 1.8);
mean_lambda_interval2 = mean(interval2); %Promedio para el intervalo 2
SD_lambda_interval2 = std(interval2); %Desviación estándar para el intervalo 2
interval3 = lambda(lambda > 1.8 & lambda <= 2);
mean_lambda_interval3 = mean(interval3);% Promedio para el intervalo 3
SD_lambda_interval3 = std(interval3);%Desviación estándar para el intervalo 3

% Mostrar los resultados de los promedios y SD para cada intervalo de lambda
disp('Promedio y desviación estándar de lambda para el intervalo [1, 1.4]:');
disp(['Promedio: ', num2str(mean_lambda_interval1), ', SD: ', num2str(SD_lambda_interval1)]);

disp('Promedio y desviación estándar de lambda para el intervalo [1.4, 1.8]:');
disp(['Promedio: ', num2str(mean_lambda_interval2), ', SD: ', num2str(SD_lambda_interval2)]);

disp('Promedio y desviación estándar de lambda para el intervalo [1.8, 2]:');
disp(['Promedio: ', num2str(mean_lambda_interval3), ', SD: ', num2str(SD_lambda_interval3)]);
%%%%%%%%%%%%%%%%%%Figura 3 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

