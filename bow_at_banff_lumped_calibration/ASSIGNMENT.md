# Part 2: Parallel Calibration of a Lumped Hydrologic Model

As in Part 1, this part of the activity will put you in the role of a **research computing specialist advising a hydrology research group**. You will start from a serial calibration workflow for a lumped hydrologic model, and you will convert it to a parallel workflow that uses **Slurm** and **MPI**. You will then run a simple scaling test to evaluate the performance of the parallel workflow, and you will write a memo to the research group that summarizes your work and provides recommendations for future use of the parallel workflow.

**Deliverable:** Complete the technical work below and submit one practical, concise memo with the following sections:

1. *Serial Workflow*
2. *Parallelization*
3. *Performance Evaluation*
4. *Recommendation and Reflection*
5. *Reproducibility Appendix*

The memo should be a single document that addresses all of the deliverables above, either as a **Markdown file** or a **PDF document**.

## 1. Serial Workflow

This activity uses **OSTRICH** (Optimization Software Toolkit for Research Involving Computational Heuristics) to calibrate a lumped model for the Bow River basin upstream of the Banff streamflow gauge based on the **SUMMA** (Structure for Unifying Multiple Modeling Alternatives) hydrologic model. The starting point is a serial calibration workflow that uses the Dynamically Dimensioned Search (`DDS`) algorithm.

Relative to the distributed execution workflow, the model setup is simplified here so that the calibration runs quickly enough for an instructional scaling test. The SUMMA model is configured in lumped form, where all spatial units are aggregated into a single basin representation. A separate routing model, which would normally combine the results from the spatial units to produce a single streamflow hydrograph, is not required in the lumped model.

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

Your goal is to modify this serial workflow so that it first runs safely through Slurm, and then runs `ParallelDDS` through Slurm and `OstrichMPI`. At this stage, focus on the structure of the serial workflow: OSTRICH chooses a candidate parameter set, `run_trial.sh` evaluates that candidate by running SUMMA and calculating KGE, and OSTRICH uses the result to choose the next candidate.

Before changing the optimizer, run the serial workflow as a scheduled Slurm job. Do not run the calibration directly on the login or head node, because even the serial calibration consumes shared resources for an extended period. Open `scripts/run_ostrich.sh` and modify it so that it remains a serial OSTRICH run, but is submitted through Slurm:

```sh
#!/usr/bin/env bash
#SBATCH --job-name=serial-calibration
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

ostrich
```

The `#SBATCH` lines request one Slurm task for the serial calibration. Submit the serial calibration from the case directory:

```sh
sbatch scripts/run_ostrich.sh
```

Slurm will print a line such as `Submitted batch job 123456`. Replace `123456` with your job ID when checking the queue:

```sh
squeue -j 123456
```

After the job finishes, use the same job ID to inspect the Slurm log and archived best model:

```sh
less slurm-serial-calibration-123456.out
cat output_archive/KGE.txt
ls output_archive
```

**Deliverable:** the *Serial Workflow* section of your memo must provide a high-level overview of the workflow and address the following questions:
- What would happen if we requested four Slurm tasks for the serial run, for example by setting `--ntasks=4`? Would the workflow run faster? Why or why not?
- What opportunities still exist for parallelism when the optimization algorithm itself is serial?
- What, conceptually, must change in the optimization method to allow parallelism across optimization iterations?

## 2. Parallelization

`ParallelDDS` is the OSTRICH parallel version of DDS. It can generate multiple candidate parameter sets during the optimization. Each candidate must still be evaluated by running SUMMA and calculating the objective function, but those model evaluations are independent of one another and can be assigned to separate MPI worker ranks.

Open `ostIn.txt`. The serial file needs three main changes:
1. Select the parallel DDS algorithm
2. Tell OSTRICH how to create worker directories
3. Replace the serial DDS algorithm block that specifies the parameters with a `ParallelDDS` block using the same parameters.

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

Next, open `scripts/run_ostrich.sh` again and modify the serial Slurm script so that it launches `OstrichMPI` with `srun`. Recall that the virtual cluster imitates a small Slurm cluster with two nodes, each with four cores, although in actuality it runs on your local machine and uses whatever resources are available. Since OSTRICH reserves one MPI rank to coordinate the search while the remaining ranks run the model, the script should request one more total task than the number of model-evaluation workers. Since we want to run a scaling study with 1, 2, and 4 model-evaluation workers, the script should request an allocation of 5 total tasks (`--ntasks=5`) so that the largest scaling case can run. If you have access to a Slurm cluster with more than 8 cores, you can request more tasks and assess scaling with even more workers, but that is not required for this activity.

As the script iterates over the worker counts, each `srun` call should request one more total task than the number of workers. The first scaling run therefore uses one model-evaluation worker and one coordinator, for a total of 2 MPI ranks. This `nworkers=1` run is the baseline for the strong-scaling calculation:

```sh
#!/usr/bin/env bash
#SBATCH --job-name=parallel-calibration
#SBATCH --nodes=2
#SBATCH --ntasks=5
#SBATCH --ntasks-per-node=4
#SBATCH --time=08:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Prevent accidental execution on the login node
if [ -z "${SLURM_JOB_ID:-}" ]; then
    echo "Submit this script with sbatch instead of running it on the login node" >&2
    exit 1
fi

# Use the executables available on PATH
export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

# Create a CSV file to store the strong scaling timings
job_id="${SLURM_JOB_ID:-local}"
timing_file="strong_scaling_times_${job_id}.csv"
printf "nworkers,ntasks,seconds\n" > "${timing_file}"

# ParallelDDS uses one coordinator rank in addition to the worker ranks
for worker_count in 1 2 4; do
    task_count=$((worker_count + 1))

    # Remove any leftover runtime files from previous runs
    for runtime_path in ostrich_worker_* Ost*.txt model_run.log; do
        if [ -e "${runtime_path}" ]; then
            rm -rf -- "${runtime_path}"
        fi
    done

    # Run the parallel calibration with the current worker count
    echo "Running ParallelDDS with ${worker_count} worker(s) and ${task_count} MPI task(s)"
    start_time="$(date +%s)"
    srun --ntasks="${task_count}" OstrichMPI
    end_time="$(date +%s)"

    # Calculate the elapsed time and write a line to the strong scaling CSV file
    elapsed_seconds=$((end_time - start_time))
    printf "%s,%s,%s\n" "${worker_count}" "${task_count}" "${elapsed_seconds}" >> "${timing_file}"
done
```

**Deliverable:** the *Parallelization* section of your memo must address the following questions:
- Why do the worker directories need multiple copies of `data`, `model`, `ostrich`, and `scripts`?
- If the `MaxIterations` is kept fixed at 40 and we increase the number of MPI ranks, and the random seed is fixed, will the same parameter sets be evaluated in each run?

## 3. Performance Evaluation

From the cluster login or head node where you made your edits, submit the job from the case directory:

```sh
cd /path/to/hydrolearn-hpc/bow_at_banff_lumped_calibration
sbatch scripts/run_ostrich.sh
```

Slurm will print a line such as `Submitted batch job 123456`. Replace `123456` with your job ID when checking the queue:

```sh
squeue -j 123456
```

After the job finishes, use the same job ID to inspect the Slurm log and archived best model:

```sh
less slurm-parallel-calibration-123456.out
cat output_archive/KGE.txt
ls output_archive
```

Inspect the timing file:

```sh
cat strong_scaling_times_123456.csv
```

Based on the timing file, create a table with these columns:

- Total MPI tasks
- Number of model-evaluation workers
- Runtime in seconds
- Speedup relative to the one-worker case
- Strong-scaling efficiency with respect to the number of workers

**Deliverable:** the *Performance Evaluation* section of your memo must report the timing file, the strong-scaling table, the speedup values, and the parallel efficiency values. Briefly interpret whether adding workers improved runtime and whether the speedup was close to ideal.

## 4. Recommendation and Reflection

**Deliverable:** the *Recommendation and Reflection* section of your memo must address the following questions:

- What is the practical value of parallelizing this calibration workflow? How might the research group use this capability in their work?
- Are all requested Slurm resources used throughout the duration of the scaling study, or are some left idle?
- What changes could be made to improve resource utilization in this workflow?

## 5. Reproducibility Appendix

At the end of your memo, include an appendix that contains the information needed to reproduce your results.

**Deliverable:** the *Reproducibility Appendix* section of your memo must include:

- The final `ostIn.txt` and `scripts/run_ostrich.sh`.
- The contents of `strong_scaling_times_<job_id>.csv`, where `<job_id>` is the Slurm job ID of your scaling study.
- The best KGE value from the final parallel run, in `output_archive/KGE.txt`.
