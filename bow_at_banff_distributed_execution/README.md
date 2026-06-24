# Bow River at Banff: distributed model execution

This directory contains a self-contained example for running the SUMMA hydrologic
model, routing the resulting runoff through mizuRoute, and calculating streamflow
diagnostics. The example simulates the distributed hydrologic response of the Bow
River basin in Alberta, Canada, upstream of the Banff streamflow gauge
`CAN_05BB001`. The SUMMA domain contains 52 grouped response units (GRUs), each
consisting of a single hydrologic response unit (HRU).

**SUMMA** is forced at an hourly time step by
`CAN_05BB001_era5_distributed_2002_2009.nc`, a cropped copy of the public
[CAMELS-SPAT ERA5 distributed forcing][can-era5] for basin `CAN_05BB001`. In the
FRDR CAMELS-SPAT dataset, the source file is stored under the dataset root at
`forcing/macro-scale/era5/era5-distributed/CAN_05BB001_era5_distributed.nc`.

[can-era5]: https://www.frdr-dfdr.ca/repo/files/1/published/publication_1301/submitted_data/forcing/macro-scale/era5/era5-distributed/CAN_05BB001_era5_distributed.nc

The forcing contains precipitation rate, air temperature, air pressure, specific
humidity, wind speed, incoming shortwave radiation, and incoming longwave
radiation. The cropped local file spans `2002-10-01 00:00` through
`2009-10-01 23:00`; the full public source file spans `1949-12-31 17:00`
through `2023-01-03 16:00`. This configured example uses the window from
`2002-10-01 00:00` through `2005-10-01 23:00`. SUMMA writes daily mean
precipitation, daily mean air temperature, and daily mean routed runoff for 1096
daily output times.

**mizuRoute** routes the SUMMA daily `averageRoutedRunoff_mean` field through the
52-segment river network in `model/settings/mizuRoute/topology.nc`. The routing
configuration uses the impulse response function option, daily runoff input with a
86400 second (one day) time step, and no basin routing or runoff remapping.

The diagnostics script compares the simulated mizuRoute streamflow against the
observed `CAN_05BB001` streamflow record, and writes the Kling-Gupta efficiency
(KGE) to `results/KGE.txt`. The first water year (`2002-10-01` to `2003-09-30`)
is excluded from the KGE calculation due to the model's spin-up period.

## Layout

```text
bow_at_banff_distributed_execution/
├── data/
├── model/
│   ├── forcing/
│   ├── settings/
│   │   ├── SUMMA/
│   │   └── mizuRoute/
│   ├── shapefiles/
│   └── simulations/
├── results/
└── scripts/
```

`data/` contains observed daily streamflow for station `CAN_05BB001`. The run
diagnostics compare the simulated mizuRoute streamflow against this record.

`model/forcing/4_SUMMA_input/` contains SUMMA meteorological forcing NetCDF files.
The active forcing file is selected by `model/settings/SUMMA/forcingFileList.txt`.

`model/settings/SUMMA/` contains the SUMMA configuration. Key files include
`fileManager.txt`, `modelDecisions.txt`, `outputControl.txt`, `attributes.nc`,
`trialParams.nc`, and the parameter tables `TBL_*.TBL`. The `states/` subdirectory
contains the initial state file used by `fileManager.txt`.

`model/settings/mizuRoute/` contains the mizuRoute configuration. The main control
file is `mizuRoute.control`, the routing topology is `topology.nc`, and
`param.nml.default` contains routing parameter defaults.

`model/shapefiles/` contains GIS inputs used to build the distributed basin,
river-network, and catchment-intersection attributes. The `_workflow_log/`
subdirectories under the model settings and shapefile folders preserve the scripts
and logs used to generate the bundled inputs.

`model/simulations/run1/` contains model output for the `run1` case. SUMMA writes
to `model/simulations/run1/SUMMA/`, and mizuRoute writes to
`model/simulations/run1/mizuRoute/`.

`scripts/` contains the executable workflow:

- `run_SUMMA_mizuRoute.sh` runs SUMMA, merges SUMMA outputs, shifts daily output
  times from SUMMA's period-ending daily means to mizuRoute's start-of-period
  routing convention, runs mizuRoute, merges routed outputs, and calculates
  diagnostics.
- `summa_run.sh` is called by `run_SUMMA_mizuRoute.sh` and runs each GRU
  sequentially using the SUMMA executable selected by `SUMMA_EXE`, or
  `summa.exe` from `PATH` by default.
- `calculate_run_diagnostics.py` writes `KGE.txt`, `streamflow_simulated.csv`, and
  `obs_vs_sim.png` from the merged mizuRoute output.

## Serial execution

The bundled runner executes the model in serial. It uses `scripts/summa_run.sh` to
loop over the 52 GRUs one after another, then runs one mizuRoute job and the
diagnostics script. Run it from this directory:

```sh
cd bow_at_banff_distributed_execution
./scripts/run_SUMMA_mizuRoute.sh
```

The command assumes `summa.exe`, `mizuRoute.exe`, NCO tools such as `ncks`,
`ncap2`, and `ncrcat`, and an active Python environment with the repository
requirements are available. If `summa.exe` or `mizuRoute.exe` are not in your
`PATH`, set the environment variables `SUMMA_EXE` and `MIZUROUTE_EXE` to the full
paths of the executables before running the script.

During a run, `model_run.log` records phases, SUMMA output is written to
`model/simulations/run1/SUMMA/`, routed output is written to
`model/simulations/run1/mizuRoute/`, and final diagnostics are written to
`results/`. The runner removes previous `run1` SUMMA and mizuRoute output files
before regenerating them.

`results/` contains diagnostics produced from the latest completed run. These files
can be regenerated by running `scripts/run_SUMMA_mizuRoute.sh`.
