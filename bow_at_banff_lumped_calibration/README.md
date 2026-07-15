# Bow River at Banff Parallel Lumped Calibration

This directory contains the OSTRICH parallel DDS calibration case for a lumped SUMMA model of the Bow River basin upstream of the Banff streamflow gauge `CAN_05BB001`. The SUMMA domain contains one grouped response unit (GRU) and one hydrologic response unit (HRU).

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
├── results/
└── scripts/
```

`obs/` contains observed daily streamflow for station `CAN_05BB001`.

`model/forcing/4_SUMMA_input/` contains the cropped SUMMA forcing file `CAN_05BB001_lumped_2002_2009.nc`, spanning `2002-10-01 00:00` through `2009-09-30 23:00`.

`model/settings/SUMMA/` contains the SUMMA configuration, attributes, parameter tables, state files, and trial parameter files.

`model/simulations/run1/SUMMA/` is regenerated inside each OSTRICH worker directory.

`ostIn.txt` sets `ProgramType ParallelDDS` with an optimization budget of 40 objective evaluations. Each call to `scripts/run_trial.sh` computes modified Kling-Gupta efficiency from aligned daily streamflow between October 1, 2003, and September 30, 2005. After the search, OSTRICH executes the best parameter set once more on the coordinator so that `scripts/save_best.sh` can preserve its output. `ostrich/` contains the multiplier template and initial multiplier values.

`results/` and `model/simulations/run1/SUMMA/run1_day.nc` contain bundled reference output that reproduces a modified KGE value of `0.545978`. These files are not results from the current parallel scaling jobs.

`scripts/run_ostrich.sh` submits one parallel calibration per Slurm job. It uses the task count requested through `sbatch`, reserves one MPI rank as the coordinator, and uses the remaining ranks as model-evaluation workers. Each job copies the case into `scaling_archive_<jobid>/` so that concurrent jobs use isolated working directories.

`scaling_archive_<jobid>/output_archive/` is created at run time and contains the best `trialParams.nc`, `run1_day.nc`, diagnostics, multiplier files, and OSTRICH logs for that job.

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

Submit a parallel DDS calibration from the case directory. For example, five total tasks provide one coordinator and four model-evaluation workers:

```sh
cd /workspace/hydrolearn-hpc/bow_at_banff_lumped_calibration
sbatch --ntasks=5 scripts/run_ostrich.sh
```

See `ASSIGNMENT.md` for the complete set of worker counts used in the scaling study.

Check job state with:

```sh
squeue -u "$USER" --Format=JobID,Name,StateCompact:4,TimeUsed:8,NumTasks:8,NodeList
```

After the job completes, inspect its MPI step accounting record, Slurm log, and best archived trial. Replace `123456` with the Slurm job ID:

```sh
sacct -j 123456.0 --format=JobID,NTasks,Elapsed
cat slurm-bow-lumped-calib-123456.out
cat scaling_archive_123456/output_archive/KGE.txt
ls scaling_archive_123456/output_archive
```

The Slurm script assumes it is submitted from the case directory. The workflow expects `python`, `summa.exe`, and `OstrichMPI` on `PATH`.

Remove generated SUMMA outputs, diagnostics, OSTRICH worker directories, OSTRICH logs, Slurm logs, scaling archives, and best-trial archives with:

```sh
./scripts/clear_outputs.sh
```

Because the bundled reference files are generated outputs, this cleanup command removes them as well; Git can restore the checked-in copies.
