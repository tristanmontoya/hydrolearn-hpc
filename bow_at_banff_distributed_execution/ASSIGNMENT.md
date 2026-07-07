# Scenario 1: Parallel Execution of a Distributed Hydrologic Model

Read the shared [Activity Overview](../ASSIGNMENT.md) before starting this activity. It defines the scenario, learning objectives, and common memo deliverable.

This activity focuses on a distributed SUMMA-mizuRoute workflow for the Bow River at Banff case. The watershed domain is divided into 52 spatial units called grouped response units (GRUs). SUMMA simulates each GRU independently, and mizuRoute routes the resulting runoff to the basin outlet.

The workflow is currently implemented as a serial script that executes SUMMA once per GRU. Starting from this serial workflow, you will run the baseline model, modify the SUMMA portion to execute multiple GRUs at the same time, and evaluate how runtime and efficiency change as CPU cores are added.

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

Inspect the following files:

```
scripts/run_SUMMA_mizuRoute.sh
scripts/submit_run.sh
```

The workflow script executes SUMMA and mizuRoute, while the submission script requests computing resources from Slurm.

In `run_SUMMA_mizuRoute.sh`, SUMMA is executed sequentially over all GRUs using:

```bash
for gru_index in $(seq 1 "${n_gru}"); do
    "${summa_exe}" -g "${gru_index}" 1 -r never -m "${summa_filemanager}"
done
```

SUMMA supports running a subset of GRUs using the command:

```sh
summa.exe -m master_file -g startGRU countGRU [-r freqRestart]
```

where:
- `startGRU` is the first GRU index
- `countGRU` is the number of consecutive GRUs to simulate
- `-r` is the restart control (e.g., `never` disables restart output)

In this workflow, each SUMMA model call uses:

```text
-g "${gru_index}" 1
```

which means:

- `startGRU = gru_index`
- `countGRU = 1`

Therefore, each SUMMA execution simulates **exactly one GRU**.

Run the baseline model using Slurm:

```sh
sbatch scripts/submit_run.sh
```

Slurm will print a line such as `Submitted batch job 123456`. Replace `123456` with your job ID. After completion, record the runtime.

Runtime can be found using:

```sh
sacct -j 123456 --format=JobID,Elapsed
```
or:

```sh
seff 123456
```

**Deliverable:** the *Serial Workflow* section of your memo must provide a high-level overview of the workflow and address the following questions:

- What are the roles of SUMMA and mizuRoute in this workflow?
- Why does the serial workflow execute SUMMA once per GRU?
- Which parts of the workflow are naturally parallelizable?
- Why does requesting additional CPU cores through Slurm alone **not** speed up the serial workflow?

---

## 2. Parallelization

The diagram below summarizes the computational pattern used in this scenario: independent spatial units can be distributed across processors before routing and output generation.

![Workflow diagram showing a hydrologic model run divided into independent spatial units that are distributed to processors or nodes before routing and output generation.](../figures/workflow_parallel_execution.png)

### 2.1 Determine Available Resources

Inspect the CPU resources that Slurm can allocate:

```sh
sinfo -N -o "%N %P %c %t"
```

The `-N` option prints one line per node. The `-o` option selects the output columns:

- `%N`: node name
- `%P`: partition name
- `%c`: number of CPUs on the node
- `%t`: node state

Use the `%c` column to identify how many CPU cores a node can provide. In this workflow, the parallel work is created by launching multiple background SUMMA processes from one Slurm task.

For each experiment, set `--cpus-per-task` equal to the number of concurrent SUMMA processes you plan to launch. Do not test more processors than the allocated node can provide. On the `vhpc-hydrotools` virtual cluster, use small processor counts such as 1, 2, 3, and 4. On an actual Slurm cluster, use processor counts that are allowed by the partition, account, and allocation limits for the system you are using.

### 2.2 Modify the Workflow

Convert the workflow to execute two GRU batches simultaneously by replacing the serial SUMMA loop with two background processes.

Replace the serial loop:

```bash
for gru_index in $(seq 1 "${n_gru}"); do
    "${summa_exe}" -g "${gru_index}" 1 -r never -m "${summa_filemanager}"
done
```

with:

```bash
"${summa_exe}" -m "${summa_filemanager}" -g 1 26 -r never &
"${summa_exe}" -m "${summa_filemanager}" -g 27 26 -r never &
wait
```

- `&` launches a process in the background so that both SUMMA simulations execute concurrently.
- `wait` pauses the script until **both** SUMMA processes have completed before continuing to mizuRoute.

### 2.3 Modify the Slurm Submission Script

Update the Slurm submission script so the requested resources match the parallel workflow.

For example, modify

```text
#SBATCH --cpus-per-task=1
```

to

```text
#SBATCH --cpus-per-task=2
```

Resubmit the job and record the runtime. This two-core run is the first parallel experiment and provides a template for the additional processor counts below.

### 2.4 Additional Processor Counts

Repeat the experiment for 3, 4, and additional processor counts, up to the CPU cores available in your Slurm allocation.

Design approximately balanced GRU assignments for each experiment.

**Deliverable:** the *Parallelization* section of your memo must address the following questions:

- Why can independent GRUs execute concurrently?
- Why must both the workflow script **and** the Slurm submission script be modified?
- How did you divide the 52 GRUs among processors?

---

## 3. Performance Evaluation

Complete the following table.

| CPU Cores | Runtime | Speedup | Parallel Efficiency |
|---:|---:|---:|---:|
|1||||
|2||||
|3||||
|4||||
|Largest Tested||||

Compute the following quantities:

- Speedup relative to the one-core case: $S_p(N) = T_1(N) / T_p(N)$
- Strong-scaling efficiency with respect to CPU cores: $E_p(N) = S_p(N) / p$

Here, $N$ is the fixed distributed simulation workload, $p$ is the number of CPU cores, $T_1(N)$ is the one-core runtime, and $T_p(N)$ is the runtime using $p$ cores.

Discuss:

- Did adding CPU cores improve runtime?
- Was the speedup close to ideal?
- Are these strong-scaling or weak-scaling experiments?
- Which processor count provides the best compromise between runtime and efficiency?

**Deliverable:** the *Performance Evaluation* section of your memo must report the runtime and performance table, the speedup values, and the parallel efficiency values. Briefly interpret whether adding CPU cores improved runtime and whether the speedup was close to ideal.

---

## 4. Recommendation and Reflection

**Deliverable:** the *Recommendation and Reflection* section of your memo must provide recommendations for a research group planning larger distributed simulations and address the following questions:

- What are the major scalability bottlenecks?
- When does adding processors become inefficient?
- Would larger watersheds, for example 1000 GRUs, benefit more from this strategy?

---

## 5. Reproducibility Appendix

At the end of your memo, include an appendix that contains the information needed to reproduce your results.

**Deliverable:** the *Reproducibility Appendix* section of your memo must include:

- The version of `run_SUMMA_mizuRoute.sh` used for each processor count.
- The version of `submit_run.sh` used for each processor count.
- The runtime and performance table.
- The Slurm resource information used to choose processor counts:

```sh
sinfo -N -o "%N %P %c %t"
```
