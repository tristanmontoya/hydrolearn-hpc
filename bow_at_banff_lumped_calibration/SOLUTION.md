# Sample Solution: Parallel Calibration Of A Lumped Hydrologic Model

This memo summarizes the completed conversion of the Bow River at Banff lumped SUMMA calibration workflow from a serial OSTRICH workflow to a Slurm and MPI workflow using `ParallelDDS`.

## Serial Workflow

The original calibration workflow uses serial DDS. In that workflow, OSTRICH proposes one candidate parameter set, `scripts/run_trial.sh` applies the multipliers, runs SUMMA, calculates KGE, and writes the result to `results/KGE.txt`. OSTRICH then uses that result to choose the next candidate parameter set.

Requesting more Slurm tasks for the serial `ostrich` executable would not make this workflow faster by itself. The serial optimizer evaluates one candidate at a time, so extra Slurm tasks would be allocated but unused unless some other part of the workflow explicitly used them.

There are still useful opportunities for parallelism around a serial optimizer. We could parallelize the model executable itself, run independent calibrations with different random seeds, or run independent calibrations from different initial guesses. Those approaches increase throughput, but they do not make a single serial DDS optimization evaluate multiple candidates at the same time.

## Parallelization

The solution changes the OSTRICH configuration from `ProgramType DDS` to `ProgramType ParallelDDS`, adds `ModelSubdir ostrich_worker_`, adds `BeginExtraDirs` for `data`, `model`, `ostrich`, and `scripts`, and replaces the DDS block with `BeginParallelDDSAlg`. The launch script then uses `srun` to start `OstrichMPI`.

The worker directories are isolated per-rank sandboxes. Each MPI worker needs its own copies of the model inputs, scripts, generated SUMMA outputs, and KGE file so that independent model evaluations do not write to the same paths at the same time. Without those separate working directories, multiple MPI ranks could overwrite one another's parameter files, model outputs, or objective-function files.

The launch script calculates `task_count = worker_count + 1` because `ParallelDDS` uses one MPI rank as the OSTRICH coordinator and the remaining ranks as model-evaluation workers. The `nworkers=1` case therefore uses two MPI ranks and is the smallest valid `ParallelDDS` scaling case.

Even with a fixed random seed and `MaxIterations = 40`, changing the number of workers can change the exact parameter sets evaluated. The parallel algorithm can evaluate candidates in a different order and update the search trajectory differently as worker results return.

## Performance Evaluation

The strong-scaling baseline is the one-worker `ParallelDDS` run, not the serial DDS run. This keeps the comparison within the same parallel algorithm and launch pathway.

Timing file: `strong_scaling_times_<job_id>.csv`

| Total MPI Tasks | Model-Evaluation Workers | Runtime (s) | Speedup | Efficiency |
| ---: | ---: | ---: | ---: | ---: |
| 2 | 1 | `<T1>` | 1.00 | 1.00 |
| 3 | 2 | `<T2>` | `<T1 / T2>` | `<(T1 / T2) / 2>` |
| 5 | 4 | `<T4>` | `<T1 / T4>` | `<(T1 / T4) / 4>` |

The speedup is calculated as `T_1 / T_N`, where `T_1` is the one-worker parallel runtime and `T_N` is the runtime with `N` model-evaluation workers. The strong-scaling efficiency is `speedup / N`.

Parallel calibration should reduce wall time when independent SUMMA model evaluations dominate the cost. Speedup will usually be less than ideal because the coordinator rank performs search management, worker directories must be staged, filesystem activity increases, and different trial simulations may not take exactly the same amount of time.

## Recommendation And Reflection

Parallelizing the calibration workflow is valuable because it can shorten turnaround time for calibration experiments and make broader research studies feasible. With a faster workflow, the group can test more parameterizations, explore multiple random seeds, compare different initial guesses, and run sensitivity or uncertainty studies with less waiting time between decisions.

The scaling script requests enough resources for the largest run, which uses four model-evaluation workers and one coordinator. During the smaller scaling cases, some allocated tasks are idle: the one-worker case uses two MPI tasks, and the two-worker case uses three MPI tasks. This is acceptable for a compact instructional scaling study, but it is not the most efficient way to use a production allocation.

For production use, I recommend first running a short scaling study to choose an effective worker count, then submitting calibration jobs with only the resources needed for that worker count. For future scaling tests, each worker count could be submitted as a separate Slurm job or as a Slurm job array so that idle resources are not held during the smaller cases.

## Reproducibility Appendix

Final configuration files:

- `ostIn.txt`
- `scripts/run_ostrich.sh`

Slurm job ID: `<job_id>`

Timing file contents:

```csv
nworkers,ntasks,seconds
1,2,<T1>
2,3,<T2>
4,5,<T4>
```

Best KGE from the final successful parallel run: `<best_kge>`

The value in `output_archive/KGE.txt` is the best KGE preserved by the final successful parallel run. It is not necessarily the best KGE across all scaling cases unless each scaling case is archived separately and compared afterward.
