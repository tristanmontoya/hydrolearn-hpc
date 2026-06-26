# Activity 2: Parallel Calibration of a Lumped Hydrologic Model

This activity focuses on the parallel calibration of a lumped hydrologic model using the OSTRICH (Optimization Software Toolkit for Research Involving Computational Heuristics) framework. OSTRICH supports a range of optimization algorithms commonly used in hydrology. In this activity, the Asynchronous Parallel Dynamically Dimensioned Search (`ParallelDDS`) algorithm is used.

`ParallelDDS` generates multiple candidate parameter sets during the optimization. Each candidate must be evaluated by running the hydrologic model, and these simulations are independent of one another. This allows the model evaluations to be executed in parallel, reducing calibration time.

Due to the large number of iterations required, this activity uses a simplified modeling setup:

- The model is configured in lumped form, where all spatial units are aggregated into a single basin representation.
- The routing component is removed, since explicit channel routing is not required in lumped models. To compute basin runoff, contributions from all GRUs are summed using area-weighted aggregation.

This activity also uses a multiplier-based parameterization approach, where model parameters are represented as dimensionless multipliers applied to default parameter values. This approach helps maintain physically consistent parameters while allowing efficient exploration of the parameter space during calibration.

## Learning Objectives

By the end of this activity, you should be able to:

- Convert a serial OSTRICH DDS calibration into a `ParallelDDS` calibration.
- Explain why parallel OSTRICH model runs need separate worker directories.
- Submit an OSTRICH MPI calibration through Slurm.
- Measure and interpret a simple strong-scaling experiment.
- Identify practical reasons why parallel speedup is not usually ideal.

## Memo Deliverable

Complete the technical work below and submit one memo written from the perspective of a research computing specialist advising a hydrology research group. Keep the memo practical and concise. Use the following sections:

1. *Current Serial Workflow*
2. *Parallelization Plan*
3. *Slurm and MPI Implementation*
4. *Scaling Results*
5. *Recommendation and Reflection*
6. *Reproducibility Appendix*

## Part 1: Inspect the Serial Calibration Workflow

If you are using the `vhpc-hydrotools` virtual cluster, change into the repository checkout:
```sh
cd /workspace/hydrolearn-hpc
```

If you are using another Slurm cluster, clone the repository yourself in a location of your choice:

```sh
git clone https://github.com/tristanmontoya/hydrolearn-hpc.git
cd hydrolearn-hpc
```

The `main` branch contains a working serial calibration workflow. Create a working branch for your parallel version:

```sh
git checkout main
git pull
git checkout -b parallelize_lumped_calibration
cd bow_at_banff_lumped_calibration
```

Before editing anything, inspect the serial workflow. You can use the `less` command to view the following files:

```sh
less README.md
less ostIn.txt
less scripts/run_ostrich.sh
less scripts/run_trial.sh
less scripts/save_best.sh
```

The file `ostIn.txt` defines the OSTRICH calibration workflow, which currently uses `ProgramType DDS`, meaning that the serial dynamic dimensioned search algorithm is used. The `ModelExecutable` line points to `scripts/run_trial.sh`, which runs the SUMMA model and writes the objective function value to `results/KGE.txt`. The `PreserveBestModel` line points to `scripts/save_best.sh`, which copies the best trial parameter file and simulation output to the `output_archive/` directory.

The serial executable `ostrich` is launched by `scripts/run_ostrich.sh`:

```sh
#!/usr/bin/env bash
set -euo pipefail

export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

ostrich
```

Your goal is to modify this serial workflow so that it runs `ParallelDDS` through Slurm and `OstrichMPI`. Find these settings in the serial `ostIn.txt`:

```text
ProgramType  DDS
ModelExecutable ./scripts/run_trial.sh
PreserveBestModel ./scripts/save_best.sh
```

Then find the serial DDS algorithm block:

```text
BeginDDSAlg
PerturbationValue 0.20
MaxIterations 40
UseInitialParamValues
EndDDSAlg
```

**Deliverable:** the *Current Serial Workflow* section of your memo must address the following questions:
- Why can't the serial `DDS` algorithm be parallelized across optimization iterations?
- What opportunities still exist for parallelism when the optimization algorithm itself is serial?
- What, conceptually, must change in the optimization method to allow parallelism across optimization iterations?

## Part 2: Convert `ostIn.txt` to `ParallelDDS`

Open `ostIn.txt` and change the program type from serial DDS to `ParallelDDS`:

```diff
-ProgramType  DDS
+ProgramType  ParallelDDS
```

This tells OSTRICH to use the parallel version of the DDS algorithm, which generates multiple candidate parameter sets for evaluation in each iteration. Each candidate is evaluated by running the model, and these evaluations are performed in parallel using MPI, where one MPI rank coordinates the search and the other ranks are "workers" that run the model and report the objective function, which in this case is the Kling-Gupta Efficiency (KGE) metric.

Next, add a worker-directory prefix after `ModelExecutable`:

```diff
 ModelExecutable ./scripts/run_trial.sh
+ModelSubdir ostrich_worker_
```

This tells OSTRICH to create separate working directories such as `ostrich_worker_0`, `ostrich_worker_1`, and so on, for each MPI rank to write to as they run model simulations in parallel. Immediately after `ModelSubdir`, add a block that specifies the extra directories that each worker needs:

```diff
+BeginExtraDirs
+data
+model
+ostrich
+scripts
+EndExtraDirs
```

To specify the options for parallel calibration, replace the serial DDS algorithm block with a `ParallelDDS` block:

```diff
-BeginDDSAlg
+BeginParallelDDSAlg
 PerturbationValue 0.20
 MaxIterations 40
 UseInitialParamValues
-EndDDSAlg
+EndParallelDDSAlg
```

**Deliverable:** the *Parallelization Plan* section of your memo must address the following questions:

- Why do the worker directories need multiple copies of `data`, `model`, `ostrich`, and `scripts`?
- If the `MaxIterations` is kept fixed at 40 and we increase the number of MPI ranks, and the random seed is fixed, will the same parameter sets be evaluated in each run?

## Part 3: Convert the Launch Script to Slurm and MPI

Open `scripts/run_ostrich.sh` and modify it to submit a Slurm job that launches `OstrichMPI` with `srun`. The script should loop over 1, 2, and 4 model-evaluation workers. Because one extra MPI rank coordinates the OSTRICH search, each `srun` call should request one more total MPI task than the number of workers. The first scaling run therefore uses one model-evaluation worker and two total MPI ranks. This `nworkers=1` run is the baseline for the strong-scaling calculation:

```sh
#!/usr/bin/env bash
#SBATCH --job-name=parallel-calibration
#SBATCH --nodes=2
#SBATCH --ntasks=5
#SBATCH --ntasks-per-node=4
#SBATCH --time=08:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

job_id="${SLURM_JOB_ID:-local}"
timing_file="strong_scaling_times_${job_id}.csv"
printf "nworkers,ntasks,seconds\n" > "${timing_file}"

for worker_count in 1 2 4; do
    task_count=$((worker_count + 1))

    for runtime_path in ostrich_worker_* Ost*.txt model_run.log; do
        if [ -e "${runtime_path}" ]; then
            rm -rf -- "${runtime_path}"
        fi
    done

    echo "Running ParallelDDS with ${worker_count} worker(s) and ${task_count} MPI task(s)"
    start_time="$(date +%s)"
    srun --ntasks="${task_count}" OstrichMPI
    end_time="$(date +%s)"

    elapsed_seconds=$((end_time - start_time))
    printf "%s,%s,%s\n" "${worker_count}" "${task_count}" "${elapsed_seconds}" >> "${timing_file}"
done
```

`ParallelDDS` needs at least two MPI ranks because one rank coordinates the search and the other ranks evaluate model runs. The script therefore calculates the total MPI task count as `worker_count + 1`.

**Deliverable:** the *Slurm and MPI Implementation* section of your memo must identify the lines that request Slurm resources, the line that launches the MPI version of OSTRICH, the reason for calculating `task_count` from `worker_count`, why the one-worker case is the smallest scaling case, and the file that stores the timing results.

## Part 4: Run the Parallel Calibration

From the cluster login or head node where you made your edits, submit the job from the case directory:

```sh
cd /path/to/hydrolearn-hpc/bow_at_banff_lumped_calibration
sbatch scripts/run_ostrich.sh
```

Check the queue:

```sh
squeue
```

After the job finishes, inspect the Slurm log and archived best model:

```sh
ls slurm-*.out
less slurm-*.out
cat output_archive/KGE.txt
ls output_archive
```

## Part 5: Calculate Strong Scaling

Inspect the timing file:

```sh
ls strong_scaling_times_*.csv
cat strong_scaling_times_*.csv
```

Create a table with these columns:

```text
nworkers, ntasks, time_seconds, speedup, parallel_efficiency
```

Use:

```text
nworkers = ntasks - 1
```

because one MPI rank coordinates the OSTRICH search.

Use the `nworkers=1` run as the reference:

```text
speedup(nworkers) = time_seconds(nworkers=1) / time_seconds(nworkers)
```

Estimate efficiency relative to the number of model-evaluation workers:

```text
parallel_efficiency = speedup / nworkers
```

**Deliverable:** the *Scaling Results* section of your memo must report the timing file, the strong-scaling table, the speedup values, and the parallel efficiency values. Briefly interpret whether adding workers improved runtime and whether the speedup was close to ideal.

## Recommendation and Reflection

**Deliverable:** the *Recommendation and Reflection* section of your memo must address the following questions:

- What is the practical value of parallelizing this calibration workflow? How might the research group use this capability in their work?
- Are all requested Slurm resources used throughout the duration of the scaling study, or are some left idle?
- What changes could be made to improve resource utilization in this workflow?

## Final Submission

Submit one memo with the sections listed at the beginning of this activity.

**Deliverable:** the *Reproducibility Appendix* section of your memo must include:

- The final `ostIn.txt` and `scripts/run_ostrich.sh`.
- The Slurm job ID.
- The contents of `strong_scaling_times_<job_id>.csv`.
- The best KGE value from `output_archive/KGE.txt`.
