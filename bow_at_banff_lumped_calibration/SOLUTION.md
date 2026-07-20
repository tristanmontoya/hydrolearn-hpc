# Sample Solution: Parallel Calibration of a Lumped Hydrologic Model

This memo summarizes the conversion of the Bow River at Banff lumped SUMMA calibration workflow from a serial dynamically dimensioned search (DDS) optimization workflow using OSTRICH to a Slurm and MPI workflow using the parallel DDS algorithm.

The results reported in this memo were obtained on the [`vhpc-hydrotools`](https://github.com/tristanmontoya/vhpc-hydrotools) virtual HPC cluster.

## Serial Workflow

The original workflow uses the serial DDS algorithm. In each iteration, OSTRICH proposes one candidate parameter set, `scripts/run_trial.sh` applies its parameter multipliers, SUMMA simulates streamflow, and the diagnostics script calculates the modified Kling-Gupta efficiency (KGE') over the aligned daily period from October 1, 2003, through September 30, 2005. OSTRICH uses the value written to `results/KGE.txt` to guide the search.

Requesting additional Slurm tasks for the serial `ostrich` executable would not make the calibration faster. Slurm would reserve the requested resources, but the serial optimizer would still evaluate one candidate at a time. A serial optimizer could still use a parallel model executable within each evaluation, or several independent serial calibrations could run concurrently with different random seeds or initial values. However, neither approach parallelizes the iterations of one DDS search. Parallelism across optimization iterations requires an algorithm that can evaluate multiple candidates at a time. The parallel DDS algorithm provides this capability by assigning independent model evaluations to MPI worker ranks under the management of a coordinator rank.

## Parallelization

To parallelize the calibration, the top-level `ostIn.txt` configuration file is modified by changing `ProgramType DDS` to `ProgramType ParallelDDS`, adding `ModelSubdir ostrich_worker_`, adding a `BeginExtraDirs`/`EndExtraDirs` block for `model`, `obs`, `ostrich`, and `scripts`, and replacing the serial `BeginDDSAlg`/`EndDDSAlg` block with a `BeginParallelDDSAlg`/`EndParallelDDSAlg` block. `ModelSubdir` specifies the rank-local directory prefix, whereas the `BeginExtraDirs`/`EndExtraDirs` block identifies the directories copied into each rank-local working directory. The launch script uses `srun` to start `OstrichMPI` with the task count requested from Slurm.

Each worker needs a separate working directory because every evaluation modifies parameter files and writes SUMMA output, diagnostics, and `results/KGE.txt` using the same relative paths. Rank-local copies prevent workers from overwriting one another's files. The worker directories also preserve the relative path structure expected by the existing scripts.

The parallel DDS algorithm reserves one MPI rank as the coordinator. A run with $p$ model-evaluation workers therefore requires $p+1$ MPI tasks. The smallest scaling case uses two tasks: one coordinator and one worker.

Keeping `RandomSeed 721734144` and `MaxIterations 40` fixed does not guarantee that every worker count evaluates the same parameter sets. Parallel DDS is asynchronous: candidate generation depends on the results available when a worker becomes free. Changing the number and completion order of concurrent evaluations changes the information available when later candidates are proposed, so the search trajectories and best KGE' values can diverge.

## Performance Evaluation

We use the one-worker parallel DDS run as the scaling baseline so that every case uses the same optimizer and MPI launch pathway. This is an instructional worker-scaling comparison with a fixed 40-evaluation optimization budget, not strict strong scaling of an identical computational workload, because the asynchronous searches can evaluate different parameter sets with different execution costs. The speedup and efficiency are

$$
S_p(N)=\frac{T_1(N)}{T_p(N)}, \qquad E_p(N)=\frac{S_p(N)}{p},
$$

where $p$ is the number of model-evaluation workers and $T_1=1350\ \mathrm{s}$, corresponding to the one-worker case. The results are summarized in the following table:

| Slurm Job ID | Total MPI Tasks | Model-Evaluation Workers | Best KGE' | Runtime (s) | Speedup | Parallel Efficiency |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 35 | 2 | 1 | 0.161631 | 1350 | 1.00 | 1.00 |
| 36 | 3 | 2 | 0.353694 | 613 | 2.20 | 1.10 |
| 37 | 4 | 3 | 0.147019 | 485 | 2.78 | 0.93 |
| 38 | 5 | 4 | 0.263835 | 244 | 5.53 | 1.38 |
| 39 | 6 | 5 | 0.591202 | 264 | 5.11 | 1.02 |
| 40 | 7 | 6 | 0.329875 | 254 | 5.31 | 0.89 |
| 41 | 8 | 7 | 0.374028 | 270 | 5.00 | 0.71 |

Adding model-evaluation workers substantially improves runtime through the four-worker case. Runtime decreases from 1350 seconds with one worker to 244 seconds with four workers, corresponding to a measured speedup of 5.53.

The measured speedup is not consistently close to an ideal linear speedup. The three-worker case achieves a speedup of 2.78 compared with an ideal value of 3, whereas the seven-worker case achieves a speedup of 5.00 compared with an ideal value of 7. The apparent efficiencies above one in the two- and four-worker cases should not be interpreted as conclusive evidence of superlinear scaling. One possible explanation is that the evaluated parameter sets can have different model-execution costs.

Several factors limit parallel efficiency in this workflow. In OSTRICH, the coordinator performs serial search-management work that can delay the dispatch of new candidates to workers. The coordinator also performs serial work at the end of the search, including rerunning the best parameter set to generate model output for archiving. Furthermore, launching MPI ranks and staging worker directories adds overhead, and concurrent workers contend for CPU and file-system resources while reading and writing NetCDF files and diagnostics. Workers left idle due to load imbalance also reduce efficiency; even for an asynchronous algorithm, this can occur at the end of the search when there are fewer remaining candidates than workers, or when workers evaluate parameter sets with different execution costs. Finally, a fixed optimization budget of 40 evaluations provides progressively fewer evaluations per worker as the worker count increases.

For these measurements, the practical saturation point appears to be four model-evaluation workers, or five total MPI tasks. The five-, six-, and seven-worker cases take 264, 254, and 270 seconds, respectively, compared with 244 seconds for four workers. Beyond four workers, additional overhead, resource contention, and load imbalance outweigh the benefit of distributing evaluations among more workers.

## Recommendation and Reflection

Parallelizing the calibration workflow is valuable because it increases model-evaluation throughput and shortens the turnaround time for calibration experiments. The present scaling cases each retain the same 40-evaluation optimization budget, but completing those evaluations sooner allows the group to run more independent calibrations, sensitivity studies, or model-structure experiments in a fixed amount of time.

Each worker count should be a separate Slurm job because this gives every case an explicit resource request, its own job ID and accounting record, and an isolated archive. A single allocation sized for the largest case would leave resources idle during smaller cases and obscure per-case elapsed times.

Varying the number of model-evaluation workers results in different objective function values because the asynchronous parallel DDS algorithm's candidate generation depends on the results available when a worker becomes free. Since the 40-evaluation optimization budget remains fixed, it is not guaranteed that adding workers will improve the best candidate found. The best KGE' values in this study range from 0.147019 to 0.591202 across the seven scaling cases. The highest KGE' is 0.591202 from the five-worker run, but this does not establish five workers as statistically better for calibration quality. Multiple calibrations with independent random seeds would be required to compare solution quality for different worker counts.

Although a fixed 40-evaluation budget is used across worker counts, the fact that different worker counts follow different search trajectories means that the total cost of the 40 evaluations can differ, as certain parameter sets can take longer to evaluate than others. As such, this study does not strictly measure strong scaling of a fixed workload, but rather the effect of worker count on the time to complete a fixed number of candidate evaluations, which can be viewed as a practical measure of throughput for the research group.

For future calibration studies, the group should perform a short scaling study before production runs and select a worker count near the point where additional workers cease to reduce runtime, if such a point exists. The highest-throughput configuration and the most resource-efficient configuration may differ, so the research group should also consider the total time to solution and practical constraints such as queue wait times and resource availability when selecting a worker count for production runs.

## Reproducibility Appendix

Final OSTRICH configuration file `ostIn.txt`:

```text
# Ostrich configuration file

ProgramType  ParallelDDS
ModelExecutable ./scripts/run_trial.sh
ModelSubdir ostrich_worker_
ObjectiveFunction gcop

OstrichWarmStart no

PreserveModelOutput no
PreserveBestModel ./scripts/save_best.sh
OnObsError	-999

BeginFilePairs
ostrich/multipliers.tpl ; ostrich/multipliers.txt
EndFilePairs

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

BeginParallelDDSAlg
PerturbationValue 0.20
MaxIterations 40
UseInitialParamValues
EndParallelDDSAlg
```

Final Slurm launch script `run_ostrich.sh`:

```sh
#!/usr/bin/env bash
#SBATCH --job-name=bow-lumped-calib
#SBATCH --ntasks=8
#SBATCH --time=01:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Use the submission directory as the source case
case_dir="${SLURM_SUBMIT_DIR:-${PWD}}"

# Run each job in a separate copied case directory
run_dir="${case_dir}/scaling_archive_${SLURM_JOB_ID}"
mkdir -p "${run_dir}"
cp -R "${case_dir}/ostIn.txt" "${case_dir}/model" "${case_dir}/obs" \
    "${case_dir}/ostrich" "${case_dir}/scripts" "${run_dir}/"
cd "${run_dir}"

# Archive best models inside this job directory
export PARALLEL_CALIBRATION_ROOT="${PWD}"
export OUTPUT_ARCHIVE_DIR="${PWD}/output_archive"

# Run the parallel calibration with all allocated tasks
srun --ntasks="${SLURM_NTASKS}" OstrichMPI
```

Virtual cluster resources reported by `sinfo -N -o "%N %P %c %t"`:

```text
NODELIST      PARTITION CPUS STATE
slurm-worker1 debug*       4 idle
slurm-worker2 debug*       4 idle
```
