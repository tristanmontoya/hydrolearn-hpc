# Scenario 1: Parallel Execution of a Distributed Hydrologic Model

This scenario focuses on a distributed SUMMA-mizuRoute workflow for the watershed upstream of the `CAN_05BB001` gauge on the Bow River at Banff, Alberta, Canada. The watershed domain is divided into 52 spatial units called grouped response units (GRUs) to represent its spatial heterogeneity. In this model configuration, SUMMA simulates each GRU independently, and mizuRoute routes the resulting runoff to the basin outlet, where streamflow is compared with observations at the Banff gauge. The figure below shows the river network and GRUs used to represent the watershed:

![River network and GRUs of the Bow River basin upstream of the Banff streamflow gauge.](../figures/Bow_at_Banff_Dist.png)

The supplied workflow executes all GRUs serially in one SUMMA process. You will run this baseline model, modify the SUMMA portion to execute GRU batches concurrently, and evaluate how runtime and efficiency change as CPU cores are added.

The comparison between simulated and observed streamflow at the Banff gauge uses the modified Kling-Gupta efficiency (KGE') from [Kling et al. (2012)](https://doi.org/10.1016/j.jhydrol.2012.01.011) over the daily evaluation period from October 1, 2003, through September 30, 2005. The `scripts/calculate_run_diagnostics.py` diagnostic script computes:

$$
\mathrm{KGE}^{\prime} = 1 - \sqrt{(r - 1)^2 + (\gamma - 1)^2 + (\beta - 1)^2}.
$$

Here, $r$ is the correlation between simulated and observed streamflow, $\gamma=(\sigma_s/\mu_s)/(\sigma_o/\mu_o)$ is the coefficient-of-variation ratio, and $\beta=\mu_s/\mu_o$ is the mean bias ratio. The symbols $\mu_s$ and $\mu_o$ denote the simulated and observed means, while $\sigma_s$ and $\sigma_o$ denote the corresponding standard deviations. Larger KGE' values indicate better agreement between simulated and observed streamflow. After the simulation finishes, the script writes the resulting value to `results/KGE.txt`.

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

The `-g` option takes two arguments: the first is the starting GRU index, and the second is the number of consecutive GRUs to simulate (*not* the final GRU index). The script reads `n_gru` as the length of the `gru` dimension in `model/settings/SUMMA/attributes.nc`; it equals 52 for this domain, so `-g 1 "${n_gru}"` simulates GRUs 1 through 52. The `-r` option sets how often SUMMA writes restart files; the workflow uses `-r never` to disable restart file output.

Submit the baseline serial model run through Slurm:

```sh
sbatch scripts/submit_run.sh
```

Slurm will print a line such as `Submitted batch job 123456`. Record the job ID for the performance evaluation in Section 3. Use `squeue` to monitor the job status:

```sh
squeue -u "$USER" --Format=JobID,Name,StateCompact:4,TimeUsed:8,CPUsPerTask:12,NodeList
```

Inspect the Slurm output and KGE' diagnostic, and confirm that the streamflow comparison plot was created, replacing `123456` with the actual job ID:

```sh
cat slurm-bow-distributed-123456.out
cat slurm-bow-distributed-123456.err
cat results/KGE.txt
ls results/obs_vs_sim.png
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

Convert the workflow to execute two GRU batches concurrently by replacing the full-domain SUMMA call with two background processes, each executing half of the GRUs. Locate the serial SUMMA call in `scripts/run_SUMMA_mizuRoute.sh`:

```bash
"${summa_exe}" -m "${summa_filemanager}" -g 1 "${n_gru}" -r never
```

Replace this call with two Slurm job steps, each consisting of one task that executes a range of GRUs. The first job step below simulates GRUs 1 through 26, and the second simulates GRUs 27 through 52:

```bash
srun --ntasks=1 --exclusive \
    "${summa_exe}" -m "${summa_filemanager}" -g 1 26 -r never &
srun --ntasks=1 --exclusive \
    "${summa_exe}" -m "${summa_filemanager}" -g 27 26 -r never &
wait
```

Each `srun` command creates one Slurm job step within the job allocation, and the `&` operator runs that step in the background. The `wait` command prevents the workflow from proceeding to mizuRoute until both SUMMA job steps finish. The `--ntasks=1` argument ensures that each job step launches one SUMMA process instead of inheriting the job-level task count set in the Slurm submission script. The `--exclusive` option assigns distinct CPU resources to concurrent job steps so that they do not compete for CPU cores.

### 2.3 Modify the Slurm Submission Script

Update the Slurm submission script so the requested resources match the parallel workflow. In `scripts/submit_run.sh`, change the resource request from

```text
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
```

to the following:

```text
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
```

The `--ntasks` value should match the number of concurrent SUMMA job steps, while `--cpus-per-task` should remain 1 because each SUMMA process is single-threaded. Submit the two-core job:

```sh
sbatch scripts/submit_run.sh
```

Record the job ID for the performance evaluation in Section 3. This two-core run is the first parallel experiment and serves as the template for the remaining scaling experiments.

### 2.4 Additional CPU Core Counts

Choose and briefly justify a maximum CPU core count, $p_{\max}$, for your scaling study. The selected value must be at least 3 and must not exceed either 52, the number of GRUs used in this case, or the maximum number of CPU cores that Slurm can allocate to the workflow. If you are using the `vhpc-hydrotools` virtual cluster, $p_{\max}$ must also not exceed the smaller of 8 (the number of virtual CPU cores provided by the cluster) and the number of physical CPU cores on the host machine.

Including the completed serial and two-core runs, test every integer CPU core count from 1 through $p_{\max}$. For each additional core count, divide the 52 GRUs into approximately balanced batches, set `--ntasks` equal to the number of background SUMMA job steps, and keep `--cpus-per-task=1`. Before submitting each configuration, confirm that the GRU ranges cover GRUs 1 through 52 exactly once, without gaps or overlaps.

Run only one configuration at a time because each run writes to the same case directory. After each run, record the Slurm job ID and confirm that the KGE' value in `results/KGE.txt` matches the one-core result before continuing.

**Deliverable:** the *Parallelization* section of your memo must address the following questions:

- Why can independent GRUs execute concurrently?
- Why must both the workflow script **and** the Slurm submission script be modified?
- What maximum CPU core count did you choose, and why?
- How did you divide the 52 GRUs among CPU cores?

## 3. Performance Evaluation

Once all runs are complete, run `sacct` for each recorded job ID, replacing `123456` with the relevant job ID:

```sh
sacct -j 123456 --format=JobID,ReqCPUS,Elapsed
```

For each job, use the top-level row in the `sacct` output, not the `.batch` or `.extern` rows. Create a table with these columns:

- Slurm job ID
- Requested CPU cores (`ReqCPUS`)
- Wall-clock runtime (`Elapsed`)
- Speedup relative to the one-core case
- Strong-scaling efficiency with respect to CPU cores

Use the following formulas to compute the speedup and strong-scaling efficiency:

- Speedup relative to the one-core case: $S_p(N) = T_1(N) / T_p(N)$
- Strong-scaling efficiency with respect to CPU cores: $E_p(N) = S_p(N) / p$

Following the notation from Section 1.3 of this module, $N$ represents the fixed distributed simulation workload, $p$ is the requested number of CPU cores from the `ReqCPUS` field in the top-level Slurm accounting row, $T_1(N)$ is the one-core runtime, and $T_p(N)$ is the runtime using $p$ cores.

**Deliverable:** the *Performance Evaluation* section of your memo must include the completed strong-scaling table and address the following questions:

- Did adding CPU cores improve runtime?
- How closely did the measured speedup approach ideal linear speedup?
- What factors might have limited the strong-scaling efficiency of this distributed model execution workflow?
- How do the marginal runtime gains and strong-scaling efficiency change as CPU cores are added?

## 4. Recommendation and Reflection

**Deliverable:** the *Recommendation and Reflection* section of your memo must provide recommendations for a hydrologic modeling research group planning larger distributed simulations and address the following questions:

- What is the practical value of parallelizing this distributed model execution workflow, and how might the research group benefit from using this capability in their work?
- How could the research group use the scaling results from this study when selecting a resource layout for future distributed simulations?
- Do the results suggest a tradeoff between minimizing the absolute wall-clock runtime and using CPU resources efficiently? How might the research group balance these two objectives when planning future distributed simulations?

## 5. Reproducibility Appendix

At the end of your memo, include an appendix that contains the information needed to reproduce your results.

**Deliverable:** the *Reproducibility Appendix* section of your memo must include:

- The final versions of `scripts/run_SUMMA_mizuRoute.sh` and `scripts/submit_run.sh` used for the maximum CPU core count.
- The Slurm resource information from `sinfo -N -o "%N %P %c %t"` used to choose CPU core counts.
