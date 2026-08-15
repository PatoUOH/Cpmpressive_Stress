"""
Neutral Soft palette -- extracted from the user's reference image.
8 named categorical colors + 1 sequential colormap + 1 diverging colormap.

Usage:
    from palette_neutral_soft import COLORS, palette_seq, palette_div

    COLORS['steel_blue']       # '#6C91B6'
    plt.plot(x, y, color=COLORS['coral'])
    plt.imshow(data, cmap=palette_seq)
    plt.imshow(diff_data, cmap=palette_div)
"""
from matplotlib.colors import LinearSegmentedColormap, ListedColormap
import matplotlib as mpl

# ---------------------------------------------------------------
# 8 named categorical colors
# ---------------------------------------------------------------
COLORS = {
    'steel_blue': '#6C91B6',
    'teal':       '#7CB4B4',
    'sage':       '#90AE96',
    'marigold':   '#F1C77A',
    'apricot':    '#F0AB6B',
    'coral':      '#DC867F',
    'lavender':   '#A28FC5',
    'taupe':      '#C0B1A6',
}

# Ordered list, for cycling through categories (e.g. plt.rcParams['axes.prop_cycle'])
COLOR_ORDER = ['steel_blue', 'teal', 'sage', 'marigold', 'apricot', 'coral', 'lavender', 'taupe']
COLOR_LIST = [COLORS[name] for name in COLOR_ORDER]

# Discrete colormap built from the 8 categorical colors (for e.g. 8-level categorical imshow)
palette_categorical = ListedColormap(COLOR_LIST, name='neutral_soft_categorical')

# ---------------------------------------------------------------
# Sequential colormap (light -> dark blue), sampled from the gradient bar
# ---------------------------------------------------------------
_seq_stops = [
    '#DBE9F5', '#D1E2F2', '#BED5EC', '#A8C6E4', '#8DB2D9',
    '#7099C9', '#527EB5', '#3966A2', '#25508F',
]
palette_seq = LinearSegmentedColormap.from_list('neutral_soft_seq', _seq_stops, N=256)

# ---------------------------------------------------------------
# Diverging colormap (blue -> white -> orange/red), sampled from the gradient bar
# ---------------------------------------------------------------
_div_stops = [
    '#4678B7', '#7CA5D4', '#AAC9E8', '#D3E3F2', '#F7F5F3',
    '#FDE3CB', '#FABD95', '#EA8C68', '#C65350',
]
palette_div = LinearSegmentedColormap.from_list('neutral_soft_div', _div_stops, N=256)

# ---------------------------------------------------------------
# Optional: register so plt.get_cmap('neutral_soft_seq') etc. work everywhere,
# and set the 8 categorical colors as the default color cycle.
# ---------------------------------------------------------------
def register(set_as_default_cycle=False):
    for name, cmap in [('neutral_soft_seq', palette_seq),
                        ('neutral_soft_div', palette_div),
                        ('neutral_soft_categorical', palette_categorical)]:
        try:
            mpl.colormaps.register(cmap, name=name)
        except ValueError:
            pass  # already registered (e.g. re-running in the same session)
    if set_as_default_cycle:
        mpl.rcParams['axes.prop_cycle'] = mpl.cycler(color=COLOR_LIST)


if __name__ == '__main__':
    # Quick self-check / preview
    import matplotlib.pyplot as plt
    import numpy as np

    register()
    fig, axes = plt.subplots(3, 1, figsize=(7, 4.2), height_ratios=[1, 1, 1])

    for i, name in enumerate(COLOR_ORDER):
        axes[0].add_patch(plt.Rectangle((i, 0), 0.9, 1, color=COLORS[name]))
        axes[0].text(i + 0.45, -0.25, name, ha='center', fontsize=7)
    axes[0].set_xlim(0, 8); axes[0].set_ylim(-0.4, 1.1); axes[0].axis('off')
    axes[0].set_title('8 named colors', fontsize=9, loc='left')

    grad = np.linspace(0, 1, 256).reshape(1, -1)
    axes[1].imshow(grad, aspect='auto', cmap=palette_seq)
    axes[1].axis('off'); axes[1].set_title('palette_seq', fontsize=9, loc='left')

    axes[2].imshow(grad, aspect='auto', cmap=palette_div)
    axes[2].axis('off'); axes[2].set_title('palette_div', fontsize=9, loc='left')

    fig.tight_layout()
    fig.savefig('palette_preview.png', dpi=150)
    print('Preview saved to palette_preview.png')
    print(COLORS)