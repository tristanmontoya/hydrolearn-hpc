#!/usr/bin/env python3
"""Update SUMMA trial parameters from OSTRICH multipliers."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import netCDF4 as nc
import numpy as np


# Build the command-line interface for one OSTRICH trial update
def process_command_line() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Update SUMMA trialParams.nc from OSTRICH multipliers."
    )
    parser.add_argument(
        "--multiplier-template",
        required=True,
        help="Path to the OSTRICH multiplier template.",
    )
    parser.add_argument(
        "--multiplier-values",
        required=True,
        help="Path to the OSTRICH multiplier values.",
    )
    parser.add_argument(
        "--trial-param-file",
        required=True,
        help="Path to the SUMMA trialParams.nc file.",
    )
    return parser.parse_args()


# Load one-column text files while preserving single-value inputs
def load_text_column(path: Path, dtype: type[str] | type[float]) -> list:
    values = np.loadtxt(path, dtype=dtype)
    if np.isscalar(values):
        return [values.item()]
    return list(values)


# Update one NetCDF variable while preserving its mask and fill value
def update_masked_variable(
    destination: nc.Dataset,
    parameter_name: str,
    update_value: np.ndarray,
    prior_values: np.ma.MaskedArray,
) -> None:
    destination.variables[parameter_name][:] = np.ma.array(
        update_value,
        mask=np.ma.getmask(prior_values),
        fill_value=prior_values.get_fill_value(),
    )


# Apply OSTRICH multipliers to a fresh copy of the a priori parameters
def main() -> None:
    args = process_command_line()

    multiplier_template = Path(args.multiplier_template)
    multiplier_values = Path(args.multiplier_values)
    trial_param_file = Path(args.trial_param_file)
    trial_param_priori = trial_param_file.with_name(
        f"{trial_param_file.stem}.priori{trial_param_file.suffix}"
    )

    if not trial_param_priori.is_file():
        raise FileNotFoundError(f"Missing a priori parameters: {trial_param_priori}")

    multiplier_names = load_text_column(multiplier_template, str)
    multiplier_numbers = [
        float(value) for value in load_text_column(multiplier_values, float)
    ]

    if len(multiplier_names) != len(multiplier_numbers):
        raise ValueError("Multiplier names and values have different lengths")

    shutil.copy2(trial_param_priori, trial_param_file)

    with nc.Dataset(trial_param_priori, "r") as source:
        with nc.Dataset(trial_param_file, "r+") as destination:
            for multiplier_name, multiplier_number in zip(
                multiplier_names,
                multiplier_numbers,
            ):
                parameter_name = str(multiplier_name).replace("_multp", "")

                if parameter_name == "thickness":
                    continue

                if parameter_name not in destination.variables:
                    raise KeyError(
                        f"{parameter_name} does not exist in {trial_param_file}"
                    )

                prior_values = source.variables[parameter_name][:]
                update_value = prior_values.data * multiplier_number
                update_masked_variable(
                    destination,
                    parameter_name,
                    update_value,
                    prior_values,
                )

            if "thickness_multp" in multiplier_names:
                thickness_index = multiplier_names.index("thickness_multp")
                thickness_multiplier = multiplier_numbers[thickness_index]

                canopy_top_prior = source.variables["heightCanopyTop"][:]
                canopy_bottom_prior = source.variables["heightCanopyBottom"][:]
                canopy_bottom = destination.variables["heightCanopyBottom"][:]

                prior_thickness = canopy_top_prior.data - canopy_bottom_prior.data
                canopy_top_update = (
                    canopy_bottom.data + prior_thickness * thickness_multiplier
                )

                update_masked_variable(
                    destination,
                    "heightCanopyTop",
                    canopy_top_update,
                    canopy_top_prior,
                )


if __name__ == "__main__":
    main()
