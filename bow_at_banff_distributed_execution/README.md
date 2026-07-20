# Bow River at Banff: Distributed Model Execution

This directory contains the serial SUMMA and mizuRoute example for the distributed Bow River basin upstream of the Banff streamflow gauge `CAN_05BB001`. The SUMMA domain contains 52 grouped response units (GRUs), each with one hydrologic response unit (HRU).

SUMMA uses hourly CAMELS-SPAT ERA5 forcing from `CAN_05BB001_era5_distributed_2002_2009.nc`. The configured run covers `2002-10-01 00:00` through `2005-10-01 23:00` and writes daily outputs. mizuRoute routes daily `averageRoutedRunoff_mean` through the 52-segment network in `model/settings/mizuRoute/topology.nc`.

Diagnostics compare simulated streamflow to observed daily flow over `2003-10-01` through `2005-09-30`, excluding the first water year as spin-up. The bundled result has KGE' `0.895356`.

The case requires `summa.exe`, `mizuRoute.exe`, and NCO; see the top-level `README.md` for tested versions. Assignment instructions are provided in `ASSIGNMENT.md`, while the rubric and sample solution are provided in `RUBRIC.md` and `SOLUTION.md`, respectively.

## Layout

```text
bow_at_banff_distributed_execution/
├── model/
│   ├── forcing/
│   ├── settings/
│   │   ├── SUMMA/
│   │   └── mizuRoute/
│   ├── shapefiles/
│   └── simulations/
├── obs/
├── results/
└── scripts/
```

`obs/` contains observed daily streamflow for station `CAN_05BB001`.

`model/forcing/4_SUMMA_input/` contains SUMMA meteorological forcing files. The active file is selected by `model/settings/SUMMA/forcingFileList.txt`.

`model/settings/SUMMA/` contains the SUMMA file manager, decisions, output control, attributes, trial parameters, state files, and parameter tables.

`model/settings/mizuRoute/` contains `mizuRoute.control`, `topology.nc`, and `param.nml.default`.

`model/shapefiles/` contains GIS inputs used to build the distributed basin and river-network attributes.

`scripts/run_SUMMA_mizuRoute.sh` runs all 52 GRUs in one serial SUMMA process.

## Serial Execution

Run the model from this directory:

```sh
./scripts/run_SUMMA_mizuRoute.sh
```

The command assumes that `python`, `summa.exe`, `mizuRoute.exe`, and NCO tools (`ncks`, `ncap2`, and `ncrcat`) are available. Override executable paths when needed:

```sh
PYTHON=/path/to/python \
SUMMA_EXE=/path/to/summa.exe \
MIZUROUTE_EXE=/path/to/mizuRoute.exe \
./scripts/run_SUMMA_mizuRoute.sh
```

During a run, `model_run.log` records phases, previous `run1` outputs are removed, and regenerated diagnostics are written to `results/`.

Remove generated `run1` outputs, diagnostics, and `model_run.log` with:

```sh
./scripts/clear_outputs.sh
```
