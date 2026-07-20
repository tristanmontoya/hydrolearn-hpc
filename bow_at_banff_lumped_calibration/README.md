# Bow River at Banff: Lumped Model Calibration

This directory contains the serial OSTRICH calibration case for a lumped SUMMA model of the Bow River basin upstream of the Banff streamflow gauge `CAN_05BB001`. The SUMMA domain contains one grouped response unit (GRU) and one hydrologic response unit (HRU).

SUMMA uses hourly CAMELS-SPAT ERA5 forcing from `CAN_05BB001_lumped_2002_2009.nc`. The configured run covers `2002-10-01 00:00` through `2009-09-30 23:00` and writes daily outputs. OSTRICH runs serial dynamically dimensioned search (DDS) for 40 evaluations and preserves the best trial in `output_archive/`.

Diagnostics compare simulated streamflow to observed daily flow over `2003-10-01` through `2005-09-30`, excluding the first water year as spin-up. The objective function minimizes negative KGE'.

The case requires `ostrich` and `summa.exe`; see the top-level README for tested versions. Assignment instructions are provided in `ASSIGNMENT.md`, while the rubric and sample solution are provided in `RUBRIC.md` and `SOLUTION.md`, respectively.

## Layout

```text
bow_at_banff_lumped_calibration/
├── ostIn.txt
├── model/
│   ├── forcing/
│   ├── settings/SUMMA/
│   ├── shapefiles/
│   └── simulations/
├── obs/
├── ostrich/
├── output_archive/
├── results/
└── scripts/
```

`obs/` contains observed daily streamflow for station `CAN_05BB001`.

`model/forcing/4_SUMMA_input/` contains SUMMA meteorological forcing files. The active file is selected by `model/settings/SUMMA/forcingFileList.txt`.

`model/settings/SUMMA/` contains the SUMMA configuration, attributes, parameter tables, state files, and trial parameter files.

`ostIn.txt` runs `scripts/run_trial.sh` with serial DDS for 40 evaluations, minimizes negative KGE', and preserves the best trial with `scripts/save_best.sh`.

`ostrich/` contains the multiplier template and current multiplier values.

`scripts/run_ostrich.sh` runs the serial OSTRICH calibration.

## Serial Calibration

Run the calibration from this directory:

```sh
./scripts/run_ostrich.sh
```

The command assumes that `python`, `summa.exe`, and `ostrich` are available. Override executable paths used by calibration trials when needed:

```sh
PYTHON=/path/to/python \
SUMMA_EXE=/path/to/summa.exe \
./scripts/run_ostrich.sh
```

During a run, `model_run.log` records calibration phases, previous `run1` outputs are removed for each trial, regenerated diagnostics are written to `results/`, and the best trial is written to `output_archive/`.

Remove generated SUMMA outputs, diagnostics, OSTRICH worker directories, OSTRICH logs, Slurm logs, timing files, scaling archives, and the best-trial archive with:

```sh
./scripts/clear_outputs.sh
```
