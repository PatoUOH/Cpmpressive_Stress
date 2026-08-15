"""
Figure B -- Active response: wire myography.
Self-contained: no external files needed besides numpy and matplotlib.
Run from anywhere: python3 FigureB.py
"""
import colorsys
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
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


# Steel-blue ramp used for the three zone rings (light -> base -> dark). The
# schematic itself is unchanged -- still the fixed-size rings with inward
# arrows -- only its horizontal position gets remapped onto the new mm axis.
STEEL_BLUE = COLORS['steel_blue']
ZONE_RING_COLORS = [_adjust_lightness(STEEL_BLUE, 0.45), STEEL_BLUE, _adjust_lightness(STEEL_BLUE, -0.35)]


# ============================================================
# Helpers (previously in common.py, now inlined)
# ============================================================
def stadium_vertices(cx, cy, half_straight, rx, ry, n=40):
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
# Real data (previously computed by compute_data.py into .dat files, now inlined)
# Six wire-myography series. Raw peak isometric force Ta, in mN -- plotted
# directly now (no conversion to active Cauchy stress).
# ============================================================
lambda_2008 = np.array([1.18, 1.3627, 1.5441, 1.6347, 1.7254])
Ta_2008_UA1 = np.array([5.8, 6.29, 6.08, 7.3, 7.99])
Ta_2008_UA2 = np.array([8.58, 9.41, 9.86, 14.09, 8.53])

lambda_2016 = np.array([1.1248, 1.2496, 1.3743, 1.4367, 1.4991])
Ta_2016_UA1 = np.array([4.9, 11.73, 13.8, 13.8, 13.72])
Ta_2016_UA2 = np.array([1.74, 4.16, 5.3, 5.43, 5.37])

lambda_2022 = np.array([1.1814, 1.3627, 1.5441, 1.7254, 1.9067])
Ta_2022_UA1 = np.array([0.33, 0.62, 2.83, 6.42, 5.38])
Ta_2022_UA2 = np.array([0.01, 0.87, 2.02, 4.7, 4.36])

# Reference length L0 per cord: NOT a single fixed pin separation, but the
# full geometric wrap of the wire-myography rig -- the wire runs around two
# needles of diameter d (perimeter contribution (pi+2)*d, i.e. a stadium/
# racetrack shape) plus the initial gap f0 on each side (2*f0). Needle
# diameter d is shared by all cords; f0 (initial pin gap) is set per cord.
NEEDLE_D_MM = 0.04


def l0_from_f0(f0_mm):
    """L0 = (pi+2)*d + 2*f0 -- geometric reference length, in mm."""
    return (np.pi + 2) * NEEDLE_D_MM + 2 * f0_mm


CORD_L0_MM = {
    'Cord 1': l0_from_f0(1.0),  # 2008, f0 = 1.0 mm
    'Cord 2': l0_from_f0(1.5),  # 2016, f0 = 1.5 mm
    'Cord 3': l0_from_f0(1.0),  # 2022, f0 = 1.0 mm
}

SPECIMENS = [
    ('Cord 1 - A', lambda_2008, Ta_2008_UA1, CORD_L0_MM['Cord 1']),
    ('Cord 1 - B', lambda_2008, Ta_2008_UA2, CORD_L0_MM['Cord 1']),
    ('Cord 2 - A', lambda_2016, Ta_2016_UA1, CORD_L0_MM['Cord 2']),
    ('Cord 2 - B', lambda_2016, Ta_2016_UA2, CORD_L0_MM['Cord 2']),
    ('Cord 3 - A', lambda_2022, Ta_2022_UA1, CORD_L0_MM['Cord 3']),
    ('Cord 3 - B', lambda_2022, Ta_2022_UA2, CORD_L0_MM['Cord 3']),
]


def lam_to_mm(lam, L0):
    """Convert a stretch ratio (lambda) to displacement in mm, using the
    cord's own reference length L0: dL_mm = L0 * (lambda - 1)."""
    return L0 * (np.asarray(lam) - 1.0)

# ============================================================
# Figure & axes
# ============================================================
FIG_W, FIG_H = 7.9, 4.3
AX_W_IN, AX_H_IN = 5.197, 3.228
AX_LEFT_IN, AX_BOTTOM_IN = 0.65, 0.55
# FIG_W widened vs. before (6.7 -> 7.9) purely to leave room for the new
# per-specimen legend to the right of the axes; the axes box itself
# (AX_W_IN/AX_H_IN/AX_BOTTOM_IN) is untouched. AX_LEFT_IN grew a bit
# (0.55 -> 0.65) to fit the numeric y tick labels plus the y title, same as
# Figure A.

fig = plt.figure(figsize=(FIG_W, FIG_H))
ax = fig.add_axes([AX_LEFT_IN / FIG_W, AX_BOTTOM_IN / FIG_H, AX_W_IN / FIG_W, AX_H_IN / FIG_H])

# X axis is displacement (mm), converted from the real stretch ratios via
# lam_to_mm(), each cord using its OWN L0 (see CORD_L0_MM above). Since L0 now
# differs per cord, there's no single lambda->mm mapping for the whole axis:
# XMIN is always 0 (lambda=1 => dL=0, regardless of L0); XMAX is the largest
# converted displacement actually reached across all six specimens (Cord 3,
# whose lambda values happen to land on clean 0.4 mm steps at its own L0,
# tops out at ~2.0 mm -- vs. ~0.9 mm under the old single-L0=1mm placeholder).
XMIN = 0.0
XMAX = max(lam_to_mm(lam_i, L0_i).max() for _, lam_i, _, L0_i in SPECIMENS)
YMIN, YMAX = 0.0, 20.0
# Raising this (without touching YMAX) compresses the active curve into a
# smaller fraction of the fixed-height axes box, and frees up vertical room
# (in inches) for the ring schematics above it -- same trick as Figure A.
# Trimmed down from the original 31 now that the KCl/organ-bath schematic is gone.
Y_SCHEMATIC_TOP = 27.0

ax.set_xlim(XMIN, XMAX)
ax.set_ylim(YMIN, Y_SCHEMATIC_TOP)
conv = AxesUnitConverter(fig, ax)

for side in ['top', 'right']:
    ax.spines[side].set_visible(False)
ax.spines['left'].set_bounds(YMIN, YMAX)
ax.spines['bottom'].set_bounds(XMIN, XMAX)

ax.set_xticks(np.linspace(XMIN, XMAX, 6))
ax.set_yticks([0, 5, 10, 15, 20])
# Numeric tick labels shown on request (previously hidden).
ax.set_xticklabels([f'{v:.2f}' for v in np.linspace(XMIN, XMAX, 6)])
ax.set_yticklabels([f'{v:.0f}' for v in [0, 5, 10, 15, 20]])

ax.set_xlabel(r'$\Delta L$ [mm]', fontsize=11)
ax.set_ylabel(r'$F$ [mN]', fontsize=11)
ax.tick_params(labelsize=9)
# Recentre the y-axis title on the visible spine (YMIN-YMAX), not the full
# data range (which extends up to Y_SCHEMATIC_TOP to make room for the ring
# schematics) -- otherwise matplotlib centres it on the whole axes and it
# sits too high. Same fix as Figure A.
y_label_frac = (YMIN + YMAX) / 2.0 / (Y_SCHEMATIC_TOP - YMIN)
# Pushed left of the tick numbers (same fix/value as Figure A).
ax.yaxis.set_label_coords(-0.085, y_label_frac)

# ---------------- vertical centre (data y) of the ring schematics, and the
# height of the "Zone 1/2/3" labels underneath them. ----------------
ring_cy = 23.15
zone_label_y = 20.1  # same physical gap below ring_cy as Figure A's Zone labels

# Shift applied (in lambda-space, then converted to mm) to Zone 2/Zone 3's ring
# positions. (Originally shared with the two dashed threshold lines, which
# have since been removed, but the ring offset itself is unchanged.)
SHARED_X_SHIFT = -0.18

# ---------------- real data: discrete markers per specimen, no fitted/smoothed
# curve. Consecutive points within the SAME specimen are joined by a short
# dotted straight segment only, purely to help the eye follow that one trial's
# order -- never a curve, and never a line crossing between specimens. ----------------
SPECIMEN_MARKERS = ['o', 's', '^', 'D', 'v', 'P']
SPECIMEN_COLORS = COLOR_LIST[:len(SPECIMENS)]

for (name, lam_i, Ta_i, L0_i), marker, color in zip(SPECIMENS, SPECIMEN_MARKERS, SPECIMEN_COLORS):
    mm_i = lam_to_mm(lam_i, L0_i)
    ax.plot(mm_i, Ta_i, ls=':', lw=1.0, color=color, marker=marker, ms=5,
            mfc=color, mec=color, label=name)

ax.legend(loc='upper left', frameon=False, fontsize=8, ncol=1, handletextpad=0.5,
          bbox_to_anchor=(1.02, 1.0), bbox_transform=ax.transAxes, title='Control')

# ============================================================
# Schematic: 3 fixed-length trials, inward (contraction) force arrows
# ============================================================
# The schematic is generic (illustrative Zone 1/2/3 markers, not tied to any
# one cord's real data), so it has no single L0 of its own to convert through
# anymore. Kept at the same RELATIVE position along the axis as before
# (fractions of [XMIN, XMAX], carried over unchanged from when the axis ran
# lambda 1.0-2.0 through the single placeholder L0): Zone 1 at 22.5% of the
# span, Zone 2/3 at 65%/92.5% minus SHARED_X_SHIFT.
ZONE_FRACS = [0.225, 0.65 + SHARED_X_SHIFT, 0.925 + SHARED_X_SHIFT]
zone_lams = [XMIN + f * (XMAX - XMIN) for f in ZONE_FRACS]
zone_names = ['Zone 1', 'Zone 2', 'Zone 3']
# Flattening kept modest across zones (less exaggerated than before).
ring_w_in = [0.36, 0.46, 0.54]
ring_h_in = [0.28, 0.25, 0.22]
# Outline thickness: thicker for Zone 1, decreasing toward Zone 3. Zones 2 & 3
# thinned a bit further on request.
ring_lw = [2.6, 1.5, 0.8]
# Arrow thickness: same for all 3 zones now, matching what Zone 2 had (1.7).
arrow_lw = [1.7, 1.7, 1.7]
pin_r_in = 0.045 * 1.35  # matches Figure A's pin size (RING_SCALE=1.35 there)
pin_edge_margin_in = 0.015

for lam, w_in, h_in, r_lw, a_lw, zname, ring_color in zip(
        zone_lams, ring_w_in, ring_h_in, ring_lw, arrow_lw, zone_names, ZONE_RING_COLORS):
    half_straight = conv.w(max(w_in - h_in, 0) / 2.0)
    rx = conv.w(h_in / 2.0)
    ry = conv.h(h_in / 2.0)
    xs, ys = stadium_vertices(lam, ring_cy, half_straight, rx, ry)
    ax.plot(xs, ys, '-', color=ring_color, lw=r_lw, clip_on=False)

    # Inward (contraction) arrows: 4 per ring now (2 above, 2 below), each
    # HORIZONTAL and pointing toward the ring's centre -- replaces the old
    # pair of side arrows that ran out from the pins.
    ring_half_w = half_straight + rx
    # Tails pushed out past the ring's own edge and tips pulled in close to
    # centre, on request, so the shaft reads clearly instead of looking like
    # a bare triangle -- it's fine if this runs a bit wider than the ring.
    x_outer = 1.2 * ring_half_w   # each arrow's tail (further from centre)
    x_inner = 0.05 * ring_half_w  # each arrow's tip (closer to centre)
    # Small enough that the bottom pair clears the Zone label underneath
    # (Zone 1's ring, the shortest, leaves the least room there).
    y_gap = conv.h(0.09)  # how far above/below the ring's own outline these sit
    top_y = ring_cy + ry + y_gap
    bot_y = ring_cy - ry - y_gap
    for y_level in (top_y, bot_y):
        for sign in (+1, -1):
            x0 = lam + sign * x_outer
            x1 = lam + sign * x_inner
            ax.annotate('', xy=(x1, y_level), xytext=(x0, y_level),
                        arrowprops=dict(arrowstyle='-|>', lw=a_lw, color=ring_color),
                        annotation_clip=False)

    # Pins: grey filled dots at the ends of the ring, same treatment as Figure A.
    pin_offset = half_straight + rx - conv.w(pin_edge_margin_in)
    for sign in (+1, -1):
        pin_x = lam + sign * pin_offset
        pin_ellipse = Ellipse(
            (pin_x, ring_cy), width=2 * conv.w(pin_r_in), height=2 * conv.h(pin_r_in),
            facecolor='0.6', edgecolor='none', zorder=4, clip_on=False)
        ax.add_patch(pin_ellipse)

    ax.text(lam, zone_label_y, zname, ha='center', fontsize=8, clip_on=False)

# ---------------- legend column (upper-left, above Zone 1): pin, then a
# plain reference ring explaining L0 (reference length) and e0 (wall
# thickness), plus a0 as a thick bar -- almost a straight copy of Figure A's
# legend. The offsets below are Figure A's own data-unit constants converted
# to inches (via ITS data_per_in) and re-applied here through this figure's
# own conv.w()/conv.h(); since both figures share the same AX_W_IN/AX_H_IN,
# that reproduces an identical physical layout regardless of the axis's real
# mm range (which now varies with XMAX, itself data-driven -- see above). ----------------
ring_top = ring_cy + max(conv.h(h / 2.0) for h in ring_h_in)

z1_half_straight = conv.w(max(ring_w_in[0] - ring_h_in[0], 0) / 2.0)
z1_rx = conv.w(ring_h_in[0] / 2.0)
z1_ry = conv.h(ring_h_in[0] / 2.0)
z1_half_w = z1_half_straight + z1_rx  # true half-width of the reference ring

legend_x = zone_lams[0] - conv.w(1.0394)  # ~20% of the axis span left of Zone 1

# Pin (same grey dot used at each ring's ends), with its label right below it.
# 0.2148in (Figure A's absolute pin height) put the bottom of this column
# (the a0 bar) below YMAX, overlapping the "20" tick -- raised further still
# for a bit more clearance above it.
legend_pin_y = ring_top + conv.h(0.75)
legend_pin = Ellipse(
    (legend_x, legend_pin_y), width=2 * conv.w(pin_r_in), height=2 * conv.h(pin_r_in),
    facecolor='0.6', edgecolor='none', zorder=4, clip_on=False)
ax.add_patch(legend_pin)
ax.text(legend_x, legend_pin_y - conv.h(0.1391), r'$\Phi$',
        ha='center', va='top', fontsize=8, clip_on=False)

# Reference ring: same outline thickness/colour as Zone 1, no pins -- exists
# purely to explain L0 and e0.
legend_ring_cy = legend_pin_y - conv.h(0.5289)
xs_leg, ys_leg = stadium_vertices(legend_x, legend_ring_cy, z1_half_straight, z1_rx, z1_ry)
ax.plot(xs_leg, ys_leg, '-', color=ZONE_RING_COLORS[0], lw=ring_lw[0], clip_on=False)

# L0: reference length -- double arrow spanning the full reference ring
# (same construction Figure A used for "d"), labelled underneath.
d_y = legend_ring_cy - z1_ry - conv.h(0.0835)
ax.annotate('', xy=(legend_x + z1_half_w, d_y), xytext=(legend_x - z1_half_w, d_y),
            arrowprops=dict(arrowstyle='<->', lw=1.0, color='k'), annotation_clip=False)
ax.text(legend_x, d_y - conv.h(0.0557), r'$L_0$', ha='center', va='top', fontsize=8, clip_on=False)

# e0: wall thickness -- just the label, to the right of the ring, level with
# where the ring outline starts (its top edge).
ax.text(legend_x + z1_half_w + conv.w(0.1039), legend_ring_cy + z1_ry - conv.h(0.0557),
        r'$e_0$', ha='left', va='center', fontsize=8, clip_on=False)

# a0: axial width -- plain thick bar in the same Zone-1 colour, centred under
# the reference ring; its own stroke thickness stands in for a0.
a0_bar_y = d_y - conv.h(0.0557) - conv.h(0.2505)
a0_lw = ring_lw[0] + 0.8
a0_half_w = z1_half_w
ax.plot([legend_x - a0_half_w, legend_x + a0_half_w], [a0_bar_y, a0_bar_y],
        color=ZONE_RING_COLORS[0], lw=a0_lw, solid_capstyle='butt', clip_on=False)
ax.text(legend_x + a0_half_w + conv.w(0.1039), a0_bar_y, r'$a_0$',
        ha='left', va='center', fontsize=8, clip_on=False)

#ax.text(1.0, 20.7,r'Each trial: single fixed pin separation, one KCl challenge, peak isometric force $T_a$ recorded.',ha='left', fontsize=8, style='italic', clip_on=False)

#ax.text(1.0, 27.9,r'Isometric: $\Delta$ fixed per trial, one trial per zone; arrows show generated tension, not motion',ha='left', fontsize=9, clip_on=False)

#ax.text(1.0, 29.6, '(b) Active response: wire myography', ha='left', fontsize=13, fontweight='bold', clip_on=False)

fig.savefig('FigureB_matplotlib.pdf')
fig.savefig('FigureB_matplotlib.png', dpi=300)
print('saved FigureB_matplotlib.pdf / .png')

plt.show()