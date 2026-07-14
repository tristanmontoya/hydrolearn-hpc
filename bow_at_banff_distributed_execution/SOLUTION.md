# Sample Solution: Scenario 1

## 1. Serial Workflow

SUMMA performs land-surface simulations independently for each GRU, while mizuRoute routes runoff through the river network.

The serial workflow iterates through all 52 GRUs and executes SUMMA once for each GRU (`countGRU=1`).

SUMMA is naturally parallelizable because GRUs are independent. Output concatenation, routing, and diagnostics remain serial.

Simply requesting more CPU cores from Slurm does not improve performance because the serial workflow runs/launches only one SUMMA process at a time.

---

## 2. Parallelization

Example two-core implementation:

```bash
"${summa_exe}" -m "${summa_filemanager}" -g 1 26 -r never &
"${summa_exe}" -m "${summa_filemanager}" -g 27 26 -r never &
wait
```

The Slurm submission script is also modified:

```diff
-#SBATCH --cpus-per-task=1
+#SBATCH --cpus-per-task=2
```

Both files must change:

- `run_SUMMA_mizuRoute.sh` determines how many processes execute.
- `submit_run.sh` reserves enough CPU resources for those processes.

Example balanced decompositions:

- 3 cores: 18,17,17 GRUs
- 4 cores: 13 GRUs each
- 8 cores: approximately 6–7 GRUs per core

---

## 3. Performance Evaluation

Example results:

| CPU Cores | Runtime (s) | Speedup | Efficiency |
|---:|---:|---:|---:|
|1|360|1.00|1.00|
|2|195|1.85|0.93|
|3|145|2.48|0.83|
|4|120|3.00|0.75|

Speedup becomes sublinear because of load imbalance, serial workflow components, file I/O, and process-launch overhead.

These are **strong-scaling** experiments because the workload (52 GRUs) remains fixed.

Fastest is not always best if resource efficiency matters. The optimal processor count is typically the point just before efficiency drops sharply.

---

## 4. Recommendation and Reflection

Domain decomposition substantially reduces runtime for distributed hydrologic simulations.

Scalability is eventually limited by Amdahl's Law, serial routing, output concatenation, and unequal GRU workloads.

Larger watersheds generally provide better scalability because there is more parallel work to distribute.

Before production runs, perform a scaling study to identify an efficient processor count instead of simply requesting the maximum available resources.


---

## 5. Reproducibility Appendix

Include:

- each experiment `run_SUMMA_mizuRoute.sh`
- each experiment `submit_run.sh`
- runtime and performance table
- CPU information. 
