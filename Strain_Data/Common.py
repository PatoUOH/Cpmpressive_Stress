"""Shared helpers for Figure A and Figure B (matplotlib port of the TikZ originals)."""
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.path import Path
from matplotlib.patches import PathPatch, FancyArrowPatch

def stadium_vertices(cx, cy, half_straight, rx, ry, n=40):
    """Stadium (rectangle + elliptical caps) centred at (cx,cy). half_straight is the half-length
    of the straight segment (x data-units); rx, ry are the cap radii in x- and y- data-units
    RESPECTIVELY (pass them already converted per-axis so the cap looks like a true circle on
    screen even though the x and y axes have very different data-per-inch scales)."""
    theta_left = np.linspace(np.pi/2, 3*np.pi/2, n)
    left_x = cx - half_straight + rx*np.cos(theta_left)
    left_y = cy + ry*np.sin(theta_left)
    theta_right = np.linspace(-np.pi/2, np.pi/2, n)
    right_x = cx + half_straight + rx*np.cos(theta_right)
    right_y = cy + ry*np.sin(theta_right)
    xs = np.concatenate([left_x, right_x, left_x[:1]])
    ys = np.concatenate([left_y, right_y, left_y[:1]])
    return xs, ys

class AxesUnitConverter:
    """Converts a desired physical size (inches) into data-coordinate deltas for THIS axes,
    given its current, fixed position (call after fig.add_axes / ax.set_position, and after
    xlim/ylim are set). This mirrors specifying node size in cm inside a pgfplots 'axis cs' node."""
    def __init__(self, fig, ax):
        self.fig = fig
        self.ax = ax
        self.refresh()

    def refresh(self):
        bbox = self.ax.get_position()  # figure-fraction
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