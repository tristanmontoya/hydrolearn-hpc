# Scenario 1: Parallel Execution of a Distributed Hydrologic Model

This activity focuses on a distributed SUMMA-mizuRoute workflow for the Bow River basin in Alberta, Canada. The watershed domain is divided into 52 spatial units called grouped response units (GRUs). In this model configuration, SUMMA simulates each GRU independently, and mizuRoute routes the resulting runoff to the basin outlet, where streamflow is compared to observations at the Banff streamflow gauge.

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

Before editing anything, inspect the structure of the serial workflow. The workflow script executes SUMMA and mizuRoute, while the submission script requests computing resources from Slurm. Inspect the following files:

```
scripts/run_SUMMA_mizuRoute.sh
scripts/submit_run.sh
```

In `run_SUMMA_mizuRoute.sh`, SUMMA is executed sequentially over all GRUs:

```bash
for gru_index in $(seq 1 "${n_gru}"); do
    "${summa_exe}" -g "${gru_index}" 1 -r never -m "${summa_filemanager}"
done
```

SUMMA can run a contiguous subset of GRUs with this command syntax.

```sh
summa.exe -m master_file -g startGRU countGRU [-r freqRestart]
```

In this command, `startGRU` is the first GRU index, `countGRU` is the number of consecutive GRUs to simulate, and `-r` controls restart output. For example, `-r never` disables restart output.

In this workflow, each SUMMA model call passes one GRU at a time.

```text
-g "${gru_index}" 1
```

This sets `startGRU = gru_index` and `countGRU = 1`, so each SUMMA execution simulates **exactly one GRU**.

Submit the baseline model through Slurm:

```sh
sbatch scripts/submit_run.sh
```

Slurm will print a line such as `Submitted batch job 123456`. Replace `123456` with your job ID. After completion, record the runtime from Slurm accounting:

```sh
sacct -j 123456 --format=JobID,Elapsed
```

**Deliverable:** the *Serial Workflow* section of your memo must provide a high-level overview of the workflow and address the following questions:

- What are the roles of SUMMA and mizuRoute in this workflow?
- Why does the serial workflow execute SUMMA once per GRU?
- Which parts of the workflow are naturally parallelizable?
- Why does requesting additional CPU cores through Slurm alone **not** speed up the serial workflow?

## 2. Parallelization

Figure 6 summarizes the computational pattern used in this scenario: independent spatial units can be distributed across processors before routing and output generation.

![Workflow diagram showing a hydrologic model run divided into independent spatial units that are distributed to processors or nodes before routing and output generation.](../figures/workflow_parallel_execution.png)

### 2.1 Determine Available Resources

Inspect the CPU resources that Slurm can allocate:

```sh
sinfo -N -o "%N %P %c %t"
```

The `-N` option prints one line per node. The `-o` option selects the output columns: `%N` is the node name, `%P` is the partition name, `%c` is the number of CPUs on the node, and `%t` is the node state. Use the `%c` column to identify how many CPU cores a node can provide. In this workflow, the parallel work is created by launching multiple SUMMA processes from one Slurm task, which is controlled by the `--cpus-per-task` option in the Slurm submission script. The maximum number of SUMMA processes that can be launched is equal to the number of CPU cores allocated to the task.

### 2.2 Modify the Workflow

Convert the workflow to execute two GRU batches simultaneously by replacing the serial SUMMA loop with two background processes. To do this, replace the serial loop

```bash
for gru_index in $(seq 1 "${n_gru}"); do
    "${summa_exe}" -g "${gru_index}" 1 -r never -m "${summa_filemanager}"
done
```

with two background SUMMA calls:

```bash
"${summa_exe}" -m "${summa_filemanager}" -g 1 26 -r never &
"${summa_exe}" -m "${summa_filemanager}" -g 27 26 -r never &
wait
```

The `&` operator launches each SUMMA process in the background, allowing both simulations to execute concurrently. The `wait` command then pauses the script until **both** SUMMA processes have completed before continuing to mizuRoute.

### 2.3 Modify the Slurm Submission Script

Update the Slurm submission script so the requested resources match the parallel workflow. In `scripts/submit_run.sh`, change the requested CPU count from

```text
#SBATCH --cpus-per-task=1
```

to

```text
#SBATCH --cpus-per-task=2
```

Resubmit the job and record the runtime. This two-core run is the first parallel experiment and provides a template for the additional processor counts below.

### 2.4 Additional Processor Counts

Repeat the experiment for 3, 4, and additional processor counts, up to the number of CPU cores available in your Slurm allocation. Design approximately balanced GRU assignments for each experiment.

**Deliverable:** the *Parallelization* section of your memo must address the following questions:

- Why can independent GRUs execute concurrently?
- Why must both the workflow script **and** the Slurm submission script be modified?
- How did you divide the 52 GRUs among processors?

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
- Strong scaling efficiency with respect to CPU cores: $E_p(N) = S_p(N) / p$

Here, $N$ is the fixed distributed simulation workload, $p$ is the number of CPU cores, $T_1(N)$ is the one-core runtime, and $T_p(N)$ is the runtime using $p$ cores.

Use the table and formulas to interpret the scaling behaviour.

**Deliverable:** the *Performance Evaluation* section of your memo must report the runtime and performance table, speedup values, and parallel efficiency values. It must also address the following questions:

- Did adding CPU cores improve runtime?
- Was the speedup close to ideal?
- Are these strong scaling or weak scaling experiments?
- Does adding CPU cores eventually become inefficient on this cluster?
- What processor count would you recommend for similar workflows run on the same cluster in the future?

## 4. Recommendation and Reflection

**Deliverable:** the *Recommendation and Reflection* section of your memo must provide recommendations for a research group planning larger distributed simulations and address the following questions:

- What are the major scalability bottlenecks in the workflow?
- How should the research group use the scaling results when choosing resources for future distributed simulations?
- How, if at all, would you expect parallel efficiency to change if the number of GRUs were increased to 100, 200, or more?

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
