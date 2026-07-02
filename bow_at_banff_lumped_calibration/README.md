# Bow River at Banff lumped calibration

This directory contains the current local OSTRICH calibration case for a lumped SUMMA model of the Bow River basin upstream of the Banff streamflow gauge `CAN_05BB001`. The SUMMA domain contains one grouped response unit (GRU) and one hydrologic response unit (HRU).

The case requires external `ostrich` and `summa.exe` executables. See the top-level README for tested executable versions.

The assignment instructions are in `ASSIGNMENT.md`.

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

`model/forcing/4_SUMMA_input/` contains the cropped SUMMA forcing file `CAN_05BB001_lumped_2002_2009.nc`, spanning `2002-10-01 00:00` through `2009-09-30 23:00`.

`model/settings/SUMMA/` contains the SUMMA configuration, attributes, parameter tables, state files, and trial parameter files.

`model/simulations/run1/SUMMA/` contains the current SUMMA output files used by the diagnostics script.

`ostIn.txt` runs `scripts/run_trial.sh` with DDS for 40 iterations, optimizes a KGE-based objective, and preserves the best trial with `scripts/save_best.sh`.
`ostrich/` contains the multiplier template and current multiplier values.

`results/` contains diagnostics from the latest completed run. The bundled results have KGE `0.545978` over `2003-10-01` through `2005-09-30`.

`output_archive/` contains the best-trial archive written by `scripts/save_best.sh`, including the best `trialParams.nc`, `run1_day.nc`, diagnostics, multiplier files, and OSTRICH logs.

## Local calibration

Run the calibration from this directory:

```sh
./scripts/run_ostrich.sh
```

The workflow expects `python`, `summa.exe`, and `ostrich` on `PATH`.

Remove generated SUMMA outputs, diagnostics, OSTRICH worker directories, OSTRICH logs, Slurm logs, timing files, scaling archives, and the best-trial archive with:

```sh
./scripts/clear_outputs.sh
```
