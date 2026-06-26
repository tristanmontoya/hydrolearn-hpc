# Activity 2: Parallel Calibration of a Lumped Hydrologic Model

In this activity, you will take the role of a **research computing specialist advising a hydrology research group**. You will start from a serial calibration workflow for a lumped hydrologic model, and you will convert it to a parallel workflow that uses **Slurm** and **MPI**. You will then run a simple scaling test to evaluate the performance of the parallel workflow, and you will write a memo to the research group that summarizes your work and provides recommendations for future use of the parallel workflow.

**Deliverable:** Complete the technical work below and submit one practical, concise memo with the following sections:

1. *Current Serial Workflow*
2. *Parallelization Plan*
3. *Slurm and MPI Implementation*
4. *Scaling Results*
5. *Recommendation and Reflection*
6. *Reproducibility Appendix*

The memo should be a single document that addresses all of the deliverables above, either as a **Markdown file** or a **PDF created using LaTeX**. The following steps will guide you through the technical work required to complete this activity, and will describe the deliverables for each section of your memo.

## Step 1: Inspect the Serial Calibration Workflow

This activity uses **OSTRICH** (Optimization Software Toolkit for Research Involving Computational Heuristics) to calibrate a lumped model for the Bow River basin upstream of the Banff streamflow gauge based on the **SUMMA** (Structure for Unifying Multiple Modeling Alternatives) hydrologic model. The starting point is a serial calibration workflow that uses the Dynamically Dimensioned Search (`DDS`) algorithm.

The model setup is simplified so that the calibration runs quickly enough for an instructional scaling test. The SUMMA model is configured in lumped form, where all spatial units are aggregated into a single basin representation. The routing component is removed because explicit channel routing is not required in the lumped model.

If you are using the `vhpc-hydrotools` virtual cluster, change into the repository checkout:
```sh
cd /workspace/hydrolearn-hpc
```

If you are using another Slurm cluster, clone the repository yourself in a location of your choice:

```sh
git clone https://github.com/tristanmontoya/hydrolearn-hpc.git
cd hydrolearn-hpc
```

The `main` branch contains a working calibration workflow configured to use the serial DDS algorithm, which evaluates one candidate parameter set at a time. Before editing anything, it is important to understand the structure of the serial program. First, change into the case directory:

```sh
cd bow_at_banff_lumped_calibration
```

The following files are particularly relevant:
```
ostIn.txt
scripts/run_ostrich.sh
scripts/run_trial.sh
scripts/save_best.sh
```

The file `ostIn.txt` defines the OSTRICH calibration workflow, which currently uses `ProgramType DDS`, meaning that the serial dynamic dimensioned search algorithm is used. The `ModelExecutable` line points to `scripts/run_trial.sh`, which runs the SUMMA model and writes the objective function value to `results/KGE.txt`. The `PreserveBestModel` line points to `scripts/save_best.sh`, which copies the best trial parameter file and simulation output to the `output_archive/` directory.

The `scripts/run_ostrich.sh` shell script runs the entire workflow. It simply sets up the environment variables so the workflow can find the Python interpreter, SUMMA executable, and the current working directory, then launches the serial `ostrich` executable, which reads the `ostIn.txt` file and performs the calibration. The script is shown below:

```sh
#!/usr/bin/env bash
set -euo pipefail

export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

ostrich
```

Your goal is to modify this serial workflow so that it runs `ParallelDDS` through Slurm and `OstrichMPI`. At this stage, focus on the structure of the serial workflow: OSTRICH chooses a candidate parameter set, `run_trial.sh` evaluates that candidate by running SUMMA and calculating KGE, and OSTRICH uses the result to choose the next candidate.

**Deliverable:** the *Current Serial Workflow* section of your memo must provide a high-level overview of the workflow and address the following questions:
- Why can't the serial `DDS` algorithm be parallelized across optimization iterations?
- What opportunities still exist for parallelism when the optimization algorithm itself is serial?
- What, conceptually, must change in the optimization method to allow parallelism across optimization iterations?

## Step 2: Convert `ostIn.txt` to `ParallelDDS`

`ParallelDDS` is the OSTRICH parallel version of DDS. It can generate multiple candidate parameter sets during the optimization. Each candidate must still be evaluated by running SUMMA and calculating the objective function, but those model evaluations are independent of one another and can be assigned to separate MPI worker ranks.

Open `ostIn.txt`. The serial file needs three kinds of changes: select the parallel DDS algorithm, tell OSTRICH how to create worker directories, and replace the serial DDS algorithm block with the `ParallelDDS` block.

First, change the program type from serial DDS to `ParallelDDS`:

```diff
-ProgramType  DDS
+ProgramType  ParallelDDS
```

This changes the OSTRICH optimizer while keeping the model execution workflow intact.

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

Finally, replace the serial DDS algorithm block with a `ParallelDDS` block:

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

## Step 3: Convert the Launch Script to Slurm and MPI

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

## Step 4: Run the Parallel Calibration

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

## Step 5: Calculate Strong Scaling

Inspect the timing file:

```sh
ls strong_scaling_times_*.csv
cat strong_scaling_times_*.csv
```

Based on the timing file, create a table with these columns:

- Total MPI tasks
- Number of model-evaluation workers
- Runtime in seconds
- Speedup relative to the one-worker case
- Strong-scaling efficiency with respect to the number of workers

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
