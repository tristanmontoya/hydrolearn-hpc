# Sample Solution: Parallel Execution of a Distributed Hydrologic Model

## Serial Workflow

The original workflow executes the distributed SUMMA model sequentially over the 52 grouped response units (GRUs) representing the Bow River basin. For each GRU, SUMMA performs an independent land-surface simulation that generates runoff and other hydrologic fluxes. After all GRUs have been simulated, mizuRoute routes the generated runoff through the river network to the Banff streamflow gauge, where simulated streamflow is compared with observations to compute the modified Kling–Gupta efficiency (KGE').

Although the watershed is spatially distributed, the original implementation is entirely serial because the shell script launches one SUMMA process at a time. Each execution simulates a single GRU (`countGRU = 1`) before moving to the next GRU.

The SUMMA component is naturally parallelizable because GRUs are independent during the land-surface calculations. Each GRU can therefore be assigned to a different CPU core without affecting the results. In contrast, mizuRoute, diagnostic calculations, and output generation occur after all GRUs have finished and therefore remain serial components of the workflow.

Requesting additional CPU cores through Slurm alone does not reduce runtime because the workflow launches only one SUMMA process regardless of how many CPU cores are allocated. Slurm merely reserves additional hardware resources; the workflow itself must also be modified to execute multiple SUMMA processes concurrently.

## Parallelization

To parallelize the workflow, the serial SUMMA loop is replaced by multiple background SUMMA processes, each responsible for a subset of the 52 GRUs. For example, a two-core implementation divides the domain into two equal batches:

```bash
"${summa_exe}" -m "${summa_filemanager}" -g 1 26 -r never &
"${summa_exe}" -m "${summa_filemanager}" -g 27 26 -r never &
wait
```

The `&` operator launches each SUMMA process in the background so they execute simultaneously, while the `wait` command ensures that all SUMMA simulations finish before mizuRoute begins routing.

The Slurm submission script must also be modified so that the allocated computing resources match the parallel workflow:

```diff
-#SBATCH --cpus-per-task=1
+#SBATCH --cpus-per-task=2
```

Both files must be modified because they perform different roles. The workflow script determines how many SUMMA processes are launched, whereas the Slurm submission script reserves sufficient CPU cores for those processes. Changing only one of the two files would either leave CPU cores unused or oversubscribe the allocated resources.

The 52 GRUs should be divided as evenly as possible among CPU cores to minimize load imbalance. Example decompositions include 26–26 GRUs for two cores, 18–17–17 for three cores, 13 GRUs each for four cores, and approximately 6–7 GRUs per core for eight cores.

## Performance Evaluation

This exercise evaluates **strong scaling**, where the total computational workload remains fixed while the number of CPU cores increases. Speedup and parallel efficiency are computed as

$$
S_p(N)=\frac{T_1(N)}{T_p(N)}, \qquad
E_p(N)=\frac{S_p(N)}{p}
$$

where $$T_1$$ is the one-core runtime and $$p$$ is the number of allocated CPU cores.

An example summary is shown below.

| Slurm Job ID | CPU Cores | Runtime (s) | Speedup | Parallel Efficiency |
| ---: | ---: | ---: | ---: | ---: |
|101|1|360|1.00|1.00|
|102|2|195|1.85|0.93|
|103|3|145|2.48|0.83|
|104|4|120|3.00|0.75|

Adding CPU cores substantially reduces runtime, although the measured speedup is less than the ideal linear speedup. The primary reasons include serial components of the workflow (such as routing and diagnostics), process-launch overhead, filesystem I/O contention, and load imbalance caused by different GRUs requiring different amounts of computation.

As additional CPU cores are added, these overheads become increasingly important and eventually dominate the execution time. Consequently, there is typically a practical saturation point beyond which requesting additional CPU cores provides little additional reduction in wall-clock runtime. For production simulations, the preferred processor count is often the point just before this performance plateau.

## Recommendation and Reflection

Parallelizing distributed hydrologic simulations substantially reduces model turnaround time, enabling research groups to perform more calibration experiments, sensitivity analyses, uncertainty studies, and scenario simulations within a fixed amount of computing time.

Scaling studies such as this one provide valuable guidance for selecting processor counts in future production runs. Rather than always requesting the maximum available CPU cores, researchers should identify the point where additional resources no longer provide meaningful runtime reductions.

The results also demonstrate the tradeoff between minimizing absolute runtime and maximizing resource efficiency. Although the fastest execution is often obtained using the largest processor count, the highest parallel efficiency usually occurs with fewer CPU cores. Research groups should therefore balance scientific productivity, queue wait times, and efficient resource utilization when selecting computing resources for large distributed simulations.

## Reproducibility Appendix

Include the following information to reproduce the experiments:

- Final version of `scripts/run_SUMMA_mizuRoute.sh` for the maximum CPU-core configuration.
- Final version of `scripts/submit_run.sh`.
- Slurm resource information from `sinfo -N -o "%N %P %c %t"`.
- Runtime, speedup, and efficiency table for all scaling experiments.
- GRU decomposition used for each CPU-core count.
