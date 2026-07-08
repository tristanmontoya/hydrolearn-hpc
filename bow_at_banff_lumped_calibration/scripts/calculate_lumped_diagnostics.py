#!/usr/bin/env python3
"""Calculate streamflow diagnostics for the Bow at Banff lumped calibration."""

from __future__ import annotations

import argparse
import logging
import os
import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr


LOGGER = logging.getLogger(__name__)
CFS_PER_CMS = 35.3147


# Build the command-line interface for reproducible lumped diagnostics
def process_command_line() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Calculate KGE and streamflow diagnostics for the lumped run."
    )
    parser.add_argument(
        "--sim-file",
        default="model/simulations/run1/SUMMA/run1_day.nc",
        help="SUMMA daily output file relative to the basin directory.",
    )
    parser.add_argument(
        "--attributes-file",
        default="model/settings/SUMMA/attributes.nc",
        help="SUMMA attributes file relative to the basin directory.",
    )
    parser.add_argument(
        "--obs-file",
        default="obs/obs_flow.CAN_05BB001.cfs.csv",
        help="Observation CSV relative to the basin directory.",
    )
    parser.add_argument(
        "--output-dir",
        default="results",
        help="Diagnostics output directory relative to the basin directory.",
    )
    parser.add_argument(
        "--runoff-var",
        default="averageRoutedRunoff_mean",
        help="SUMMA routed runoff variable to evaluate.",
    )
    parser.add_argument(
        "--area-var",
        default="HRUarea",
        help="SUMMA attribute variable containing HRU area.",
    )
    parser.add_argument(
        "--obs-unit",
        choices=("cfs", "cms"),
        default="cfs",
        help="Observation streamflow unit.",
    )
    parser.add_argument(
        "--start-date",
        default="2003-10-01",
        help="First date included in KGE calculation.",
    )
    parser.add_argument(
        "--end-date",
        default="2005-09-30",
        help="Last date included in KGE calculation.",
    )
    parser.add_argument(
        "--make-plot",
        action="store_true",
        help="Write an observed-versus-simulated hydrograph PNG.",
    )
    return parser.parse_args()


# Resolve relative paths from the basin directory
def resolve_basin_path(basin_dir: Path, path_text: str) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        return path
    return basin_dir / path


# Calculate the modified Kling-Gupta efficiency
def calculate_modified_kge(obs: np.ndarray, sim: np.ndarray) -> float:
    obs_std = np.std(obs, ddof=1)
    sim_std = np.std(sim, ddof=1)
    obs_mean = np.mean(obs)
    sim_mean = np.mean(sim)

    correlation = np.corrcoef(sim, obs)[0, 1]
    relative_variability = (sim_std / sim_mean) / (obs_std / obs_mean)
    bias = sim_mean / obs_mean

    return float(
        1.0
        - np.sqrt(
            (correlation - 1.0) ** 2
            + (relative_variability - 1.0) ** 2
            + (bias - 1.0) ** 2
        )
    )


# Read observed streamflow and convert it to cubic meters per second
def read_observations(obs_file: Path, obs_unit: str) -> pd.DataFrame:
    observations = pd.read_csv(
        obs_file,
        index_col=0,
        usecols=[0, 1],
        na_values=["-99.0", "-999.0", "-9999.0", "NA"],
    )
    observations.columns = ["obs"]

    obs_dates = observations.index.astype(str)
    parsed_dates = pd.to_datetime(obs_dates, format="%m/%d/%y", errors="coerce")
    if parsed_dates.isna().any():
        parsed_dates = pd.to_datetime(obs_dates, format="%Y-%m-%d", errors="coerce")
    if parsed_dates.isna().any():
        raise ValueError(f"Could not parse all observation dates in {obs_file}")

    observations.index = parsed_dates

    if obs_unit == "cfs":
        observations["obs"] /= CFS_PER_CMS

    return observations


# Convert SUMMA routed runoff depth to basin streamflow
def read_summa_streamflow(
    sim_file: Path,
    attributes_file: Path,
    runoff_var: str,
    area_var: str,
) -> pd.DataFrame:
    with xr.open_dataset(sim_file) as runoff_dataset:
        with xr.open_dataset(attributes_file) as attributes:
            if runoff_var not in runoff_dataset:
                raise KeyError(f"{runoff_var} was not found in {sim_file}")
            if area_var not in attributes:
                raise KeyError(f"{area_var} was not found in {attributes_file}")

            runoff = runoff_dataset[runoff_var]
            area = attributes[area_var]

            if runoff.shape[1] != area.size:
                raise ValueError("Runoff and HRU area dimensions do not match")

            streamflow = (runoff * area.values).sum(dim=runoff.dims[1])
            simulated = pd.DataFrame(
                {"sim": streamflow.values},
                index=pd.to_datetime(runoff_dataset["time"].values),
            )

    simulated.index.name = "time"
    return simulated


# Merge observations and simulations over the evaluation window
def merge_evaluation_window(
    observations: pd.DataFrame,
    simulated: pd.DataFrame,
    start_date: str,
    end_date: str,
) -> pd.DataFrame:
    merged = pd.concat([observations, simulated], axis=1).dropna()
    merged = merged.loc[start_date:end_date]

    if merged.empty:
        raise ValueError("No overlapping observed and simulated values were found")

    return merged


# Write the hydrograph image when matplotlib is available
def write_hydrograph(merged: pd.DataFrame, kge: float, output_file: Path) -> None:
    try:
        mpl_config_dir = Path(tempfile.gettempdir()) / "hydrolearn-hpc-matplotlib"
        mpl_config_dir.mkdir(parents=True, exist_ok=True)
        os.environ.setdefault("MPLCONFIGDIR", str(mpl_config_dir))
        os.environ.setdefault("XDG_CACHE_HOME", str(mpl_config_dir))

        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        LOGGER.warning("matplotlib is unavailable, so %s was not written", output_file)
        return

    figure, axis = plt.subplots(figsize=(10, 4))
    axis.plot(merged.index, merged["obs"], "k-", label="Observed")
    axis.plot(merged.index, merged["sim"], "r:", label="Simulated")
    axis.set_title(f"Observed vs simulated streamflow (KGE = {kge:.3f})")
    axis.set_xlabel("Time")
    axis.set_ylabel("Streamflow (m^3/s)")
    axis.legend()
    axis.grid(alpha=0.3)
    figure.tight_layout()
    figure.savefig(output_file, dpi=300, bbox_inches="tight")
    plt.close(figure)


# Run diagnostics and write reproducible output artefacts
def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    logging.getLogger("matplotlib").setLevel(logging.WARNING)
    args = process_command_line()

    basin_dir = Path(__file__).resolve().parents[1]
    sim_file = resolve_basin_path(basin_dir, args.sim_file)
    attributes_file = resolve_basin_path(basin_dir, args.attributes_file)
    obs_file = resolve_basin_path(basin_dir, args.obs_file)
    output_dir = resolve_basin_path(basin_dir, args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    observations = read_observations(obs_file, args.obs_unit)
    simulated = read_summa_streamflow(
        sim_file,
        attributes_file,
        args.runoff_var,
        args.area_var,
    )
    merged = merge_evaluation_window(
        observations,
        simulated,
        args.start_date,
        args.end_date,
    )
    kge = calculate_modified_kge(merged["obs"].values, merged["sim"].values)

    simulated.to_csv(output_dir / "streamflow_simulated.csv")
    (output_dir / "KGE.txt").write_text(f"{kge:.6f}\t#KGE\n", encoding="utf-8")

    if args.make_plot:
        write_hydrograph(merged, kge, output_dir / "obs_vs_sim.png")

    LOGGER.info("KGE = %.6f", kge)


if __name__ == "__main__":
    main()
