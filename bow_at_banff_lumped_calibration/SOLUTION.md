# Sample Solution: Parallel Calibration of a Lumped Hydrologic Model

This memo summarizes the completed conversion of the Bow River at Banff lumped SUMMA calibration workflow from a serial OSTRICH workflow to a Slurm and MPI workflow using `ParallelDDS`. **Note: this needs to be updated to reflect the recent changes to the assignment instructions.** 

## Serial Workflow

The original calibration workflow uses the serial `DDS` algorithm. In that workflow, OSTRICH proposes one candidate parameter set, `scripts/run_trial.sh` applies the multipliers, runs SUMMA, calculates KGE, and writes the result to `results/KGE.txt`. OSTRICH then uses that result to choose the next candidate parameter set.

Requesting more Slurm tasks for the serial `ostrich` executable would not make this workflow faster by itself. The serial optimizer evaluates one candidate at a time, so extra Slurm tasks would be allocated but unused unless some other part of the workflow explicitly used them.

There are still useful opportunities for parallelism around a serial optimizer. If the model is a parallelizable executable (for example, a distributed model that can run multiple spatial units at once), then we could run the calibration iterations in sequence, but with each model using multiple cores. Another approach is to run independent serial calibrations with different random seeds or different initial guesses. Those approaches increase throughput (i.e., the number of model simulations per unit time) but they do not make a single serial DDS optimization evaluate multiple candidates at the same time.

## Parallelization

The solution changes the OSTRICH configuration from `ProgramType DDS` to `ProgramType ParallelDDS`, adds `ModelSubdir ostrich_worker_`, adds `BeginExtraDirs` for `model`, `obs`, `ostrich`, and `scripts`, and replaces the DDS block with `BeginParallelDDSAlg`. The archive script also honours `OUTPUT_ARCHIVE_DIR`, so each worker-count run can preserve its own best model archive while serial runs still write to `output_archive/`. The launch script then uses `srun` to start `OstrichMPI` with the specified number of tasks.

Each MPI worker needs its own copies of the model inputs, scripts, generated SUMMA outputs, and KGE file so that independent model evaluations do not write to the same paths at the same time. Without those separate working directories, multiple MPI ranks could overwrite one another's parameter files, model outputs, or objective-function files.

The launch script calculates `task_count = worker_count + 1` because `ParallelDDS` uses one MPI rank as the OSTRICH coordinator and the remaining ranks as model-evaluation workers. The `nworkers=1` case therefore uses two MPI ranks and is the smallest valid `ParallelDDS` scaling case.

Even when keeping a fixed random seed and `MaxIterations = 40`, changing the number of workers can change the exact parameter sets evaluated. Since new parameter sets are proposed based on the results of previous evaluations, the search trajectory can diverge when the number of workers changes. The `nworkers=1` case evaluates one candidate at a time, while the `nworkers=2` and `nworkers=4` cases evaluate up to two and four candidates at a time, respectively. The optimizer will therefore propose different parameter sets, since it will have different KGE results to use in determining the next candidate.

## Performance Evaluation

The strong-scaling baseline is the one-worker `ParallelDDS` run, not the serial DDS run. This keeps the comparison within the same parallel algorithm and launch pathway.

Summary file: `strong_scaling_summary_6.csv`

| Total MPI Tasks | Model-Evaluation Workers | Runtime (s) | Speedup | Efficiency |
| ---: | ---: | ---: | ---: | ---: |
| 2 | 1 | 857 | 1.00 | 1.00 |
| 3 | 2 | 428 | 2.00 | 1.00 |
| 5 | 4 | 252 | 3.40 | 0.85 |

The speedup is calculated as `T_1 / T_N`, where `T_1` is the one-worker parallel runtime and `T_N` is the runtime with `N` model-evaluation workers. The strong-scaling efficiency is `speedup / N`.

Parallel calibration was found to significantly reduce wall time in this scaling study. The two-worker case was close to ideal scaling, while the four-worker case was faster than the baseline but below ideal scaling. This is expected because the coordinator rank performs search management, worker directories must be staged, file system activity increases, and different trial simulations may not take exactly the same amount of time.

The final `output_archive/KGE.txt` file contains the best KGE from the final four-worker run, not necessarily the best KGE across all scaling cases. The summary file reports best KGE values of `0.161631`, `0.353694`, and `0.263835` for the one-, two-, and four-worker runs, respectively. The best KGE observed across the scaling study was therefore `0.353694` from the two-worker run.

## Recommendation and Reflection

Parallelizing the calibration workflow is valuable because it can shorten turnaround time for calibration experiments, and it can increase the number of candidate parameter sets evaluated in a given experiment so as to improve the chance of finding a better solution.

With a faster calibration workflow, the group can run more experiments in the same amount of time, which allows them to explore different model structures (e.g., discretization options, process representations, or parameterizations), run multiple independent calibrations with different random seeds or initial guesses, and run sensitivity or uncertainty studies more rapidly. Increasing the number of candidate evaluations per unit time allows the group to more thoroughly explore the parameter space and converge to a better solution.

The scaling script requests enough resources for the largest run, which uses four model-evaluation workers and one coordinator. During the smaller scaling cases, some allocated tasks are idle: the one-worker case uses two MPI tasks, and the two-worker case uses three MPI tasks. This is acceptable for a small scaling study, but it is not the most efficient way to use a production allocation.

I recommend first running a short scaling study to choose an effective worker count, then submitting calibration jobs with only the resources needed for that worker count. For future scaling tests, each worker count could be submitted as a separate Slurm job or as a Slurm job array so that idle resources are not held during the smaller worker-count runs.

## Reproducibility Appendix

Final `ostIn.txt`:

```text
# Ostrich configuration file

# Use the parallel DDS optimizer
ProgramType  ParallelDDS
ModelExecutable ./scripts/run_trial.sh

# Stage rank-local working directories for model evaluations
ModelSubdir ostrich_worker_
ObjectiveFunction gcop

OstrichWarmStart no

PreserveModelOutput no
PreserveBestModel ./scripts/save_best.sh
OnObsError	-999

BeginFilePairs
ostrich/multipliers.tpl ; ostrich/multipliers.txt
EndFilePairs

# ParallelDDS copies these input directories into each worker directory
BeginExtraDirs
model
obs
ostrich
scripts
EndExtraDirs

#Parameter/DV Specification
BeginParams
#parameter	init	lwr	upr	txInN  txOst 	txOut fmt
k_soil_multp	1.000000	0.0716990	7.1698980	none	none	none	free
theta_sat_multp	1.000000	0.8245610	1.5037590	none	none	none	free
aquiferBaseflowExp_multp	1.000000	0.5000000	5.0000000	none	none	none	free
aquiferBaseflowRate_multp	1.000000	0.0000000	1.0000000	none	none	none	free
qSurfScale_multp	1.000000	0.0200000	2.0000000	none	none	none	free
summerLAI_multp	1.000000	0.0033330	3.3333330	none	none	none	free
frozenPrecipMultip_multp	1.000000	0.5000000	1.5000000	none	none	none	free
routingGammaScale_multp	1.000000	0.1000000	10.0000000	none	none	none	free
routingGammaShape_multp	1.000000	0.8000000	1.2000000	none	none	none	free
Fcapil_multp	1.000000	0.1666670	1.6666670	none	none	none	free
tempCritRain_multp	1.000000	0.9963390	1.0036610	none	none	none	free
heightCanopyBottom_multp	1.000000	0.0000000	100.0000000	none	none	none	free
windReductionParam_multp	1.000000	0.0000000	3.5714290	none	none	none	free
vGn_n_multp	1.000000	0.6793480	2.0380430	none	none	none	free
thickness_multp	1.000000	0.0526320	100.0000000	none	none	none	free
EndParams

BeginResponseVars
#name	  filename					keyword		line	col	token
KGE      ./results/KGE.txt;		OST_NULL	0		1  	 ' '
EndResponseVars

BeginTiedRespVars
NegKGE 1 KGE wsum -1.00
EndTiedRespVars

BeginGCOP
CostFunction NegKGE
PenaltyFunction APM
EndGCOP

BeginConstraints
# not needed when no constraints, but PenaltyFunction statement above is required
# name     type     penalty    lwr   upr   resp.var
EndConstraints

# Random seed control
RandomSeed 721734144

# Configure the parallel DDS search
BeginParallelDDSAlg
PerturbationValue 0.20
MaxIterations 40
UseInitialParamValues
EndParallelDDSAlg
```

Final `scripts/run_ostrich.sh`:

```sh
#!/usr/bin/env bash
#SBATCH --job-name=parallel-calibration
#SBATCH --nodes=2
#SBATCH --ntasks=5
#SBATCH --ntasks-per-node=4
#SBATCH --time=08:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Preserve best models in the original case directory
export PARALLEL_CALIBRATION_ROOT="${PWD}"

# Create a summary file for the scaling study
summary_file="strong_scaling_summary_${SLURM_JOB_ID}.csv"
archive_root="scaling_archive_${SLURM_JOB_ID}"
printf "nworkers,ntasks,seconds,best_kge,archive_dir\n" > "${summary_file}"
mkdir -p "${archive_root}"
cp ostIn.txt scripts/run_ostrich.sh "${archive_root}/"

# ParallelDDS uses one coordinator rank in addition to the worker ranks
for worker_count in 1 2 4; do
    # Calculate the total number of tasks needed for this worker count
    task_count=$((worker_count + 1))

    # Set the output archive directory for this worker-count run
    run_archive="${archive_root}/workers_${worker_count}"
    export OUTPUT_ARCHIVE_DIR="${PWD}/${run_archive}/output_archive"

    # Clean previous run artifacts
    rm -rf ostrich_worker_* Ost*.txt model_run.log "${run_archive}"

    # Make a fresh output archive directory
    mkdir -p "${OUTPUT_ARCHIVE_DIR}"

    # Start the timer for this worker-count run
    start_time="${SECONDS}"

    # Run the parallel calibration with the current worker count
    srun --ntasks="${task_count}" OstrichMPI

    # Calculate the elapsed time for this worker-count run
    elapsed_seconds=$((SECONDS - start_time))

    # Read the best KGE from the current run into the variable `best_kge`
    # or set `best_kge` to `NA` if the file does not exist
    best_kge="NA"
    if [ -f "${OUTPUT_ARCHIVE_DIR}/KGE.txt" ]; then
        read -r best_kge _ < "${OUTPUT_ARCHIVE_DIR}/KGE.txt"
    fi

    # Keep output_archive aligned with the latest completed run
    rm -rf output_archive
    cp -r "${OUTPUT_ARCHIVE_DIR}" output_archive

    printf "%s,%s,%s,%s,%s\n" "${worker_count}" "${task_count}" \
        "${elapsed_seconds}" "${best_kge}" "${run_archive}" >> "${summary_file}"
done
```

Slurm job ID: `6`

Summary file contents:

```csv
nworkers,ntasks,seconds,best_kge,archive_dir
1,2,857,0.161631,scaling_archive_6/workers_1
2,3,428,0.353694,scaling_archive_6/workers_2
4,5,252,0.263835,scaling_archive_6/workers_4
```

Best KGE from the final successful parallel run: `0.263835`
