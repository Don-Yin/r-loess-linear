"""Standard figures selected by LOESS_FIGURE_EXPERIMENT."""
from __future__ import annotations

import json
import os
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.font_manager import FontProperties
from matplotlib.image import imread
from matplotlib.legend_handler import HandlerTuple
from matplotlib.lines import Line2D
from matplotlib.offsetbox import AnnotationBbox, OffsetImage
from matplotlib.ticker import FuncFormatter, MaxNLocator
from matplotlib.transforms import offset_copy
from python_plotting_convention import (  # pyright: ignore[reportMissingImports]
    apply_style,
    figure_size,
    place_labels,
    tag_artist,
)
from result_data import (
    BEFORE_RED,
    DEFAULT_BLUE,
    DROPPED_PURPLE,
    KEPT_GREEN,
    LOGO_PT,
    R_LOGO,
    ROOT,
    X_PAD,
    Y_PAD,
    ZOOM_COLOUR,
    _LogoHandler,
    _marker_styles,
    _visible_box,
    read_csv,
    source_record,
)
from slice_zoom import (  # pyright: ignore[reportMissingImports]
    WIDTHS,
    box_outline,
    halo,
    link,
)

ZOOM_SHARE = 0.25
COINCIDENT_SD = 2.0
COINCIDENT_CLEARANCE_PT = 0.8
R_GREY = "#b4bcc4"
EXPERIMENTS = {"000": "nov6_cache", "001": "actual_vertices", "002": "baseline_prototype", "003": "reductions",
               "004": "worst_case", "005": "package_source", "006": "sparse_retention", "007": "shorter_source", "008": "python_skmisc"}


def _number(value, _=None):
    return f"{value:,.3f}".rstrip("0").rstrip(".").replace("-", "\N{MINUS SIGN}")


def _style(digit, label, color=DEFAULT_BLUE, filled=True, name=None):
    return {"digit": digit, "label": label, "color": color, "filled": filled, "name": name}


def _read_manifest(path):
    try:
        return json.loads((ROOT / path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read {path}: {error}") from error


def _series(rows, style, *, identity="identical_to_r"):
    try:
        ordered = sorted(rows, key=lambda row: int(row["N"]))
        n = np.array([int(row["N"]) for row in ordered])
        seconds = np.array([float(row["median_seconds"]) for row in ordered])
        requested = np.array([float(row["requested_bytes"]) for row in ordered])
        spread = np.array([np.nan if row["sd_seconds"] == "NA" else float(row["sd_seconds"]) for row in ordered])
    except (TypeError, ValueError) as error:
        raise ValueError(f"invalid measured numbers for {style['label']}: {rows}") from error
    if not len(n) or len(set(n)) != len(n):
        raise ValueError(f"missing or duplicate N for {style['label']}")
    if any(row[identity] != "TRUE" for row in ordered) or not np.all(np.isfinite(seconds) & (seconds > 0) & np.isfinite(requested) & (requested > 0)):
        raise ValueError(f"invalid or nonidentical observations for {style['label']}: {rows}")
    return {"n": n, "seconds": seconds, "bytes": requested, "sd_seconds": spread, "style": style}


def _data(experiment):
    folder = f"experiments/exp_{experiment}_{EXPERIMENTS[experiment]}"
    table = f"{folder}/.results/tables/growth.csv"
    rows = read_csv(table)
    records = [source_record(table, ["build", "N", "median_seconds", "requested_bytes"])]
    missing = [row for row in rows if row.get("status", "ok") != "ok"]
    if experiment == "008":
        rows = [row for row in rows if row["status"] == "ok"]
        reference = _series([row for row in rows if row["build"] == "unpatched"], _style("", ""), identity="identical_to_reference")
        styles = {"cache": _style("8", "cache", BEFORE_RED, False), "actual": _style("8", "+ actual vertices")}
        logo = imread(ROOT / "docs/assets/python-logo.png")
        lines_path = f"{folder}/.results/tables/growth-source-lines.csv"
        source_rows = read_csv(lines_path, integer_columns=("reference_lines", "added", "removed"))
        total = source_rows[0]["reference_lines"]
        records.append(source_record(lines_path, ["variant", "reference_lines", "added", "removed"]))
        builds = [_series([row for row in rows if row["build"] == name], style, identity="identical_to_reference")
                  for name, style in styles.items()]
    else:
        ref_path = "experiments/shared/artifacts/r-growth/growth.csv"
        manifest_path = "experiments/shared/artifacts/r-growth/manifest.json"
        manifest = _read_manifest(manifest_path)
        reference = _series(read_csv(ref_path), _style("", ""))
        logo, total = R_LOGO, manifest["reference_source_lines"]
        records += [source_record(ref_path, ["N", "median_seconds", "requested_bytes"]), source_record(manifest_path, ["reference_source_lines", "input"])]
        lines_path = f"{folder}/.results/tables/lines-against-r.csv"
        source_rows = [row for row in read_csv(lines_path, integer_columns=("added", "removed")) if row["part"] == "source"]
        records.append(source_record(lines_path, ["variant", "part", "added", "removed"]))
        styles = {
            "000": {"cache": _style("0", "cache")}, "001": {"actual_vertices": _style("1", "actual vertices")},
            "002": {"prototype": _style("2", "prototype")}, "005": {"package": _style("P", "this package")},
            "006": {"sparse": _style("6", "sparse retention")},
            "007": {"deletions_only": _style("7", "deletions"), "reduced": _style("7", "+ reductions", BEFORE_RED, False)},
            "004": {"cap-67108864": _style("4", "64 MiB"), "cap-65536": _style("4", "cap", "#ee7733", name="64 KiB"),
                    "cap-0": _style("4", "cap", "#ee7733", name="0")},
        }.get(experiment)
        if experiment == "003":
            variants_path = f"{folder}/src/variants.csv"
            variants = read_csv(variants_path)
            styles = {row["name"]: _style("3", "7 kept" if row["verdict"] == "kept" else "dropped",
                       KEPT_GREEN if row["verdict"] == "kept" else DROPPED_PURPLE, row["verdict"] == "kept") for row in variants}
            records.append(source_record(variants_path, ["name", "verdict"]))
        if styles is None:
            raise ValueError(f"no build styles for experiment {experiment}")
        if {row["build"] for row in rows} != set(styles):
            raise ValueError(f"{table}: builds do not match the experiment's result figure")
        builds = [_series([row for row in rows if row["build"] == name], style) for name, style in styles.items()]
    if any(build["n"].tolist() != reference["n"].tolist() for build in builds):
        raise ValueError(f"{table}: incomplete standard N grid")
    for build, name in zip(builds, styles, strict=True):
        variant = "prototype" if experiment == "004" else name
        found = [row for row in source_rows if row["variant"] == variant]
        if len(found) != 1:
            raise ValueError(f"{lines_path}: expected one source count for {variant}")
        build["source"] = {"variant": name, "added": found[0]["added"], "removed": found[0]["removed"]}
    return reference, builds, logo, total, records, missing


def _logo_at(ax, xy, logo, dy=0):
    artist = AnnotationBbox(OffsetImage(logo, zoom=LOGO_PT / logo.shape[0]), xy, xybox=(0, dy),
                            boxcoords="offset points", frameon=False, pad=0, zorder=5)
    ax.add_artist(artist)
    return artist


def _marker_at(ax, xy, style, dy=0, nested=False):
    transform = offset_copy(ax.transData, fig=ax.figure, y=dy, units="points")
    marks = _marker_styles(style)
    if nested:
        marks = [{**marks[0], "markersize": 12.5, "markerfacecolor": "none"}]
    for mark in marks:
        ax.plot(*xy, linestyle="none", transform=transform, zorder=4, **mark)


def _axes(ax, top, nmax):
    ax.set(xlim=(-X_PAD * nmax, nmax * 1.12), ylim=(-Y_PAD * top, top))
    ax.spines[["top", "right"]].set_visible(False)
    ax.xaxis.set_major_locator(MaxNLocator(4, min_n_ticks=3))
    ax.yaxis.set_major_locator(MaxNLocator(4, min_n_ticks=3))
    ax.xaxis.set_major_formatter(FuncFormatter(_number))
    ax.yaxis.set_major_formatter(FuncFormatter(_number))
    ax.tick_params(labelsize=9)
    ax.grid(color="#d9dfe4", linestyle=":", linewidth=0.6)
    ax.set_axisbelow(True)
    tag_artist(ax, semantic_role="body")


def _coincident(left, right, memory_tolerance=0):
    same_bytes = left["bytes"][-1] == right["bytes"][-1] and np.all(np.abs(left["bytes"] - right["bytes"]) <= memory_tolerance)
    noise = COINCIDENT_SD * np.hypot(left["sd_seconds"], right["sd_seconds"])
    return same_bytes and np.all(np.abs(left["seconds"] - right["seconds"]) <= noise)


def _groups(builds, key, range_builds, memory_tolerance=0):
    groups = []
    for label in dict.fromkeys(build["style"]["label"] for build in builds):
        selected = [build for build in builds if build["style"]["label"] == label]
        if range_builds:
            groups.append((selected[0], np.stack([build[key] for build in selected])))
            continue
        pending = selected.copy()
        while pending:
            build = pending.pop(0)
            coincident = [other for other in pending if _coincident(build, other, memory_tolerance)]
            pending = [other for other in pending if not any(other is match for match in coincident)]
            if coincident:
                names = [item["style"]["name"] for item in [build, *coincident]]
                build = {**build, "style": {**build["style"], "name": " / ".join(filter(None, names))}}
            groups.append((build, build[key][None, :]))
    return groups


def _pair(figure, bottom, reference, builds, logo, key, title, range_builds):
    maximum = max(build[key].max().item() for build in builds)
    ref_max = reference[key].max().item()
    zoomed = maximum / ref_max < ZOOM_SHARE
    nmax = max(max(build["n"]) for build in [reference, *builds])
    unit = ("s", 1.0) if key == "seconds" else (("GB", 1e9) if max(ref_max, maximum) >= 1e9 else ("MB", 1e6))
    near_unit = (("s", 1.0) if maximum >= 1 else ("ms", 1e-3)) if key == "seconds" else (("GB", 1e9) if maximum >= 1e9 else ("MB", 1e6))
    top, near = max(ref_max, maximum) * 1.5, maximum * 1.5
    whole = figure.add_axes((0.11, bottom, 0.37 if zoomed else 0.77, 0.225))
    _axes(whole, top / unit[1], nmax)
    whole.plot(reference["n"], reference[key] / unit[1], color=BEFORE_RED, linewidth=1.3,
               marker="s", markersize=2.4, zorder=2)
    panels = [(whole, unit[1])]
    near_ax = None
    if zoomed:
        near_ax = figure.add_axes((0.55, bottom, 0.33, 0.225))
        _axes(near_ax, near / near_unit[1], nmax)
        near_ax.yaxis.tick_right()
        near_ax.yaxis.set_label_position("right")
        near_ax.set_ylabel(near_unit[0], fontsize=9)
        panels.append((near_ax, near_unit[1]))
    r_end = (reference["n"][-1], reference[key][-1] / unit[1])
    collision = False
    names = []
    memory_tolerance = COINCIDENT_CLEARANCE_PT * 1.5 * max(build["bytes"].max() for build in builds) / (whole.get_position().height * figure.get_figheight() * 72)
    groups = _groups(builds, key, range_builds, memory_tolerance)
    ends = {ax: [] for ax, _ in panels}
    for build, values in groups:
        lower, upper = values.min(axis=0), values.max(axis=0)
        at = (build["n"][-1], upper[-1] / unit[1])
        close = np.linalg.norm(whole.transData.transform(at) - whole.transData.transform(r_end)) * 72 / figure.dpi < 14
        collision |= close
        for ax, size in panels:
            if len(values) > 1:
                ax.plot(build["n"], lower / size, color=build["style"]["color"], linewidth=0.9, marker="o", markersize=2.0)
                ax.vlines(build["n"], lower / size, upper / size, color=build["style"]["color"], linewidth=0.8, alpha=0.45)
            ax.plot(build["n"], upper / size, color=build["style"]["color"], linewidth=1.3,
                    marker="o" if build["style"]["filled"] else "^", markersize=2.4)
            end = lower[-1] if len(values) > 1 else upper[-1]
            point = (build["n"][-1], end / size)
            pixel = ax.transData.transform(point)
            nested = not build["style"]["filled"] and any(np.linalg.norm(pixel - previous) * 72 / figure.dpi < 2 for previous in ends[ax])
            _marker_at(ax, point, build["style"], -10 if close and ax is whole else 0, nested)
            ends[ax].append(pixel)
            if build["style"]["name"] and ax is panels[-1][0]:
                names.append((build["n"][-1], upper[-1] / size, build["style"]["name"]))
    if names:
        xs, ys, texts = zip(*names, strict=True)
        endpoint_axes = panels[-1][0]
        figure.draw_without_rendering()
        renderer = figure.canvas.get_renderer()
        width = max(renderer.get_text_width_height_descent(text, FontProperties(size=9), False)[0] for text in texts)
        radius = max(mark["markersize"] for build, _ in groups for mark in _marker_styles(build["style"])) / 2
        reserved = (width + (radius + 6) * figure.dpi / 72) / endpoint_axes.get_window_extent(renderer).width
        if reserved >= 1:
            raise ValueError(f"endpoint labels exceed panel width: {texts}")
        left, right = endpoint_axes.get_xlim()
        endpoint_axes.set_xlim(left, max(right, left + (max(xs) - left) / (1 - reserved)))
        endpoint_axes.set_xticks(np.linspace(0, nmax, 3))
        if place_labels(endpoint_axes, xs, ys, texts, fontsize=9):
            raise ValueError(f"cannot place labels {texts}")
    _logo_at(whole, r_end, logo, 10 if collision else 0)
    whole.set_title(title, loc="left", fontsize=10.5, pad=6)
    whole.set_ylabel(unit[0], fontsize=9)
    if key == "bytes":
        whole.set_xlabel("N", fontsize=9, loc="right")
    if near_ax is not None:
        (x0, y0), (x1, y1) = _visible_box(whole, (-X_PAD * nmax, -Y_PAD * near / unit[1]), (nmax * 1.12, near / unit[1]))
        box_outline(whole, (y0 + 0.5, y1 + 0.5, x0 + 0.5, x1 + 0.5), ZOOM_COLOUR).set_zorder(2.5)
        link(figure, whole, near_ax, [(x1, y1), (x1, y0)], [(0, 1), (0, 0)], ZOOM_COLOUR)
        for spine in near_ax.spines.values():
            spine.set(visible=True, edgecolor=ZOOM_COLOUR, linewidth=WIDTHS["frame"], path_effects=halo(WIDTHS["frame"]))
    return {"zoomed": zoomed, "largest_build_share": maximum / ref_max, "unit": unit[0], "zoom_unit": near_unit[0] if zoomed else None,
            "grouped_curve_names": [build["style"]["name"] for build, _ in groups if build["style"]["name"]],
            "memory_coincidence_tolerance_bytes": memory_tolerance}


def _source_panel(figure, builds, logo, total, range_builds):
    unique = {}
    for build in builds:
        counts = build["source"]
        unique.setdefault((counts["added"], counts["removed"]), build)
    extrema = range_builds or len(unique) > 3
    if extrema:
        selected = sorted(unique.values(), key=lambda build: total - build["source"]["removed"] + build["source"]["added"])
        selected = [selected[0], selected[-1]]
    else:
        selected = list(unique.values())
    ax = figure.add_axes((0.11, 0.075, 0.77, 0.20))
    xmax = max(total, *(total - build["source"]["removed"] + build["source"]["added"] for build in selected))
    ax.set_xlim(-xmax if extrema else 0, xmax * (1.65 if extrema else 1.35))
    count_rows = 3 if extrema else 2 * len(selected)
    ax.set_ylim(-0.65, count_rows - 0.35)
    labels = []
    if extrema:
        ax.barh(2, total, height=0.56, color=R_GREY)
        logo_artist = _logo_at(ax, (total + xmax * 0.035, 2), logo)
        labels.append((logo_artist, 2, f"{total:,}"))
    for i, build in enumerate(selected):
        added, removed = build["source"]["added"], build["source"]["removed"]
        kept = total - removed
        y = 1 - i if extrema else 2 * (len(selected) - i - 1)
        ax.barh(y, kept, height=0.56, color=R_GREY)
        ax.barh(y, added, left=kept, height=0.56, color=DEFAULT_BLUE)
        end = kept + added + xmax * 0.035
        _marker_at(ax, (end, y), build["style"])
        text = f"\N{MINUS SIGN}{removed:,}  +{added:,}" if extrema else f"+{added:,}"
        if place_labels(ax, [end], [y], [text], fontsize=9):
            raise ValueError("source counts do not fit")
        if extrema:
            name = {"trimmed_qr": "trimmed QR"}.get(build["source"]["variant"], build["source"]["variant"].replace("_", " "))
            tag_artist(ax.text(-xmax * 0.97, y, name, ha="left", va="center", fontsize=9), semantic_role="row_heading")
        else:
            ax.barh(y + 1, kept, height=0.56, color=R_GREY)
            ax.barh(y + 1, removed, left=kept, height=0.56, color=BEFORE_RED, hatch="////", edgecolor="white", linewidth=0.3)
            labels.append((_logo_at(ax, (total + xmax * 0.035, y + 1), logo), y + 1, f"\N{MINUS SIGN}{removed:,}"))
    ax.set_yticks([])
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.spines["bottom"].set_bounds(0, ax.get_xlim()[1])
    ax.set_xticks([value for value in MaxNLocator(4).tick_values(0, ax.get_xlim()[1]) if 0 <= value <= ax.get_xlim()[1]])
    ax.xaxis.set_major_formatter(FuncFormatter(_number))
    ax.tick_params(labelsize=9)
    ax.set_title("source lines", loc="left", fontsize=10.5, pad=6)
    tag_artist(ax, semantic_role="body")
    figure.draw_without_rendering()
    for artist, y, text in labels:
        x = ax.transData.inverted().transform((artist.get_window_extent(figure.canvas.get_renderer()).x1, 0))[0]
        if place_labels(ax, [x], [y], [text], fontsize=9):
            raise ValueError("reference source count does not fit")
    return {"reference": total, "extrema_only": extrema, "shown": [build["source"] for build in selected],
            "added_range": [min(b["source"]["added"] for b in builds), max(b["source"]["added"] for b in builds)],
            "removed_range": [min(b["source"]["removed"] for b in builds), max(b["source"]["removed"] for b in builds)]}


def build_figure(*, target_width_cm: float = 16.0, experiment=None):
    """Read saved tables and draw one experiment; the checker supplies width, the environment selects data."""
    experiment = experiment or os.environ["LOESS_FIGURE_EXPERIMENT"]
    if experiment not in EXPERIMENTS:
        raise ValueError(f"unknown figure selection: experiment={experiment}")
    apply_style()
    reference, builds, logo, total, sources, missing = _data(experiment)
    figure = plt.figure(figsize=figure_size(target_width_cm, height_cm=13.5))
    panels = {key: _pair(figure, bottom, reference, builds, logo, key, title, experiment == "003")
              for key, bottom, title in (("seconds", 0.675, "time"), ("bytes", 0.365, "requested memory"))}
    lines = _source_panel(figure, builds, logo, total, experiment == "003")
    handles: list[Any] = [OffsetImage(logo)]
    labels = [""]
    for build in builds:
        style = build["style"]
        if style["label"] in labels:
            continue
        handles.append(tuple(Line2D([], [], linestyle="none", **mark) for mark in _marker_styles(style, 0.85)))
        labels.append(style["label"])
    figure.legend(handles, labels, handler_map={tuple: HandlerTuple(ndivide=1), OffsetImage: _LogoHandler()},
                  loc="upper center", bbox_to_anchor=(0.5, 0.995), ncol=len(handles), fontsize=9, handlelength=1.2,
                  handletextpad=0.4, columnspacing=1.2, borderaxespad=0, frameon=False)
    return figure, {"scientific_job": "measured growth trajectories and source comparison", "experiment": experiment,
                    "zoom_share_threshold": ZOOM_SHARE, "coincidence_sd_multiplier": COINCIDENT_SD,
                    "coincidence_clearance_pt": COINCIDENT_CLEARANCE_PT,
                    "coincidence_rule": "equal endpoint memory, earlier memory differences below display clearance, median times within two combined replicate SDs; first curve represents the group",
                    "panels": panels, "source_lines": lines,
                    "range_definition": "bounds across saved build medians; no statistical uncertainty interval",
                    "memory_definition": "requested native bytes; excludes the influence matrix; not resident memory",
                    "sources": sources, "missing_observations": missing}
