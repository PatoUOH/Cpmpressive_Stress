"""
Python port of script_FINAL_v2.m -- passive (ring-tensile) + active (wire myography)
biomechanics pipeline for human umbilical arteries.

Requires: numpy, pandas, scipy, statsmodels, matplotlib, openpyxl
    pip install numpy pandas scipy statsmodels matplotlib openpyxl --break-system-packages

Usage:
    python3 pipeline.py
Expects 'Resumen_datos_raw_mod.xlsx' in the same folder as THIS script (resolved via
__file__, not the working directory).
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import ttest_ind, ttest_rel, mannwhitneyu, friedmanchisquare, wilcoxon
from statsmodels.stats.diagnostic import lilliefors

STEEL_BLUE = '#6C91B6'   # active curve (left axis) -- matches palette_neutral_soft.py COLORS['steel_blue']
CORAL = '#DC867F'        # passive curve (right axis) -- matches palette_neutral_soft.py COLORS['coral']
CORAL_ZONE1 = '#EFC9C5'  # lightest -- Zone 1 (elastin-dominated, most compliant)
CORAL_ZONE2 = CORAL      # base coral -- Zone 2 (transition)
CORAL_ZONE3 = '#9A5E59'  # darkest -- Zone 3 (collagen-dominated, stiffest)


def interp_nan_outside(x_query, x_data, y_data):
    x_data = np.asarray(x_data, dtype=float)
    y_data = np.asarray(y_data, dtype=float)
    order = np.argsort(x_data)
    return np.interp(x_query, x_data[order], y_data[order], left=np.nan, right=np.nan)


def demiray_model(a, b, lam):
    return a * (lam ** 2 - 1 / lam) * np.exp((b / 2) * (lam ** 2 + 2 / lam - 3)) * 1000


def read_excel_range(path, sheet, usecols, first_data_row_1indexed, n_rows):
    skiprows = first_data_row_1indexed - 1
    df = pd.read_excel(path, sheet_name=sheet, usecols=usecols,
                        skiprows=skiprows, nrows=n_rows, header=None)
    return df.to_numpy(dtype=float)


L0_ctrl, L0_fgr = 4.0, 4.0
A0_ctrl, A0_fgr = 5.91, 5.64
ARCHIVO = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Resumen_datos_raw_mod.xlsx')


def run_pipeline(archivo=ARCHIVO):
    disp_ind_ctrl = read_excel_range(archivo, 'AU_N', 'A:E', 3, 2790)
    fza_ind_ctrl = read_excel_range(archivo, 'AU_N', 'G:K', 3, 2790)
    disp_ind_fgr = read_excel_range(archivo, 'AU_FGR', 'A:E', 3, 2224)
    fza_ind_fgr = read_excel_range(archivo, 'AU_FGR', 'G:K', 3, 2224)

    lambda_ind_ctrl = (L0_ctrl + disp_ind_ctrl) / L0_ctrl
    lambda_ind_fgr = (L0_fgr + disp_ind_fgr) / L0_fgr
    sigma_ind_ctrl = (fza_ind_ctrl / A0_ctrl) * lambda_ind_ctrl * 1000
    sigma_ind_fgr = (fza_ind_fgr / A0_fgr) * lambda_ind_fgr * 1000

    lmax_ctrl = np.nanmin(np.nanmax(lambda_ind_ctrl, axis=0))
    lmax_fgr = np.nanmin(np.nanmax(lambda_ind_fgr, axis=0))

    Ng = 200  # finer grid -> more points per zone, more stable per-specimen slopes
    grid_ctrl = np.linspace(1.0, lmax_ctrl, Ng)
    grid_fgr = np.linspace(1.0, lmax_fgr, Ng)

    a_ctrl_fijo, b_ctrl_fijo = 0.014, 1.0
    a_fgr_fijo, b_fgr_fijo = 0.020, 1.4

    sigma_grid_ctrl_raw = np.full((Ng, 5), np.nan)
    sigma_grid_fgr_raw = np.full((Ng, 5), np.nan)
    sigma_dem_grid_ctrl = np.full((Ng, 5), np.nan)

    for k in range(5):
        lk = lambda_ind_ctrl[:, k]
        sk = sigma_ind_ctrl[:, k]
        mask = ~np.isnan(lk) & ~np.isnan(sk)
        if mask.sum() > 2:
            sigma_grid_ctrl_raw[:, k] = interp_nan_outside(grid_ctrl, lk[mask], sk[mask])
            sigma_dem_k = demiray_model(a_ctrl_fijo, b_ctrl_fijo, lk[mask])
            sigma_dem_grid_ctrl[:, k] = interp_nan_outside(grid_ctrl, lk[mask], sigma_dem_k)

        lkf = lambda_ind_fgr[:, k]
        skf = sigma_ind_fgr[:, k]
        maskf = ~np.isnan(lkf) & ~np.isnan(skf)
        if maskf.sum() > 2:
            sigma_grid_fgr_raw[:, k] = interp_nan_outside(grid_fgr, lkf[maskf], skf[maskf])

    sd_ctrl_raw = np.nanstd(sigma_grid_ctrl_raw, axis=1, ddof=1)
    sd_fgr_raw = np.nanstd(sigma_grid_fgr_raw, axis=1, ddof=1)
    sigma_sem_raw_ctrl = sd_ctrl_raw / np.sqrt(5)
    sigma_sem_raw_fgr = sd_fgr_raw / np.sqrt(5)

    sigma_dem_ctrl = demiray_model(a_ctrl_fijo, b_ctrl_fijo, grid_ctrl)
    sigma_dem_fgr = demiray_model(a_fgr_fijo, b_fgr_fijo, grid_fgr)

    print('--- Parametros Demiray FIJOS ---')
    print(f'Control: a = {a_ctrl_fijo:.4f}, b = {b_ctrl_fijo:.4f}')
    print(f'FGR:     a = {a_fgr_fijo:.4f}, b = {b_fgr_fijo:.4f}\n')

    lambda_2008 = np.array([1.18, 1.3627, 1.5441, 1.6347, 1.7254])
    Ta_2008_UA1 = np.array([5.8, 6.29, 6.08, 7.3, 7.99])
    Ta_2008_UA2 = np.array([8.58, 9.41, 9.86, 14.09, 8.53])
    lambda_2016 = np.array([1.1248, 1.2496, 1.3743, 1.4367, 1.4991])
    Ta_2016_UA1 = np.array([4.9, 11.73, 13.8, 13.8, 13.72])
    Ta_2016_UA2 = np.array([1.74, 4.16, 5.3, 5.43, 5.37])
    lambda_2022 = np.array([1.1814, 1.3627, 1.5441, 1.7254, 1.9067])
    Ta_2022_UA1 = np.array([0.33, 0.62, 2.83, 6.42, 5.38])
    Ta_2022_UA2 = np.array([0.01, 0.87, 2.02, 4.7, 4.36])

    a0, e0 = 1.5, 0.25
    lambda_act = [lambda_2008, lambda_2008, lambda_2016, lambda_2016, lambda_2022, lambda_2022]
    Ta_act = [Ta_2008_UA1, Ta_2008_UA2, Ta_2016_UA1, Ta_2016_UA2, Ta_2022_UA1, Ta_2022_UA2]

    n_art_act = len(lambda_act)
    coef_act = []
    for lam_i, Ta_i in zip(lambda_act, Ta_act):
        sigma_i = (Ta_i / (2 * a0 * e0)) * lam_i
        coef_act.append(np.polyfit(lam_i, sigma_i, 2))

    lambda_min_act = max(l.min() for l in lambda_act)
    grid_act_ext = np.linspace(lambda_min_act, 2.0, 200)

    sigma_grid_act_ext = np.array([np.polyval(c, grid_act_ext) for c in coef_act])
    sigma_mean_act_ext = sigma_grid_act_ext.mean(axis=0)
    sigma_sd_act_ext = sigma_grid_act_ext.std(axis=0, ddof=1)
    sigma_sem_act_ext = sigma_sd_act_ext / np.sqrt(n_art_act)

    # ---- Figure C: dual axis, active=steel_blue, passive=coral ----
    fig1, ax_left = plt.subplots(figsize=(9, 5.8))
    ax_right = ax_left.twinx()

    # ---- log-space (geometric) SEM bands, point-by-point along the curve ----
    # Same reasoning as the Figure D fix: stress is strictly positive, so a linear
    # +/- SEM band can (and previously did, silently) cross zero. A per-point positivity
    # filter alone is not enough: near the edges of the shared grid, only 1-2 specimens
    # can end up with a valid positive value at a given point, and a sample std on 1
    # point is undefined (this produced the "Degrees of freedom <= 0" warning and the
    # spiky artifacts near the plot edges). A minimum-valid-count guard, with the SEM
    # factor held forward/backward from the nearest reliable point when the local count
    # is too low, fixes this the same way MIN_POINTS_PER_ZONE fixed the zone bars.
    MIN_VALID_FOR_BAND = 3

    def pointwise_log_sem_factor(values_matrix, min_valid=MIN_VALID_FOR_BAND, smooth_window=11):
        """values_matrix: (n_grid, n_specimens). Returns an (n_grid,) multiplicative
        SEM factor (>=1), computed only where >=min_valid positive values exist at
        that grid point, held forward/backward elsewhere so no wild or undefined
        estimate is ever plotted, then lightly smoothed (moving average in log-space)
        purely to remove point-to-point jitter in the estimated spread -- the
        underlying data and the central curve itself are never touched."""
        log_vals = np.where(values_matrix > 0, np.log(np.where(values_matrix > 0, values_matrix, np.nan)), np.nan)
        n_valid = np.sum(~np.isnan(log_vals), axis=1)
        sem_log = np.full(log_vals.shape[0], np.nan)
        ok_idx = np.where(n_valid >= min_valid)[0]
        for idx in ok_idx:
            v = log_vals[idx][~np.isnan(log_vals[idx])]
            sem_log[idx] = v.std(ddof=1) / np.sqrt(len(v))
        sem_log_filled = pd.Series(sem_log).ffill().bfill().to_numpy()
        if smooth_window > 1:
            sem_log_filled = pd.Series(sem_log_filled).rolling(
                smooth_window, center=True, min_periods=1).mean().to_numpy()
        return np.exp(sem_log_filled), n_valid

    sem_factor_act, n_valid_act_pt = pointwise_log_sem_factor(sigma_grid_act_ext.T)
    act_lower = sigma_mean_act_ext / sem_factor_act
    act_upper = sigma_mean_act_ext * sem_factor_act

    sem_factor_ctrl_curve, n_valid_ctrl_pt = pointwise_log_sem_factor(sigma_grid_ctrl_raw)
    ctrl_lower = sigma_dem_ctrl / sem_factor_ctrl_curve
    ctrl_upper = sigma_dem_ctrl * sem_factor_ctrl_curve

    print(f'\nActive band: min specimens/point = {n_valid_act_pt.min()} of {n_art_act}, '
          f'{(n_valid_act_pt < MIN_VALID_FOR_BAND).sum()} of {len(n_valid_act_pt)} points held from nearest neighbor')
    print(f'Passive band: min specimens/point = {n_valid_ctrl_pt.min()} of 5, '
          f'{(n_valid_ctrl_pt < MIN_VALID_FOR_BAND).sum()} of {len(n_valid_ctrl_pt)} points held from nearest neighbor')

    ax_left.fill_between(grid_act_ext, act_lower, act_upper, color=STEEL_BLUE, alpha=0.18, linewidth=0)
    n_markers = 20
    marker_idx = np.round(np.linspace(0, len(grid_act_ext) - 1, n_markers)).astype(int)
    ax_left.plot(grid_act_ext, sigma_mean_act_ext, '-', color=STEEL_BLUE, linewidth=1.4)
    ax_left.plot(grid_act_ext[marker_idx], sigma_mean_act_ext[marker_idx], 's',
                 markerfacecolor='w', markeredgecolor=STEEL_BLUE,
                 label='Active stress ($n{=}6$, polynomial fit, geometric SEM)')
    ax_left.set_ylabel(r'Active stress ($\sigma_{a}$, kPa)', fontsize=14, color=STEEL_BLUE)
    ax_left.tick_params(axis='y', colors=STEEL_BLUE)
    ax_left.spines['left'].set_color(STEEL_BLUE)
    ax_left.set_ylim(0, 25)

    ax_right.fill_between(grid_ctrl, ctrl_lower, ctrl_upper, color=CORAL, alpha=0.20, linewidth=0)
    ax_right.plot(grid_ctrl, sigma_dem_ctrl, '-o', color=CORAL, markerfacecolor='w',
                  markeredgecolor=CORAL, linewidth=1.4, markevery=Ng // 10,
                  label='Passive stress ($n{=}5$, Demiray fit, geometric SEM)')

    ax_left.set_xlim(1.0, lmax_ctrl)
    ax_right.set_ylim(0, 250)
    ax_left.set_xlabel(r'Stretch ($\lambda$, u.a)', fontsize=14)
    ax_right.set_ylabel(r'Passive Stress ($\sigma_{p}$, kPa)', fontsize=14, color=CORAL)
    ax_right.tick_params(axis='y', colors=CORAL)
    ax_right.spines['right'].set_color(CORAL)
    ax_left.axvline(1.451, ls='--', color='k', linewidth=0.5)
    ax_left.axvline(1.845, ls='--', color='k', linewidth=0.5)

    # ---- Mark, on the passive curve, the same lambda where the active curve peaks ----
    # This is the biomechanical anchor for the physiological substrate stiffness choice
    # (e.g. 64 kPa): the stretch at which contractile capacity is maximal, read off the
    # passive stress-stretch relationship at that same lambda.
    idx_peak_act = np.argmax(sigma_mean_act_ext)
    lam_opt = grid_act_ext[idx_peak_act]
    sigma_a_peak = sigma_mean_act_ext[idx_peak_act]
    sigma_p_at_peak = demiray_model(a_ctrl_fijo, b_ctrl_fijo, lam_opt)

    ax_left.plot(lam_opt, sigma_a_peak, marker='*', color=STEEL_BLUE, markeredgecolor='k',
                 markersize=14, zorder=5)
    ax_right.plot(lam_opt, sigma_p_at_peak, marker='*', color=CORAL, markeredgecolor='k',
                  markersize=14, zorder=5)
    ax_left.plot([lam_opt, lam_opt], [sigma_a_peak, 0], ls=':', color='0.4', linewidth=0.9, zorder=1)
    ax_right.annotate(f'$\\lambda_{{opt}}={lam_opt:.2f}$\n$\\sigma_p={sigma_p_at_peak:.0f}$ kPa',
                      xy=(lam_opt, sigma_p_at_peak), xytext=(lam_opt + 0.06, sigma_p_at_peak - 35),
                      fontsize=11, color=CORAL,
                      arrowprops=dict(arrowstyle='-', color=CORAL, lw=0.8))

    print(f'\nActive peak: lambda_opt = {lam_opt:.3f}, sigma_a_peak = {sigma_a_peak:.2f} kPa')
    print(f'Passive stress at that same lambda: sigma_p = {sigma_p_at_peak:.2f} kPa')

    lines_l, labels_l = ax_left.get_legend_handles_labels()
    lines_r, labels_r = ax_right.get_legend_handles_labels()
    ax_left.legend(lines_l + lines_r, labels_l + labels_r, loc='upper left', fontsize=11, frameon=False)

    fig1.tight_layout()
    fig1.savefig('FigureC_active_vs_passive.pdf')
    fig1.savefig('FigureC_active_vs_passive.png', dpi=200)

    # ---- Zone modulus (unchanged logic) ----
    z = [1.0, 1.451, 1.845, 2.0]
    z3_fin_ctrl = min(lmax_ctrl, z[3])
    z3_fin_fgr = min(lmax_fgr, z[3])

    mask1c = (grid_ctrl >= z[0]) & (grid_ctrl <= z[1])
    mask2c = (grid_ctrl >= z[1]) & (grid_ctrl <= z[2])
    mask3c = (grid_ctrl >= z[2]) & (grid_ctrl <= z3_fin_ctrl)
    mask1f = (grid_fgr >= z[0]) & (grid_fgr <= z[1])
    mask2f = (grid_fgr >= z[1]) & (grid_fgr <= z[2])
    mask3f = (grid_fgr >= z[2]) & (grid_fgr <= z3_fin_fgr)

    def slope(x, y):
        return np.polyfit(x, y, 1)[0]

    E_prom_ctrl_fit = np.array([slope(grid_ctrl[mask1c], sigma_dem_ctrl[mask1c]),
                                 slope(grid_ctrl[mask2c], sigma_dem_ctrl[mask2c]),
                                 slope(grid_ctrl[mask3c], sigma_dem_ctrl[mask3c])])
    E_prom_fgr_fit = np.array([slope(grid_fgr[mask1f], sigma_dem_fgr[mask1f]),
                                slope(grid_fgr[mask2f], sigma_dem_fgr[mask2f]),
                                slope(grid_fgr[mask3f], sigma_dem_fgr[mask3f])])

    E_ind_ctrl_fit = np.full((5, 3), np.nan)
    E_ind_fgr_fit = np.full((5, 3), np.nan)
    MIN_POINTS_PER_ZONE = 5  # below this, a per-specimen slope is too noise-sensitive to trust

    for k in range(5):
        if np.any(~np.isnan(sigma_grid_ctrl_raw[:, k])):
            yk = sigma_grid_ctrl_raw[:, k]
            if not np.any(np.isnan(yk[mask1c])) and mask1c.sum() >= MIN_POINTS_PER_ZONE:
                E_ind_ctrl_fit[k, 0] = slope(grid_ctrl[mask1c], yk[mask1c])
            if not np.any(np.isnan(yk[mask2c])) and mask2c.sum() >= MIN_POINTS_PER_ZONE:
                E_ind_ctrl_fit[k, 1] = slope(grid_ctrl[mask2c], yk[mask2c])
            if not np.any(np.isnan(yk[mask3c])) and mask3c.sum() >= MIN_POINTS_PER_ZONE:
                E_ind_ctrl_fit[k, 2] = slope(grid_ctrl[mask3c], yk[mask3c])
        if np.any(~np.isnan(sigma_grid_fgr_raw[:, k])):
            yk = sigma_grid_fgr_raw[:, k]
            if not np.any(np.isnan(yk[mask1f])) and mask1f.sum() >= MIN_POINTS_PER_ZONE:
                E_ind_fgr_fit[k, 0] = slope(grid_fgr[mask1f], yk[mask1f])
            if not np.any(np.isnan(yk[mask2f])) and mask2f.sum() >= MIN_POINTS_PER_ZONE:
                E_ind_fgr_fit[k, 1] = slope(grid_fgr[mask2f], yk[mask2f])
            if not np.any(np.isnan(yk[mask3f])) and mask3f.sum() >= MIN_POINTS_PER_ZONE:
                E_ind_fgr_fit[k, 2] = slope(grid_fgr[mask3f], yk[mask3f])

    print(f'\nPoints per zone (Control grid): Zone1={mask1c.sum()}, Zone2={mask2c.sum()}, Zone3={mask3c.sum()}')
    print(f'Specimens with a valid Zone E (min {MIN_POINTS_PER_ZONE} pts): '
          f'{(~np.isnan(E_ind_ctrl_fit)).sum(axis=0)} of 5, per zone')

    # ------------------------------------------------------------
    # Log-space (geometric) SEM: E is a strictly positive, ratio-scale quantity, so a
    # linear mean +/- SEM can (and here does) cross zero, which is not physically
    # meaningful. Compute the SEM of log(E) per zone and back-transform to get an
    # asymmetric, always-positive error bar around the existing bar height.
    # Only strictly positive per-specimen E values enter the log; a non-positive slope
    # from a noisy narrow-window fit is treated the same way as "too few points":
    # excluded as unreliable, not silently kept.
    # ------------------------------------------------------------
    def log_sem_factor(E_col):
        valid = E_col[~np.isnan(E_col) & (E_col > 0)]
        n_valid = len(valid)
        if n_valid < 2:
            return np.nan, n_valid
        log_vals = np.log(valid)
        sem_log = log_vals.std(ddof=1) / np.sqrt(n_valid)
        return np.exp(sem_log), n_valid  # multiplicative SEM factor (>=1)

    sem_factor_ctrl = np.full(3, np.nan)
    n_valid_ctrl = np.full(3, 0)
    for j in range(3):
        sem_factor_ctrl[j], n_valid_ctrl[j] = log_sem_factor(E_ind_ctrl_fit[:, j])

    err_lower_ctrl = E_prom_ctrl_fit * (1 - 1 / sem_factor_ctrl)
    err_upper_ctrl = E_prom_ctrl_fit * (sem_factor_ctrl - 1)

    print(f'Log-space SEM factor per zone (Control): {sem_factor_ctrl} '
          f'(n_valid used: {n_valid_ctrl})')
    print(f'-> asymmetric bounds: '
          f'{[f"[{E_prom_ctrl_fit[j]-err_lower_ctrl[j]:.1f}, {E_prom_ctrl_fit[j]+err_upper_ctrl[j]:.1f}]" for j in range(3)]}')

    sem_ctrl_fit = np.nanstd(E_ind_ctrl_fit, axis=0, ddof=1) / np.sqrt(np.sum(~np.isnan(E_ind_ctrl_fit), axis=0))
    sem_fgr_fit = np.nanstd(E_ind_fgr_fit, axis=0, ddof=1) / np.sqrt(np.sum(~np.isnan(E_ind_fgr_fit), axis=0))

    pvals_fit = np.full(3, np.nan)
    tnames_fit = [''] * 3
    for j in range(3):
        xc = E_ind_ctrl_fit[:, j][~np.isnan(E_ind_ctrl_fit[:, j])]
        xf = E_ind_fgr_fit[:, j][~np.isnan(E_ind_fgr_fit[:, j])]
        if len(xc) >= 4 and len(xf) >= 4:
            _, pnc = lilliefors(xc, dist='norm')
            _, pnf = lilliefors(xf, dist='norm')
            if pnc > 0.05 and pnf > 0.05:
                _, pvals_fit[j] = ttest_ind(xc, xf, equal_var=False)
                tnames_fit[j] = 't-Welch'
            else:
                _, pvals_fit[j] = mannwhitneyu(xc, xf, alternative='two-sided')
                tnames_fit[j] = 'Mann-Whitney'
        else:
            _, pvals_fit[j] = mannwhitneyu(xc, xf, alternative='two-sided')
            tnames_fit[j] = 'Mann-Whitney (N<4)'

    def sig_symbol(p):
        if p < 0.001:
            return '***'
        if p < 0.01:
            return '**'
        if p < 0.05:
            return '*'
        return 'ns'

    sig_fit = [sig_symbol(p) for p in pvals_fit]

    complete = ~np.any(np.isnan(E_ind_ctrl_fit), axis=1)
    n_complete = complete.sum()
    E_complete = E_ind_ctrl_fit[complete, :]

    friedman_stat, friedman_p = (np.nan, np.nan)
    if n_complete >= 3:
        friedman_stat, friedman_p = friedmanchisquare(E_complete[:, 0], E_complete[:, 1], E_complete[:, 2])

    zone_pairs = [(0, 1, 'Zone 1 vs Zone 2'), (1, 2, 'Zone 2 vs Zone 3'), (0, 2, 'Zone 1 vs Zone 3')]
    zone_pair_p_raw = {}
    zone_pair_p_bonf = {}
    zone_pair_test = {}
    log_E_complete = np.log(E_complete) if E_complete.size and np.all(E_complete > 0) else None

    for i, j, label in zone_pairs:
        p_raw, test_name = np.nan, 'n/a'
        if n_complete >= 4 and log_E_complete is not None:
            diffs = log_E_complete[:, i] - log_E_complete[:, j]
            try:
                _, p_norm = lilliefors(diffs, dist='norm')
            except Exception:
                p_norm = 0.0
            if p_norm > 0.05:
                _, p_raw = ttest_rel(log_E_complete[:, i], log_E_complete[:, j])
                test_name = 'paired t (log)'
            else:
                try:
                    _, p_raw = wilcoxon(E_complete[:, i], E_complete[:, j])
                except ValueError:
                    p_raw = np.nan
                test_name = 'Wilcoxon'
        elif n_complete >= 2:
            try:
                _, p_raw = wilcoxon(E_complete[:, i], E_complete[:, j])
                test_name = 'Wilcoxon (N<4)'
            except ValueError:
                p_raw = np.nan
        zone_pair_p_raw[label] = p_raw
        zone_pair_p_bonf[label] = min(p_raw * 3, 1.0) if not np.isnan(p_raw) else np.nan
        zone_pair_test[label] = test_name

    zone_pair_sig = {label: sig_symbol(p) if not np.isnan(p) else 'n/a'
                      for label, p in zone_pair_p_bonf.items()}

    print(f'\n--- Zone-vs-zone comparison, Control only (paired, n={n_complete} complete specimens) ---')
    print(f'Friedman omnibus: chi2 = {friedman_stat:.3f}, p = {friedman_p:.4f}')
    for label in zone_pair_p_bonf:
        print(f'{label}: {zone_pair_test[label]}, p_raw = {zone_pair_p_raw[label]:.4f}, '
              f'p_bonferroni(x3) = {zone_pair_p_bonf[label]:.4f} ({zone_pair_sig[label]})')

    # ---- Figure D: Control only. Per prior decision (opcion 1), report ONLY the
    # Friedman omnibus result -- pairwise Wilcoxon signed-rank at n=5 cannot reach
    # p<0.05 even uncorrected (exact floor 2/32=0.0625, 0.1875 after Bonferroni x3),
    # so no pairwise brackets are drawn to avoid an apparent contradiction with a
    # significant omnibus. The increasing trend is described qualitatively in text,
    # supported by this single p-value.
    # ------------------------------------------------------------
    fig2, ax2 = plt.subplots(figsize=(7, 5.5))
    x = np.array([1, 2, 3])
    ancho = 0.5

    ax2.bar(x, E_prom_ctrl_fit, ancho, color=[CORAL_ZONE1, CORAL_ZONE2, CORAL_ZONE3],
            edgecolor='k', label='UA Control')
    ax2.errorbar(x, E_prom_ctrl_fit, yerr=[err_lower_ctrl, err_upper_ctrl],
                 fmt='k.', linewidth=1.5, capsize=8)

    bar_tops = E_prom_ctrl_fit + err_upper_ctrl

    ax2.set_xticks(x)
    ax2.set_xticklabels(['Zone 1', 'Zone 2', 'Zone 3'])
    ax2.set_xlabel('Stretch Intervals', fontsize=13)
    ax2.set_ylabel(r'Stretch Modulus ($E$, kPa)', fontsize=13)

    # ---- pairwise brackets: paired t-test (log-space) if differences are plausibly
    # normal (Lilliefors), else Wilcoxon signed-rank -- Bonferroni x3 -- see console
    # output for which test was used per pair ----
    gap1 = 0.08 * bar_tops.max()
    y_z12 = max(bar_tops[0], bar_tops[1]) + gap1
    y_z23 = max(bar_tops[1], bar_tops[2]) + gap1
    y_z13 = max(y_z12, y_z23) + gap1 * 1.8

    def draw_bracket(x1, x2, y, label):
        ax2.plot([x1, x1, x2, x2], [y - gap1 * 0.25, y, y, y - gap1 * 0.25], 'k-', linewidth=1)
        fs = 11 if label in ('ns', 'n/a') else 15
        ax2.text((x1 + x2) / 2, y + gap1 * 0.15, label, fontsize=fs, ha='center', fontweight='bold')

    draw_bracket(x[0], x[1], y_z12, zone_pair_sig['Zone 1 vs Zone 2'])
    draw_bracket(x[1], x[2], y_z23, zone_pair_sig['Zone 2 vs Zone 3'])
    draw_bracket(x[0], x[2], y_z13, zone_pair_sig['Zone 1 vs Zone 3'])
    y_top = np.nanmax([y_z13, np.nanmax(bar_tops)]) if not np.all(np.isnan(bar_tops)) else 1.0
    if np.isnan(y_top):
        y_top = np.nanmax(bar_tops[~np.isnan(bar_tops)]) if np.any(~np.isnan(bar_tops)) else 1.0
    ax2.set_ylim(0, y_top + gap1 * 2.5)

    friedman_p_str = f'{friedman_p:.3f}' if not np.isnan(friedman_p) else 'n/a'
    str_box = (
        f'Zone modulus ($E$, kPa), $n$={n_complete}\n'
        f'  Zone 1: {E_prom_ctrl_fit[0]:.1f} [{E_prom_ctrl_fit[0]-err_lower_ctrl[0]:.1f}, {E_prom_ctrl_fit[0]+err_upper_ctrl[0]:.1f}]\n'
        f'  Zone 2: {E_prom_ctrl_fit[1]:.1f} [{E_prom_ctrl_fit[1]-err_lower_ctrl[1]:.1f}, {E_prom_ctrl_fit[1]+err_upper_ctrl[1]:.1f}]\n'
        f'  Zone 3: {E_prom_ctrl_fit[2]:.1f} [{E_prom_ctrl_fit[2]-err_lower_ctrl[2]:.1f}, {E_prom_ctrl_fit[2]+err_upper_ctrl[2]:.1f}]\n'
        f'  Friedman omnibus: $p$={friedman_p_str}'
    )
    ax2.text(0.03, 0.80, str_box, transform=ax2.transAxes, fontsize=9.5,
             bbox=dict(facecolor=(0.98, 0.98, 0.98), edgecolor='k'), verticalalignment='top')
    


    fig2.tight_layout()
    fig2.savefig('FigureD_zone_modulus.pdf')
    fig2.savefig('FigureD_zone_modulus.png', dpi=200)

    lam1, lam2 = 1.55, 1.75

    def dsigma_demiray(lam, a, b):
        return a * ((2 * lam + 1 / lam ** 2) + (lam ** 2 - 1 / lam) * b * (lam - 1 / lam ** 2)) \
               * np.exp((b / 2) * (lam ** 2 + 2 / lam - 3)) * 1000

    sigma1_ctrl = demiray_model(a_ctrl_fijo, b_ctrl_fijo, lam1)
    sigma2_ctrl = demiray_model(a_ctrl_fijo, b_ctrl_fijo, lam2)
    E_secante_ctrl = (sigma2_ctrl - sigma1_ctrl) / (lam2 - lam1)

    sigma1_fgr = demiray_model(a_fgr_fijo, b_fgr_fijo, lam1)
    sigma2_fgr = demiray_model(a_fgr_fijo, b_fgr_fijo, lam2)
    E_secante_fgr = (sigma2_fgr - sigma1_fgr) / (lam2 - lam1)

    lam_fino = np.linspace(lam1, lam2, 200)
    E_tangente_ctrl = dsigma_demiray(lam_fino, a_ctrl_fijo, b_ctrl_fijo).mean()
    E_tangente_fgr = dsigma_demiray(lam_fino, a_fgr_fijo, b_fgr_fijo).mean()

    print(f"\n========== MODULO ELASTICO DEMIRAY [lambda = {lam1:.2f} a {lam2:.2f}] ==========")
    print(f"{'Grupo':<12}{'E secante':>15}{'E tangente (avg)':>20}")
    print(f"{'Control':<12}{E_secante_ctrl:>15.3f}{E_tangente_ctrl:>20.3f}")
    print(f"{'FGR':<12}{E_secante_fgr:>15.3f}{E_tangente_fgr:>20.3f}")
    print("(unidades: kPa)")
    print("=" * 74)

    return dict(grid_ctrl=grid_ctrl, grid_fgr=grid_fgr, sigma_dem_ctrl=sigma_dem_ctrl,
                sigma_dem_fgr=sigma_dem_fgr, E_prom_ctrl_fit=E_prom_ctrl_fit,
                E_prom_fgr_fit=E_prom_fgr_fit, pvals_fit=pvals_fit, tnames_fit=tnames_fit,
                sig_fit=sig_fit)


if __name__ == '__main__':
    results = run_pipeline()
    print('\nSaved: FigureC_active_vs_passive.pdf/.png, FigureD_zone_modulus.pdf/.png')
    plt.show()