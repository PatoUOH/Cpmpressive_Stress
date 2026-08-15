"""
Figure A -- Passive response: ring-tensile test.
Reads the 5 individual FGR force-vs-displacement series straight from
Resumen_datos_raw_mod.xlsx (same file/sheet/range as the MATLAB pipeline,
Stress_Strain_Curves_0906.m) -- no longer self-contained, needs that .xlsx
alongside this script.
Run from the Strain_Data folder: python3 Figurea.py
"""
import colorsys
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
import openpyxl
from matplotlib.patches import Ellipse
from PaletteNeutralSoft import COLORS, COLOR_LIST

mpl.rcParams['font.family'] = 'DejaVu Sans'
mpl.rcParams['mathtext.fontset'] = 'dejavusans'


def _adjust_lightness(hex_color, factor):
    """factor>0 lightens toward white, factor<0 darkens toward black (range -1..1)."""
    r, g, b = mpl.colors.to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = l + (1 - l) * factor if factor >= 0 else l * (1 + factor)
    return colorsys.hls_to_rgb(h, l, s)


# Coral ramp used for the three zone rings (light -> base -> dark).
CORAL = COLORS['coral']
ZONE_RING_COLORS = [_adjust_lightness(CORAL, 0.45), CORAL, _adjust_lightness(CORAL, -0.35)]


# ============================================================
# Helpers (previously in common.py, now inlined)
# ============================================================
def stadium_vertices(cx, cy, half_straight, rx, ry, n=40):
    """Stadium (rectangle + elliptical caps) centred at (cx,cy). half_straight is the half-length
    of the straight segment (x data-units); rx, ry are the cap radii in x- and y- data-units
    respectively (already converted per-axis, so the cap looks like a true circle on screen even
    though the x and y axes have very different data-per-inch scales)."""
    theta_left = np.linspace(np.pi / 2, 3 * np.pi / 2, n)
    left_x = cx - half_straight + rx * np.cos(theta_left)
    left_y = cy + ry * np.sin(theta_left)
    theta_right = np.linspace(-np.pi / 2, np.pi / 2, n)
    right_x = cx + half_straight + rx * np.cos(theta_right)
    right_y = cy + ry * np.sin(theta_right)
    xs = np.concatenate([left_x, right_x, left_x[:1]])
    ys = np.concatenate([left_y, right_y, left_y[:1]])
    return xs, ys


class AxesUnitConverter:
    """Converts a desired physical size (inches) into data-coordinate deltas for THIS axes,
    given its current, fixed position. Call .refresh() again if xlim/ylim change afterward."""
    def __init__(self, fig, ax):
        self.fig = fig
        self.ax = ax
        self.refresh()

    def refresh(self):
        bbox = self.ax.get_position()
        fig_w, fig_h = self.fig.get_size_inches()
        self.ax_w_in = bbox.width * fig_w
        self.ax_h_in = bbox.height * fig_h
        x0, x1 = self.ax.get_xlim()
        y0, y1 = self.ax.get_ylim()
        self.data_per_in_x = (x1 - x0) / self.ax_w_in
        self.data_per_in_y = (y1 - y0) / self.ax_h_in

    def w(self, inches):
        return inches * self.data_per_in_x

    def h(self, inches):
        return inches * self.data_per_in_y


# ============================================================
# Real data: 5 individual FGR specimens, read straight from the lab's raw
# Excel file -- same file/sheet/range the MATLAB pipeline reads
# (Stress_Strain_Curves_0906.m: AU_FGR sheet, disp A3:E2226, force G3:K2226).
# Plotted as-is: raw displacement (mm) vs raw force (N), no lambda/sigma
# conversion, no averaging, no model fit.
# ============================================================
FGR_XLSX = 'Resumen_datos_raw_mod.xlsx'

# Reference length used ONLY to re-express the schematic's stretch-ratio
# positions (ring centres, zone thresholds) in mm -- matches L0_fgr in
# Stress_Strain_Curves_0906.m (confirmed, not invented).
L0_FGR_MM = 4.0


def lam_to_mm(lam):
    """Convert a stretch ratio (lambda) to displacement in mm: dL = L0*(lambda-1)."""
    return L0_FGR_MM * (np.asarray(lam) - 1.0)


def _load_fgr_specimens(xlsx_path):
    """Read the 5 individual N force-vs-displacement series. Returns a list
    of (label, displacement_mm, force_N) tuples, one per specimen."""
    wb = openpyxl.load_workbook(xlsx_path, read_only=True, data_only=True)
    ws = wb['AU_N']
    rows = list(ws.iter_rows(min_row=1, max_row=2226, max_col=11, values_only=True))
    # Display label only -- generic "Specimen N", N = column order in the sheet
    # (i.e. the same left-to-right order as disp/force columns A-E / G-K).
    labels = [f'Specimen {i + 1}' for i in range(5)]
    disp = [[] for _ in range(5)]
    force = [[] for _ in range(5)]
    for row in rows[2:]:  # data starts at row 3
        for i in range(5):
            d, f = row[i], row[6 + i]
            if d is not None and f is not None:
                disp[i].append(d)
                force[i].append(f)
    return [(labels[i], np.array(disp[i]), np.array(force[i])) for i in range(5)]


fgr_specimens = _load_fgr_specimens(FGR_XLSX)

# ============================================================
# Figure & axes (fixed position, in inches)
# ============================================================
FIG_W, FIG_H = 7.9, 4.0
AX_W_IN, AX_H_IN = 5.197, 3.228
AX_LEFT_IN, AX_BOTTOM_IN = 0.65, 0.55
# AX_LEFT_IN grew a bit (0.55 -> 0.65, FIG_W +0.1 to compensate) to fit the
# numeric y tick labels plus the y title without the two overlapping.
# FIG_W widened vs. before (6.7 -> 7.8) purely to leave room for the new
# per-specimen legend to the right of the axes; the axes box itself is untouched.

fig = plt.figure(figsize=(FIG_W, FIG_H))
ax = fig.add_axes([AX_LEFT_IN / FIG_W, AX_BOTTOM_IN / FIG_H, AX_W_IN / FIG_W, AX_H_IN / FIG_H])

# X axis is real displacement now (mm), spanning the same lambda=1.0-2.0
# range the schematic was always built around, just expressed in mm.
XMIN, XMAX = lam_to_mm(1.0), lam_to_mm(2.0)
YMIN, YMAX = 0.0, 0.8  # N -- on request; 7_1209 (max ~1.38 N) will clip above this
# Raising this (without touching YMAX) compresses the passive curve into a
# smaller fraction of the fixed-height axes box, and frees up more vertical
# room (in inches) for the ring schematics above it.
# SCALE_Y rescales every inherited "data-unit" constant below (this figure was
# originally tuned at YMAX=300/Y_SCHEMATIC_TOP=580; multiplying by SCALE_Y
# reproduces the exact same physical layout at the new, real YMAX).
SCALE_Y = YMAX / 300.0
Y_SCHEMATIC_TOP = 580.0 * SCALE_Y

ax.set_xlim(XMIN, XMAX)
ax.set_ylim(YMIN, Y_SCHEMATIC_TOP)
conv = AxesUnitConverter(fig, ax)

for side in ['top', 'right']:
    ax.spines[side].set_visible(False)
ax.spines['left'].set_bounds(YMIN, YMAX)
ax.spines['bottom'].set_bounds(XMIN, XMAX)

# Numeric tick labels shown on request (previously hidden).
ax.set_xticks(np.linspace(XMIN, XMAX, 6))
ax.set_yticks(np.linspace(YMIN, YMAX, 5))  # 5 steps -> clean 0.2 N increments at YMAX=0.8
ax.set_xticklabels([f'{v:.1f}' for v in np.linspace(XMIN, XMAX, 6)])
ax.set_yticklabels([f'{v:.2f}' for v in np.linspace(YMIN, YMAX, 5)])

ax.set_xlabel(r'$\Delta L$ [mm]', fontsize=11)
ax.set_ylabel(r'$F$ [N]', fontsize=11)
ax.tick_params(labelsize=9)
# By default matplotlib centres the y-axis title on the whole axes box
# (0 to Y_SCHEMATIC_TOP), which sits far above the actual spine (0 to YMAX)
# since the extra range above YMAX only exists to make room for the ring
# schematics. Recentre it on the visible spine instead.
y_label_frac = (YMIN + YMAX) / 2.0 / (Y_SCHEMATIC_TOP - YMIN)
# Pushed left of the tick numbers (-0.03 overlapped them; -0.11 pushed it off
# the canvas with the old, narrower AX_LEFT_IN) -- -0.085 clears the numbers
# and still fits inside the widened left margin.
ax.yaxis.set_label_coords(-0.085, y_label_frac)

# ---------------- schematic shift amounts ----------------
# ZONE2_X_SHIFT/ZONE3_X_SHIFT move each ring's whole drawing (ring + arrows +
# pins + label). (The dashed threshold lines these used to be aligned with
# have been removed, but the ring offsets themselves are unchanged.)
ZONE2_X_SHIFT = -0.115
ZONE3_X_SHIFT = -0.05

# Vertical centre (data y) of the ring schematics, and the height of the
# "Zone 1/2/3" labels underneath them.
ring_cy = 390.0 * SCALE_Y
zone_label_y = 325.0 * SCALE_Y

# ---------------- real passive curves: 5 individual FGR specimens, raw ----------------
# Control hidden on request -- only FGR shown. No fit, no average, no model:
# each specimen plotted exactly as read from the Excel file.
FGR_SPECIMEN_COLORS = COLOR_LIST[:len(fgr_specimens)]
for (label, disp_i, force_i), color in zip(fgr_specimens, FGR_SPECIMEN_COLORS):
    # Truncated at the first point above YMAX -- default axes clipping only
    # clips to the full ylim (0..Y_SCHEMATIC_TOP), which is taller than YMAX
    # to make room for the ring schematic, so a tall specimen like 7_1209
    # would otherwise draw straight up into the schematic area above.
    above = np.flatnonzero(force_i > YMAX)
    if above.size:
        cutoff = above[0]
        disp_i, force_i = disp_i[:cutoff], force_i[:cutoff]
    ax.plot(disp_i, force_i, '-', lw=1.1, color=color, label=str(label))

ax.legend(loc='upper left', frameon=False, fontsize=8,
          bbox_to_anchor=(1.02, 1.0), bbox_transform=ax.transAxes, title='Control')

# ============================================================
# Schematic: three rings, aligned to zone midpoints, flattening as they open
# ============================================================
zone_lams = [1.225, 1.65, 1.925]
zone_names = ['Zone 1', 'Zone 2', 'Zone 3']
# Ring scale factor: bump this single number to grow/shrink all three rings
# (and, since arrows/pins are computed from ring_w_in/ring_h_in, they scale
# together with it automatically).
RING_SCALE = 1.35
ring_w_in = [0.335 * RING_SCALE, 0.591 * RING_SCALE, 0.787 * RING_SCALE]
ring_h_in = [0.256 * RING_SCALE, 0.217 * RING_SCALE, 0.177 * RING_SCALE]
# Outline thickness per zone: thicker for Zone 1, a little less for Zone 2,
# thinner still for Zone 3. Scaled up a bit less aggressively than the rings
# themselves so the strokes don't look too heavy. Zones 1 & 2 bumped up a
# little further on request. Zone 3 bumped up too so it reads clearly against
# its darker fill, but kept below Zone 2's thickness.
ring_lw = [2.0 * 1.15 + 0.4, 1.5 * 1.15 + 0.3, 1.0 * 1.15 + 0.55]

# Screen position of each schematic (ring + arrows + label) -- kept separate from
# zone_lams (which still reflects the true stretch value, unused now that the
# numeric label was removed, but kept for clarity/future use).
# Zone 2 and Zone 3's whole drawings (ring + arrows + label) are shifted left on
# request (ZONE2_X_SHIFT / ZONE3_X_SHIFT defined above, shared with the window band).
# Shifts are applied in lambda-space, then converted to mm -- so the same
# shift fractions reproduce the same physical layout regardless of L0_FGR_MM.
zone_draw_x = list(zone_lams)
zone_draw_x[1] += ZONE2_X_SHIFT
zone_draw_x[2] += ZONE3_X_SHIFT
zone_draw_x_mm = [lam_to_mm(x) for x in zone_draw_x]

pin_r_in = 0.045 * RING_SCALE  # pin marker radius, in inches
pin_edge_margin_in = 0.015  # how far inside the true ring outline the pin centre sits, in inches

for lam, x_draw, w_in, h_in, lw, zname, ring_color in zip(
        zone_lams, zone_draw_x_mm, ring_w_in, ring_h_in, ring_lw, zone_names, ZONE_RING_COLORS):
    half_straight = conv.w(max(w_in - h_in, 0) / 2.0)
    rx = conv.w(h_in / 2.0)
    ry = conv.h(h_in / 2.0)
    xs, ys = stadium_vertices(x_draw, ring_cy, half_straight, rx, ry)
    ax.plot(xs, ys, '-', color=ring_color, lw=lw, clip_on=False)

    # Single rightward arrow only, kept strictly inside the ring outline: it
    # starts right at the ring's centre and runs out to just shy of the ring
    # wall (never crossing it).
    ring_half_w_in = w_in / 2.0
    arrow_end_in = ring_half_w_in - 0.03
    x1_off = conv.w(arrow_end_in)
    ax.annotate('', xy=(x_draw + x1_off, ring_cy), xytext=(x_draw, ring_cy),
                arrowprops=dict(arrowstyle='-|>', lw=1.3, color='k'),
                annotation_clip=False)

    # Pins: grey filled dots at the ends of the ring, pushed out to just shy of
    # the true outline (the outermost point of each rounded cap at y=ring_cy).
    # Only the left pin gets a black cross the size of its own diameter -- it
    # reads as the pin that's free to move, while the right one (plain dot,
    # matching the arrow's fixed base) stays put.
    pin_offset = half_straight + rx - conv.w(pin_edge_margin_in)
    pin_diam_x = 2 * conv.w(pin_r_in)
    pin_diam_y = 2 * conv.h(pin_r_in)
    for sign in (+1, -1):
        pin_x = x_draw + sign * pin_offset
        pin_ellipse = Ellipse(
            (pin_x, ring_cy), width=pin_diam_x, height=pin_diam_y,
            facecolor='0.6', edgecolor='none', zorder=4, clip_on=False)
        ax.add_patch(pin_ellipse)
        if sign == -1:  # left pin only
            ax.plot([pin_x, pin_x], [ring_cy - pin_diam_y / 2.0, ring_cy + pin_diam_y / 2.0],
                    'k-', lw=1.0, zorder=5, clip_on=False)
            ax.plot([pin_x - pin_diam_x / 2.0, pin_x + pin_diam_x / 2.0], [ring_cy, ring_cy],
                    'k-', lw=1.0, zorder=5, clip_on=False)

    ax.text(x_draw, zone_label_y, zname, ha='center', fontsize=7.5, clip_on=False)

# ---------------- time arrow above the ring row ----------------
ring_top = ring_cy + max(conv.h(h / 2.0) for h in ring_h_in)
time_arrow_y = ring_top + 75.0 * SCALE_Y
time_text_y = time_arrow_y - 18.0 * SCALE_Y

time_arrow_cx = sum(zone_draw_x_mm) / len(zone_draw_x_mm)
time_arrow_half_w = (zone_draw_x_mm[-1] - zone_draw_x_mm[0]) / 2.0 * 0.7
ax.annotate('', xy=(time_arrow_cx + time_arrow_half_w, time_arrow_y),
            xytext=(time_arrow_cx - time_arrow_half_w, time_arrow_y),
            arrowprops=dict(arrowstyle='-|>', lw=1.5, color='red'),
            annotation_clip=False)
ax.text(time_arrow_cx, time_text_y, 'Time (sec)', ha='center', va='top', fontsize=9, clip_on=False)

# ---------------- legend column (upper-left, above Zone 1): pin, then a
# plain reference ring explaining e0 (wall thickness) and d (diameter) ----------------
# Ring geometry re-used from Zone 1's dimensions, just for sizing the reference ring.
z1_half_straight = conv.w(max(ring_w_in[0] - ring_h_in[0], 0) / 2.0)
z1_rx = conv.w(ring_h_in[0] / 2.0)
z1_ry = conv.h(ring_h_in[0] / 2.0)
z1_half_w = z1_half_straight + z1_rx  # true half-width of the ring outline

# Same lambda-space offset as before (-0.20), converted to mm at the end --
# reproduces the same physical position regardless of L0_FGR_MM.
legend_x = lam_to_mm(zone_draw_x[0] - 0.20)

# Pin (same grey dot used at each ring's ends), with its label right below it.
legend_pin_y = time_arrow_y + 65.0 * SCALE_Y
legend_pin = Ellipse(
    (legend_x, legend_pin_y), width=2 * conv.w(pin_r_in), height=2 * conv.h(pin_r_in),
    facecolor='0.6', edgecolor='none', zorder=4, clip_on=False)
ax.add_patch(legend_pin)
ax.text(legend_x, legend_pin_y - 25.0 * SCALE_Y, r'$\Phi$',
        ha='center', va='top', fontsize=8, clip_on=False)

# ---- View 1 (front view): the ring outline, with d (diameter) and e0 (wall
# thickness) marked on it. ----
# Reference ring: same outline thickness as Zone 1, no pins -- exists purely
# to explain e0 and d, so it sits above the ring row instead of cluttering
# the real Zone 1 ring. Given more clearance below the pin on request.
legend_ring_cy = legend_pin_y - 95.0 * SCALE_Y
xs_leg, ys_leg = stadium_vertices(legend_x, legend_ring_cy, z1_half_straight, z1_rx, z1_ry)
# Same coral as Zone 1's ring, since this reference ring stands in for it.
ax.plot(xs_leg, ys_leg, '-', color=ZONE_RING_COLORS[0], lw=ring_lw[0], clip_on=False)

# d: mean diameter -- double arrow spanning the full reference ring, labelled underneath.
d_y = legend_ring_cy - z1_ry - 15.0 * SCALE_Y
ax.annotate('', xy=(legend_x + z1_half_w, d_y), xytext=(legend_x - z1_half_w, d_y),
            arrowprops=dict(arrowstyle='<->', lw=1.0, color='k'), annotation_clip=False)
ax.text(legend_x, d_y - 10.0 * SCALE_Y, r'$d$', ha='center', va='top', fontsize=8, clip_on=False)

# e0: wall thickness -- just the label, to the right of the ring, level with
# where the ring outline starts (its top edge) rather than its vertical centre.
# The "0.02"/"10.0" gaps are the same inch-equivalents as before (0.1039in,
# converted via conv.w/h so they hold regardless of the axis rescale).
ax.text(legend_x + z1_half_w + conv.w(0.1039), legend_ring_cy + z1_ry - 10.0 * SCALE_Y,
        r'$e_0$', ha='left', va='center', fontsize=8, clip_on=False)

# ---- View 2 (edge-on view): a plain thick bar, centred under View 1, in the
# same Zone-1 coral. Its own stroke thickness stands for a0 (axial width) the
# way e0 is read off View 1's stroke. ----
a0_bar_y = (d_y - 10.0 * SCALE_Y) - 45.0 * SCALE_Y
a0_lw = ring_lw[0] + 0.8  # a bit thicker than the ring's outline, on request (linewidth, scale-free)
a0_half_w = z1_half_w  # same length as the ring above it (and as the d span)
ax.plot([legend_x - a0_half_w, legend_x + a0_half_w], [a0_bar_y, a0_bar_y],
        color=ZONE_RING_COLORS[0], lw=a0_lw, solid_capstyle='butt', clip_on=False)
ax.text(legend_x + a0_half_w + conv.w(0.1039), a0_bar_y, r'$a_0$',
        ha='left', va='center', fontsize=8, clip_on=False)

#ax.text(1.0, 326,r'Local curvature and contact geometry change with $\Delta$ $\rightarrow$ $\sigma_p$ is an apparent (average) stress.',ha='left', fontsize=8, style='italic', clip_on=False)

#ax.text(1.0, 432,r'Measured: $a_0$ (axial width), $e_0$ (wall thickness), $d$ (mean diameter), $\phi$(pin diameter)',ha='left', fontsize=9, clip_on=False)

#ax.text(1.0, 458, '(a) Passive response: ring-tensile test',ha='left', fontsize=13, fontweight='bold', clip_on=False)

#plt.show()

fig.savefig('FigureA_matplotlib.pdf')
fig.savefig('FigureA_matplotlib.png', dpi=300)
print('saved FigureA_matplotlib.pdf / .png')
