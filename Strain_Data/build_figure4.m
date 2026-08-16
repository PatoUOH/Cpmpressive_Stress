%% build_figure4.m
% Compone 5 paneles PDF en una figura de 2 filas para publicacion.
% Fila 1: [qPCR_HUVEC encima de qPCR_HUAEC] + Jess_Piezo1
% Fila 2: Jess_Akt_pAkt + Jess_eNOS_peNOS
% Etiquetas de panel: A=HUVEC, B=HUAEC, C=Piezo1, D=Akt, E=eNOS
%
% Requiere Ghostscript (gs) o poppler-utils (pdftoppm) instalado en el
% sistema para rasterizar los PDF fuente. No requiere Image Processing
% Toolbox.

clear; clc; close all;

%% --- Configuracion ---
baseDir = pwd;   % carpeta donde estan los PDF de origen
files.A = fullfile(baseDir, 'qPCR_HUVEC.pdf');
files.B = fullfile(baseDir, 'qPCR_HUAEC.pdf');
files.C = fullfile(baseDir, 'jess_Piezo1.pdf');
files.D = fullfile(baseDir, 'Jess_Akt_pAkt.pdf');
files.E = fullfile(baseDir, 'Jess_eNOS_peNOS.pdf');

dpi    = 600;   % resolucion de rasterizado de cada PDF fuente
LB     = 14;    % pt reservados para la etiqueta encima de cada panel
GUT    = 15;    % separacion horizontal entre paneles
ROWGAP = 25;    % separacion vertical entre fila 1 y fila 2
MARGIN = 15;    % margen exterior
WTOTAL = 540;   % ancho de contenido en puntos (~190 mm, doble columna)

%% --- Rasterizar cada PDF (sin recortar) y medir su relacion de aspecto ---
labels = fieldnames(files);
imgs   = struct();
ratios = struct();
for i = 1:numel(labels)
    key = labels{i};
    [im, r] = local_pdf2im(files.(key), dpi);
    imgs.(key)   = im;
    ratios.(key) = r;
end

r1 = ratios.A; r2 = ratios.B; r3 = ratios.C; r4 = ratios.D; r5 = ratios.E;

% qPCR_HUVEC.pdf trae una leyenda (Control/64kPa) a la derecha que
% qPCR_HUAEC.pdf no tiene, asi que el grafico de barras real ocupa solo
% una fraccion del ancho total de la pagina de HUVEC. chartFracA es esa
% fraccion (medida sobre el PDF vectorial: el grafico termina en x=465.01 pt
% de un ancho de pagina total de 569.71 pt). Se usa para agrandar todo el
% panel A (leyenda incluida) hasta que su grafico de barras quede del
% mismo tamano que el de B, en vez de recortar la leyenda.
chartFracA = 465.00665283203125 / 569.7098388671875;
r1_chart = r1 * chartFracA;   % relacion de aspecto de solo el grafico de barras de A

%% --- Geometria del layout ---
% X = ancho de referencia del grafico de barras (igual para A y B)
k  = 1/r1_chart + 1/r2;
X  = (WTOTAL - GUT - r3*LB) / (r1/r1_chart + r3*k);
H1 = 2*LB + X*k;
Wb = r3 * (H1 - LB);            % ancho columna B (Piezo1), misma altura H1

cellA1_img_h = X / r1_chart;     % alto de la imagen de HUVEC (grafico a escala X)
cellA1_h     = LB + cellA1_img_h;
widthA_full  = cellA1_img_h * r1; % ancho total de HUVEC incl. leyenda (> X)

cellA2_h = LB + X/r2;            % alto celda HUAEC (ancho = X, sin leyenda)

% Fila 2: Akt + eNOS con la misma altura de celda H2
H2 = (WTOTAL - GUT) / (r4 + r5) + LB;
Wa = r4 * (H2 - LB);
We = r5 * (H2 - LB);

PAGE_W = 2*MARGIN + WTOTAL;
PAGE_H = 2*MARGIN + H1 + ROWGAP + H2;

%% --- Crear figura (unidades en puntos) ---
fig = figure('Units', 'points', 'Position', [100 100 PAGE_W PAGE_H], ...
             'Color', 'w');

x0     = MARGIN;
y0_top = MARGIN;   % referencia con origen arriba-izquierda (crece hacia abajo)

% Fila 1 - columna A (HUVEC con leyenda, mas ancho que B)
place_panel(fig, imgs.A, 'A', x0, y0_top, widthA_full, cellA1_h, LB, PAGE_H);
y_c2 = y0_top + cellA1_h;
scaleB = 1.1;  % 10% más grande
Xb = X * scaleB;
place_panel(fig, imgs.B, 'B', x0, y_c2, Xb, LB + Xb/r2, LB, PAGE_H);

% Fila 1 - columna B (Piezo1), empieza despues del panel mas ancho (A)
colB_x0 = x0 + widthA_full + GUT;
place_panel(fig, imgs.C, 'C', colB_x0, y0_top, Wb, H1, LB, PAGE_H);

% Fila 2
y2 = y0_top + H1 + ROWGAP;
akt_x1 = x0 + Wa;
place_panel(fig, imgs.D, 'D', x0, y2, Wa, H2, LB, PAGE_H);

enos_x0 = akt_x1 + GUT;
place_panel(fig, imgs.E, 'E', enos_x0, y2, We, H2, LB, PAGE_H);

%% --- Exportar ---
exportgraphics(fig, fullfile(baseDir, 'Figura4_compuesta.pdf'), 'Resolution', dpi);
exportgraphics(fig, fullfile(baseDir, 'Figura4_compuesta.tiff'), 'Resolution', dpi);

fprintf('Listo: Figura4_compuesta.pdf y Figura4_compuesta.tiff en %s\n', baseDir);

%% ================= Funciones locales =================
function [im, ratio] = local_pdf2im(pdfFile, dpi)
% Rasteriza la primera pagina de un PDF a PNG usando Ghostscript o
% pdftoppm (poppler-utils), y devuelve la imagen y su relacion w/h.
    tmpPng = [tempname() '.png'];
    [statusGs, ~] = system('gs -v');
    if statusGs == 0
        cmd = sprintf(['gs -q -dSAFER -dBATCH -dNOPAUSE -dFirstPage=1 ' ...
            '-dLastPage=1 -sDEVICE=png16m -r%d -sOutputFile="%s" "%s"'], ...
            dpi, tmpPng, pdfFile);
    else
        [statusPp, ~] = system('pdftoppm -v');
        if statusPp ~= 0
            error(['No se encontro Ghostscript (gs) ni pdftoppm en el ' ...
                'sistema. Instala Ghostscript (https://ghostscript.com) ' ...
                'o poppler-utils (pdftoppm) y vuelve a intentar.']);
        end
        outBase = tempname();
        cmd = sprintf('pdftoppm -png -r %d -singlefile "%s" "%s"', ...
            dpi, pdfFile, outBase);
        tmpPng = [outBase '.png'];
    end
    [st, out] = system(cmd);
    if st ~= 0
        error('Fallo al rasterizar %s:\n%s', pdfFile, out);
    end
    im = imread(tmpPng);
    delete(tmpPng);
    [h, w, ~] = size(im);
    ratio = w / h;
end

function place_panel(fig, im, label, x, y_top, w, h, LB, PAGE_H)
% Coloca una imagen dentro de una celda [x, y_top, w, h] (origen
% arriba-izquierda, y_top crece hacia abajo). La banda superior de altura
% LB se sigue reservando (para no alterar la geometria del layout), pero
% ya no se dibuja la etiqueta de panel (A, B, C...) sobre ella.
    y_bottom_axes = PAGE_H - (y_top + h);   % conversion a origen abajo-izquierda de MATLAB
    ax = axes(fig, 'Units', 'points', 'Position', [x, y_bottom_axes, w, h - LB]);
    image(ax, im);
    axis(ax, 'image', 'off');
end
