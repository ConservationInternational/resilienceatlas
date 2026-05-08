#!/usr/bin/env python3
"""
Preprocess SBTN threshold data into a single wide CSV.

Reads per-realm, per-indicator CSVs and outputs one row per ecoregion with
columns for each combination of indicator × metric (baseline / threshold /
exceedance).

Usage:
    python preprocess.py [SOURCE_DIR]

SOURCE_DIR defaults to the OneDrive folder containing realm sub-directories.
Output is written to sbtn_thresholds.csv in the same directory as this script.
"""

import os
import sys
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).parent.resolve()
OUTPUT_CSV = SCRIPT_DIR / "sbtn_thresholds.csv"

DEFAULT_SOURCE = (
    Path.home()
    / "Conservation International Foundation"
    / "Jordan Rogan - To share with Alex"
)

REALMS = [
    "Afrotropic",
    "Australasia",
    "Indomalayan",
    "Nearctic",
    "Neotropic",
    "Oceania",
    "Palearctic",
]

# Short column prefix used in the wide output
IND_CODE = {
    "natural_land": "natural_land",
    "nitrogen_deposition": "nitrogen_dep",
    "soil_erosion": "soil_erosion",
    "soil_organic_carbon": "soc",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def detect_indicator(stem: str) -> str:
    """Infer indicator key from the CSV file name (without extension)."""
    s = stem.lower()
    if "natural" in s:
        return "natural_land"
    if "soc" in s:
        return "soil_organic_carbon"
    if "erosion" in s:
        return "soil_erosion"
    if "acidif" in s:
        return "nitrogen_deposition"
    raise ValueError(f"Cannot detect indicator from filename stem: {stem!r}")

def _norm(name: str) -> str:
    """Normalise a single column name to snake_case."""
    return name.strip().lower().replace(" ", "_").replace(".", "_")


def norm_cols(df: pd.DataFrame) -> pd.DataFrame:
    """Return df with normalised column names."""
    df = df.copy()
    df.columns = [_norm(c) for c in df.columns]
    return df


def load_file(path: Path, realm: str) -> pd.DataFrame:
    """
    Parse one CSV and return a tidy DataFrame with columns:
        eco_id, ecoregion, indicator, realm, baseline, threshold, exceedance
    Rows containing '#VALUE!' in any cell are dropped.
    """
    indicator = detect_indicator(path.stem)

    df = pd.read_csv(path, encoding="latin1", dtype=str)
    df = norm_cols(df)

    # Drop rows that contain '#VALUE!' in any column
    value_err_mask = df.apply(
        lambda col: col.str.contains("#VALUE!", na=False)
    ).any(axis=1)
    n_dropped = int(value_err_mask.sum())
    if n_dropped:
        print(f"    Dropped {n_dropped} row(s) with #VALUE! errors")
    df = df[~value_err_mask].copy()

    # ── eco_id ──
    if "eco_id" not in df.columns:
        raise KeyError(
            f"No eco_id column in {path}. Columns found: {df.columns.tolist()}"
        )
    df["eco_id"] = pd.to_numeric(df["eco_id"], errors="coerce")
    df = df[df["eco_id"].notna()].copy()
    df["eco_id"] = df["eco_id"].astype(int)

    # ── ecoregion name ──
    if "ecoregion_name" in df.columns:
        df["ecoregion"] = df["ecoregion_name"]
    else:
        raise KeyError(
            f"Expected 'ecoregion_name' after normalisation in {path}. "
            f"Columns found: {df.columns.tolist()}"
        )

    # ── threshold: prefer 'final_threshold', fall back to 'threshold' ──
    if "final_threshold" in df.columns:
        df["threshold"] = pd.to_numeric(df["final_threshold"], errors="coerce")
    elif "threshold" in df.columns:
        df["threshold"] = pd.to_numeric(df["threshold"], errors="coerce")
    else:
        raise KeyError(
            f"No threshold column in {path}. Columns found: {df.columns.tolist()}"
        )

    # ── baseline ──
    if "baseline" not in df.columns:
        raise KeyError(
            f"No 'baseline' column in {path}. Columns found: {df.columns.tolist()}"
        )
    df["baseline"] = pd.to_numeric(df["baseline"], errors="coerce")

    # ── exceedance (difference between baseline and threshold) ──
    # Allow for the variant name in Neotropic Soil Erosion:
    #   "Difference between baseline and threshold (threshold exceedance)"
    exceedance_col = next(
        (c for c in df.columns if c.startswith("difference_between_baseline_and_threshold")),
        None,
    )
    if exceedance_col is None:
        raise KeyError(
            f"No exceedance column in {path}. Columns found: {df.columns.tolist()}"
        )
    df["exceedance"] = pd.to_numeric(df[exceedance_col], errors="coerce")

    df["indicator"] = indicator
    df["realm"] = realm

    return df[["eco_id", "ecoregion", "indicator", "realm", "baseline", "threshold", "exceedance"]]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main(source_dir: Path) -> None:
    all_frames: list[pd.DataFrame] = []

    for realm in REALMS:
        realm_dir = source_dir / realm
        if not realm_dir.exists():
            print(f"WARNING: Realm directory not found: {realm_dir}")
            continue
        csvs = sorted(realm_dir.glob("*.csv"))
        if not csvs:
            print(f"WARNING: No CSV files found in {realm_dir}")
            continue
        for csv_file in csvs:
            print(f"  {realm}/{csv_file.name}")
            df = load_file(csv_file, realm)
            print(f"    → {len(df)} rows")
            all_frames.append(df)

    if not all_frames:
        print("ERROR: No data loaded.", file=sys.stderr)
        sys.exit(1)

    long_df = pd.concat(all_frames, ignore_index=True)

    # ── Raise on duplicate (eco_id, indicator) ──
    dupes = long_df.groupby(["eco_id", "indicator"]).filter(lambda g: len(g) > 1)
    if not dupes.empty:
        conflict_rows = (
            dupes[["eco_id", "indicator", "realm"]]
            .sort_values(["eco_id", "indicator"])
            .to_string(index=False)
        )
        raise ValueError(
            "Duplicate (eco_id, indicator) pairs found — each ecoregion must appear "
            f"in exactly one realm per indicator:\n{conflict_rows}"
        )

    # ── Pivot to wide (one row per eco_id) ──
    # Ecoregion name: take first occurrence per eco_id
    eco_names = (
        long_df.groupby("eco_id")["ecoregion"].first().rename("ecoregion")
    )

    wide = eco_names.to_frame()

    for ind_key, col_prefix in IND_CODE.items():
        subset = long_df[long_df["indicator"] == ind_key].set_index("eco_id")
        for metric in ("baseline", "threshold", "exceedance"):
            wide[f"{col_prefix}_{metric}"] = subset[metric]

    wide = wide.reset_index().sort_values("eco_id").reset_index(drop=True)

    # ── Summary ──
    print(f"\nOutput: {len(wide)} ecoregions, {len(wide.columns)} columns")
    null_counts = wide.isnull().sum()
    null_cols = null_counts[null_counts > 0]
    if not null_cols.empty:
        print("Null value counts by column:")
        for col, n in null_cols.items():
            print(f"  {col}: {n}")
    else:
        print("No null values found.")

    wide.to_csv(OUTPUT_CSV, index=False)
    print(f"\nWrote: {OUTPUT_CSV}")


if __name__ == "__main__":
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not src.exists():
        print(f"ERROR: Source directory not found: {src}", file=sys.stderr)
        sys.exit(1)
    main(src)
