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
