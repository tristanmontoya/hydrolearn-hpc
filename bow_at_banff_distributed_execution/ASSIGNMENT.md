# Scenario 1: Parallel Execution of a Distributed Hydrologic Model

This scenario focuses on a distributed SUMMA-mizuRoute workflow for the watershed upstream of the `CAN_05BB001` gauge on the Bow River at Banff, Alberta, Canada. The watershed domain is divided into 52 spatial units called grouped response units (GRUs) to represent its spatial heterogeneity. In this model configuration, SUMMA simulates each GRU independently, and mizuRoute routes the resulting runoff to the basin outlet, where streamflow is compared with observations at the Banff gauge. The figure below shows the river network and GRUs used to represent the watershed:

![River network and GRUs of the Bow River basin upstream of the Banff streamflow gauge.](../figures/Bow_at_Banff_Dist.png)

The supplied workflow is a serial script that executes all GRUs in one SUMMA process. You will run the baseline model, modify the SUMMA portion to execute GRU batches at the same time, and evaluate how runtime and efficiency change as CPU cores are added.

The comparison between simulated and observed streamflow at the Banff gauge uses the modified Kling-Gupta efficiency ($\mathrm{KGE}^{\prime}$) from [Kling et al. (2012)](https://doi.org/10.1016/j.jhydrol.2012.01.011) over the daily evaluation period from October 1, 2003, through September 30, 2005. The `scripts/calculate_run_diagnostics.py` diagnostic script computes:

$$
\mathrm{KGE}^{\prime} = 1 - \sqrt{(r - 1)^2 + (\gamma - 1)^2 + (\beta - 1)^2},
$$

Here, $r$ is the correlation between simulated and observed streamflow, $\gamma=(\sigma_s/\mu_s)/(\sigma_o/\mu_o)$ is the coefficient-of-variation ratio, and $\beta=\mu_s/\mu_o$ is the mean bias ratio. The symbols $\mu_s$ and $\mu_o$ denote the simulated and observed means, while $\sigma_s$ and $\sigma_o$ denote the corresponding standard deviations. Larger KGE' values indicate better agreement between simulated and observed streamflow. After completing the simulation, the script writes the resulting value to `results/KGE.txt`.

## 1. Serial Workflow

If you are using the [`vhpc-hydrotools` virtual cluster](https://github.com/tristanmontoya/vhpc-hydrotools), change into the repository checkout:

```sh
cd /workspace/hydrolearn-hpc
```

If you are using another Slurm cluster, clone the repository yourself in a location of your choice:

```sh
git clone https://github.com/tristanmontoya/hydrolearn-hpc.git
cd hydrolearn-hpc
```

Then change into the case directory:

```sh
cd bow_at_banff_distributed_execution
```

Before editing anything, inspect the structure of the serial workflow. The workflow script executes SUMMA and mizuRoute, whereas the submission script requests computing resources from Slurm. Inspect the following files:

```
scripts/run_SUMMA_mizuRoute.sh
scripts/submit_run.sh
```

In `run_SUMMA_mizuRoute.sh`, one SUMMA process executes all GRUs:

```bash
"${summa_exe}" -m "${summa_filemanager}" -g 1 "${n_gru}" -r never
```

The `-g` option takes two arguments: the first is the starting GRU index, and the second is the number of consecutive GRUs to simulate (*not* the final GRU index). The script reads `n_gru` as the length of the `gru` dimension in `model/settings/SUMMA/attributes.nc`; it equals 52 for this domain, so `-g 1 "${n_gru}"` simulates GRUs 1 through 52. The `-r` option sets how often SUMMA writes restart files; in this case, we set `-r never` to disable restart file output.

Submit the baseline serial model run through Slurm:

```sh
sbatch scripts/submit_run.sh
```

Slurm will print a line such as `Submitted batch job 123456`. Replace `123456` with your job ID when checking the queue:

```sh
squeue -u "$USER" --Format=JobID,Name,StateCompact:4,TimeUsed:8,CPUsPerTask:12,NodeList
```

After the job finishes, use the same job ID to inspect the Slurm output and KGE' diagnostics:

```sh
cat slurm-bow-distributed-123456.out
cat slurm-bow-distributed-123456.err
cat results/KGE.txt
ls results/obs_vs_sim.png
```

Then record the requested CPU core count and runtime from Slurm accounting:

```sh
sacct -j 123456 --format=JobID,ReqCPUS,Elapsed
```

**Deliverable:** the *Serial Workflow* section of your memo must provide a high-level overview of the workflow and address the following questions:

- What are the roles of SUMMA and mizuRoute in this workflow?
- How does the serial workflow use `-g` to execute all 52 GRUs in one SUMMA process?
- Which parts of the workflow are naturally parallelizable?
- Why does requesting additional CPU cores through Slurm alone **not** speed up the serial workflow?

## 2. Parallelization

The figure below shows how independent spatial units can be distributed across CPU cores before output concatenation, post-processing, routing, and diagnostics:

![Illustration of a typical distributed hydrologic modeling workflow.](../figures/workflow_parallel_execution.png)

### 2.1 Determine Available Resources

Inspect the CPU resources that Slurm can allocate:

```sh
sinfo -N -o "%N %P %c %t"
```

The `-N` option prints one line per node. The `-o` option selects the output columns: `%N` is the node name, `%P` is the partition name, `%c` is the number of CPUs on the node, and `%t` is the node state. Use the `%c` values for the available nodes to identify the CPU cores that Slurm can allocate.

### 2.2 Modify the Workflow

Convert the workflow to execute two GRU batches simultaneously by replacing the full-domain SUMMA call with two background processes, each executing half of the total number of GRUs. To do this, locate the serial SUMMA call in `scripts/run_SUMMA_mizuRoute.sh`:

```bash
"${summa_exe}" -m "${summa_filemanager}" -g 1 "${n_gru}" -r never
```

Replace the above with two Slurm job steps, each consisting of one task that executes a range of GRUs. In the example below, the first job step simulates GRUs 1 through 26, while the second job step simulates GRUs 27 through 52:

```bash
srun --ntasks=1 --exclusive \
    "${summa_exe}" -m "${summa_filemanager}" -g 1 26 -r never &
srun --ntasks=1 --exclusive \
    "${summa_exe}" -m "${summa_filemanager}" -g 27 26 -r never &
wait
```

Each `srun` command creates one Slurm job step within the job allocation, and the `&` operator runs the job step in the background. The first job step simulates GRUs 1 through 26, while the second job step simulates GRUs 27 through 52. The `wait` command ensures that the workflow does not proceed to mizuRoute until both SUMMA job steps finish. The `--ntasks=1` argument ensures that each job step launches one SUMMA process instead of inheriting the job-level task count set in the Slurm job script, while the `--exclusive` option assigns distinct CPU resources to concurrent job steps so they do not compete for CPU cores.

### 2.3 Modify the Slurm Submission Script

Update the Slurm submission script so the requested resources match the parallel workflow. In `scripts/submit_run.sh`, change the resource request from

```text
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
```

to

```text
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
```

The `--ntasks` value should match the number of concurrent SUMMA job steps executing GRU batches, while `--cpus-per-task` should remain 1 because each SUMMA job step is single-threaded. Resubmit the job using `sbatch` and record the requested CPU core count and runtime from the top-level job row in the Slurm accounting output (not the `.batch` or `.extern` rows). This two-core run is the first parallel experiment and provides a template for the additional CPU core counts that you will use in the next section.

### 2.4 Additional CPU Core Counts

Repeat the experiment for 3, 4, and then each additional CPU core count up to the maximum number of CPU cores available across the Slurm nodes, using approximately balanced GRU assignments for each experiment. For each core count, set `--ntasks` equal to the number of background SUMMA job steps and keep `--cpus-per-task=1`. Including the serial and two-core cases, test each CPU core count from 1 through the maximum available. Before submitting each configuration, check that its GRU ranges cover GRUs 1 through 52 exactly once, without gaps or overlaps. After each run, check that the KGE' in `results/KGE.txt` matches the one-core result before continuing. On the `vhpc-hydrotools` virtual cluster, the maximum available count may be limited by the CPU cores on your local machine. Run one CPU core count at a time because each run writes to the same case directory.

**Deliverable:** the *Parallelization* section of your memo must address the following questions:

- Why can independent GRUs execute concurrently?
- Why must both the workflow script **and** the Slurm submission script be modified?
- How did you divide the 52 GRUs among CPU cores?

## 3. Performance Evaluation

After each job finishes, record the requested CPU core count and runtime using Slurm accounting output:

```sh
sacct -j 123456 --format=JobID,ReqCPUS,Elapsed
```

Use the top-level job rows in the `sacct` output, not the `.batch` or `.extern` rows. Based on the Slurm accounting output, create a table with these columns:

- Slurm job ID
- Requested CPU cores
- Wall-clock runtime from the Slurm accounting output
- Speedup relative to the one-core case
- Strong-scaling efficiency with respect to CPU cores

Use the following formulas to compute the speedup and strong-scaling efficiency:

- Speedup relative to the one-core case: $S_p(N) = T_1(N) / T_p(N)$
- Strong-scaling efficiency with respect to CPU cores: $E_p(N) = S_p(N) / p$

Following the notation from Section 1.3 of this module, $N$ represents the fixed distributed simulation workload, $p$ is the requested number of CPU cores from the `ReqCPUS` field in the top-level Slurm accounting row, $T_1(N)$ is the one-core runtime, and $T_p(N)$ is the runtime using $p$ cores.

**Deliverable:** the *Performance Evaluation* section of your memo must report the Slurm job IDs, the strong-scaling table, speedup values, and strong-scaling efficiency values. It must also address the following questions:

- Did adding CPU cores improve runtime?
- Was the speedup close to ideal?
- If the speedup was not ideal, what factors might have limited the strong-scaling efficiency of this distributed model execution workflow?
- How do the marginal runtime gains and strong-scaling efficiency change as CPU cores are added?

## 4. Recommendation and Reflection

**Deliverable:** the *Recommendation and Reflection* section of your memo must provide recommendations for a hydrologic modeling research group planning larger distributed simulations and address the following questions:

- What is the practical value of parallelizing this distributed model execution workflow, and how might the research group benefit from using this capability in their work?
- How could the research group use the scaling results from studies such as this one when selecting resource layout for future distributed simulations? 
- Do the results suggest a tradeoff between minimizing the absolute wall-clock runtime and using CPU resources efficiently? How might the research group balance these two objectives when planning future distributed simulations?

## 5. Reproducibility Appendix

At the end of your memo, include an appendix that contains the information needed to reproduce your results.

**Deliverable:** the *Reproducibility Appendix* section of your memo must include:

- The final versions of `scripts/run_SUMMA_mizuRoute.sh` and `scripts/submit_run.sh` used for the maximum CPU core count.
- The Slurm resource information from `sinfo -N -o "%N %P %c %t"` used to choose CPU core counts.
