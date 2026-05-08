#!/usr/bin/env python3
"""
prepare_ldn_ecoregion_stats.py

Combine the per-methodology ecoregion-summary CSVs produced by the
counterbalancing AWS pipeline into a single file ready for upload to
CartoDB as the `ldn_ecoregion_stats` table.

Transformations applied to each CSV before merging:

1. Add a `methodology` column (derived from the source directory name).

2. Recompute `total_area_km2` as the sum of the seven status columns.
   Older pipeline runs stored a change-area value in total_area_km2 by
   mistake; the status columns are always correct.

3. Recompute `ldn_pct = delta_ldn_km2 / total_area_km2 * 100` for
   consistency with the corrected total_area_km2.

4. Add `baseline_degraded_sqkm` = deg_to_deg + deg_to_stable + deg_to_imp.
   This is the area that was classified **degraded during the 2000-2015
   baseline**, regardless of its subsequent trajectory.
   - status_3_baseline_degradation_sqkm (deg_to_stable) alone is
     insufficient because deg_to_imp land is assigned to status_6
     (baseline improvement), not status_3.

Usage
-----
    python scripts/prepare_ldn_ecoregion_stats.py \\
        --input-dir /path/to/counterbalancing_results \\
        --output    /path/to/ldn_ecoregion_stats.csv

    # Or rely on defaults (input = results/ next to this script, output = cwd):
    python scripts/prepare_ldn_ecoregion_stats.py

The input directory must contain subdirectories named TE/, FAO-WOCAT/, and
JRC/ (matching the S3 layout used by the counterbalancing pipeline).

CartoDB upload
--------------
After running this script, upload ldn_ecoregion_stats.csv to CartoDB under
the `cdb` account (https://cdb.carto.com) and grant SELECT to publicuser:

    GRANT SELECT ON ldn_ecoregion_stats TO publicuser;
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd

# ── Directory name → CartoDB methodology key ─────────────────────────────────
METHODOLOGY_MAP: dict[str, str] = {
    "TE": "trendsearth",
    "FAO-WOCAT": "fao-wocat",
    "JRC": "jrc",
}

# File-label segment used in the CSV filename for each subdirectory
FILE_LABEL_MAP: dict[str, str] = {
    "TE": "Trends.Earth",
    "FAO-WOCAT": "FAO-WOCAT",
    "JRC": "JRC",
}

# The seven status columns that together equal total land area
STATUS_COLS = [
    "status_1_persistent_degradation_sqkm",
    "status_2_recent_degradation_sqkm",
    "status_3_baseline_degradation_sqkm",
    "status_4_stability_sqkm",
    "status_5_baseline_improvement_sqkm",
    "status_6_recent_improvement_sqkm",
    "status_7_persistent_improvement_sqkm",
]

# Transition columns used to derive true baseline degradation
BASELINE_DEG_COLS = ["deg_to_deg_sqkm", "deg_to_stable_sqkm", "deg_to_imp_sqkm"]

# Final column order for the output table
OUTPUT_COLS = [
    "eco_id",
    "methodology",
    "gains_km2",
    "losses_km2",
    "total_area_km2",
    "baseline_degraded_sqkm",
    "status_1_persistent_degradation_sqkm",
    "status_2_recent_degradation_sqkm",
    "status_3_baseline_degradation_sqkm",
    "status_4_stability_sqkm",
    "status_5_baseline_improvement_sqkm",
    "status_6_recent_improvement_sqkm",
    "status_7_persistent_improvement_sqkm",
    "deg_to_deg_sqkm",
    "deg_to_stable_sqkm",
    "deg_to_imp_sqkm",
    "stable_to_deg_sqkm",
    "stable_to_stable_sqkm",
    "stable_to_imp_sqkm",
    "imp_to_deg_sqkm",
    "imp_to_stable_sqkm",
    "imp_to_imp_sqkm",
    "delta_ldn_km2",
    "ldn_pct",
]


def load_and_transform(csv_path: Path, methodology: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path)

    missing = [c for c in STATUS_COLS + BASELINE_DEG_COLS if c not in df.columns]
    if missing:
        raise ValueError(f"{csv_path.name}: missing expected columns: {missing}")

    # 1. Methodology tag
    df.insert(1, "methodology", methodology)

    # 2. Recompute total_area_km2 from the seven status columns (always correct)
    df["total_area_km2"] = df[STATUS_COLS].sum(axis=1)

    # 3. Recompute ldn_pct for consistency
    df["ldn_pct"] = df.apply(
        lambda r: (r["delta_ldn_km2"] / r["total_area_km2"] * 100)
        if r["total_area_km2"] > 0
        else 0.0,
        axis=1,
    )

    # 4. Baseline degraded area (all land degraded at baseline 2000-2015)
    df["baseline_degraded_sqkm"] = df[BASELINE_DEG_COLS].sum(axis=1)

    return df[[c for c in OUTPUT_COLS if c in df.columns]]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Combine counterbalancing ecoregion CSVs into ldn_ecoregion_stats.csv"
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=None,
        help="Directory containing TE/, FAO-WOCAT/, JRC/ subdirectories "
             "(default: counterbalancing_results/ next to this script)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("ldn_ecoregion_stats.csv"),
        help="Output CSV path (default: ldn_ecoregion_stats.csv in cwd)",
    )
    args = parser.parse_args()

    # Default input: counterbalancing_results/ next to this script
    if args.input_dir is None:
        args.input_dir = Path(__file__).parent.parent / "counterbalancing_results"

    if not args.input_dir.is_dir():
        print(f"ERROR: input directory not found: {args.input_dir}", file=sys.stderr)
        sys.exit(1)

    parts: list[pd.DataFrame] = []

    for subdir, methodology in METHODOLOGY_MAP.items():
        label = FILE_LABEL_MAP[subdir]
        subdir_path = args.input_dir / subdir
        csv_name = f"TrendsEarth_LDN_2000-2023_{label}_ecoregion_summary.csv"
        csv_path = subdir_path / csv_name

        if not csv_path.exists():
            print(f"WARNING: not found, skipping — {csv_path}", file=sys.stderr)
            continue

        print(f"  Loading {subdir}/{csv_name}  →  methodology='{methodology}'")
        df = load_and_transform(csv_path, methodology)
        print(f"           {len(df):,} ecoregion rows")
        parts.append(df)

    if not parts:
        print("ERROR: no input CSVs found.", file=sys.stderr)
        sys.exit(1)

    combined = pd.concat(parts, ignore_index=True)

    # Sanity check: no duplicate (eco_id, methodology) pairs
    dupes = combined.duplicated(subset=["eco_id", "methodology"]).sum()
    if dupes:
        print(f"WARNING: {dupes} duplicate (eco_id, methodology) rows found.", file=sys.stderr)

    combined.to_csv(args.output, index=False)
    print(
        f"\nWrote {len(combined):,} rows × {len(combined.columns)} columns "
        f"→ {args.output}"
    )
    print(f"Methodologies: {sorted(combined['methodology'].unique())}")
    print(f"Ecoregions   : {combined['eco_id'].nunique():,} unique eco_id values")


if __name__ == "__main__":
    main()
