# Bow River at Banff lumped calibration

This directory contains the current local OSTRICH calibration case for a lumped
SUMMA model of the Bow River basin upstream of the Banff streamflow gauge
`CAN_05BB001`. The SUMMA domain contains one grouped response unit (GRU) and one
hydrologic response unit (HRU).

The case uses the repository Python 3.12 environment and also requires external
`ostrich` and `summa.exe` executables. The bundled `output_archive/` logs report
`OSTRICH version 26.06.23 (Built Jun 23 2026 @ 22:51:28)`, which is a
build-date executable identifier rather than a tagged source code release (we use the current `v21.03.16` release)

## Layout

```text
bow_at_banff_lumped_calibration/
├── ostIn.txt
├── data/
├── model/
│   ├── forcing/
│   ├── settings/SUMMA/
│   ├── shapefiles/
│   └── simulations/
├── ostrich/
├── output_archive/
├── results/
└── scripts/
```

`data/` contains observed daily streamflow for station `CAN_05BB001`.

`model/forcing/4_SUMMA_input/` contains the cropped SUMMA forcing file
`CAN_05BB001_lumped_2002_2009.nc`, spanning `2002-10-01 00:00` through
`2009-09-30 23:00`.

`model/settings/SUMMA/` contains the SUMMA configuration, attributes, parameter
tables, state files, and trial parameter files.

`model/simulations/run1/SUMMA/` contains the current SUMMA output files used by
the diagnostics script.

`ostIn.txt` runs `scripts/run_trial.sh` with DDS for 20 iterations, optimizes a
KGE-based objective, and preserves the best trial with `scripts/save_best.sh`.
`ostrich/` contains the multiplier template and current multiplier values.

`results/` contains diagnostics from the latest completed run. The bundled
results have KGE `0.545978` over `2003-10-01` through `2005-09-30`.

`output_archive/` contains the best-trial archive written by
`scripts/save_best.sh`, including the best `trialParams.nc`, `run1_day.nc`,
diagnostics, multiplier files, and OSTRICH logs.

Root-level `Ost*.txt` files and `model_run.log` are regenerated local runtime
outputs and are not part of the committed case.

## Local calibration

Run the calibration from this directory:

```sh
./scripts/run_ostrich.sh
```

The runner defaults to `ostrich` and `summa.exe` from `PATH`. Override them when
needed:

```sh
OSTRICH_EXE=/path/to/ostrich SUMMA_EXE=/path/to/summa.exe ./scripts/run_ostrich.sh
```

If `PYTHON` is unset, the runner uses the repository `.venv/bin/python` when it
exists, then falls back to `python3`.

## Diagnostics only

To recompute diagnostics from the current SUMMA daily output:

```sh
../.venv/bin/python scripts/calculate_lumped_diagnostics.py --make-plot
```
