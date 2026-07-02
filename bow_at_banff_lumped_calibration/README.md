# Bow River at Banff Parallel Lumped Calibration

This directory contains the `ParallelDDS` OSTRICH calibration case for a lumped SUMMA model of the Bow River basin upstream of the Banff streamflow gauge `CAN_05BB001`. The SUMMA domain contains one grouped response unit (GRU) and one hydrologic response unit (HRU).

The case is intended for the `vhpc-hydrotools` Slurm virtual machine. That environment provides Slurm, OpenMPI, Python, `OstrichMPI`, and `summa.exe` on `PATH`. See the top-level README for tested executable versions.

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
└── scripts/
```

`obs/` contains observed daily streamflow for station `CAN_05BB001`.

`model/forcing/4_SUMMA_input/` contains the cropped SUMMA forcing file `CAN_05BB001_lumped_2002_2009.nc`, spanning `2002-10-01 00:00` through `2009-09-30 23:00`.

`model/settings/SUMMA/` contains the SUMMA configuration, attributes, parameter tables, state files, and trial parameter files.

`model/simulations/run1/SUMMA/` is regenerated inside each OSTRICH worker directory.

`ostIn.txt` runs `scripts/run_trial.sh` with `ParallelDDS` for 40 evaluations, optimizes a KGE-based objective, and preserves the best trial with `scripts/save_best.sh`. `ostrich/` contains the multiplier template and initial multiplier values.

`scripts/run_ostrich.sh` submits a Slurm strong-scaling job with 1, 2, and 4 model-evaluation workers. Each run requests one additional OSTRICH MPI task for the coordinator rank.

`output_archive/` is created at run time and contains the best `trialParams.nc`, `run1_day.nc`, diagnostics, multiplier files, and OSTRICH logs.

## Slurm Calibration

Start the virtual cluster from the `vhpc-hydrotools` repository:

```sh
cd ../vhpc-hydrotools
docker compose up -d
```

Log in to the head node:

```sh
ssh -p 2222 user@localhost
```

The VM stores the course repository in a named Docker volume at `/workspace/hydrolearn-hpc`. If the VM workspace was seeded before this branch existed, update that checkout before submitting the job:

```sh
cd /workspace/hydrolearn-hpc
git fetch origin
git checkout parallelize_lumped_calibration
git pull --ff-only
```

Submit the `ParallelDDS` calibration from the case directory:

```sh
cd /workspace/hydrolearn-hpc/bow_at_banff_lumped_calibration
sbatch scripts/run_ostrich.sh
```

Check job state with:

```sh
squeue
```

After the job completes, inspect the best archived trial:

```sh
cat output_archive/KGE.txt
ls output_archive
```

Inspect the strong-scaling summary, replacing `123456` with the Slurm job ID:

```sh
cat strong_scaling_summary_123456.csv
```

The Slurm script assumes it is submitted from the case directory. The workflow expects `python`, `summa.exe`, and `OstrichMPI` on `PATH`.

Remove generated SUMMA outputs, diagnostics, OSTRICH worker directories, OSTRICH logs, Slurm logs, scaling summaries, scaling archives, and the best-trial archive with:

```sh
./scripts/clear_outputs.sh
```
