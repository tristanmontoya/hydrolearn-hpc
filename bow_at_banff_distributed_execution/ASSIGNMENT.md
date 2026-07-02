# Part 1: Parallel Execution of a Distributed Hydrologic Model

## Deliverable

Assume you are a **research computing specialist** helping a hydrology research group improve the performance of a distributed **SUMMA–mizuRoute** workflow.

Convert the existing serial workflow into a parallel workflow using **domain decomposition**, evaluate its performance, and submit **one technical memo** (Markdown or PDF) with the following sections:

1. Serial Workflow
2. Parallelization by Domain Decomposition
3. Performance Evaluation
4. Recommendation and Reflection
5. Reproducibility Appendix

---

## 1. Serial Workflow

Inspect:

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

```bash
summa.exe -m master_file -g startGRU countGRU [-r freqRestart]
```

where:
- `startGRU` is the first GRU index
- `countGRU` is the number of consecutive GRUs to simulate
- `-r` is the restart control (e.g., `never` disables restart output)

In this workflow, each SUMMA model call uses:

```bash
-g "${gru_index}" 1
```

which means:

- `startGRU = gru_index`
- `countGRU = 1`

Therefore, each SUMMA execution simulates **exactly one GRU**.

Run the baseline model using SLURM:

```bash
sbatch scripts/submit_run.sh
```

Slurm will print a line such as `Submitted batch job 123456`. `123456` will be replaced with your job ID. After completion, record the runtime. 

Runtime can be found using:

```bash
sacct -j <jobid> --format=JobID,Elapsed
```
or:

```bash
seff <jobid>
```

**Deliverable** 

Describe:

- The role of SUMMA and mizuRoute.
- Why the serial workflow executes SUMMA once per GRU.
- Which parts of the workflow are naturally parallelizable?
- Why does requesting additional CPU cores through Slurm alone **not** speed up the serial workflow?

---

## 2. Parallelization by Domain Decomposition

### 2.1 Determine Available Resources

Determine the number of available CPU cores.

```bash
python -c "import os; print(os.cpu_count())"
```

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

Resubmit the job and record the runtime.

### 2.4 Additional Processor Counts

Repeat the experiment for 3, 4, and additional processor counts (up to the available cores).

Design approximately balanced GRU assignments for each experiment.

**Deliverable** 

Explain:

- Why independent GRUs can execute concurrently.
- Why both the workflow script **and** the Slurm submission script must be modified.
- How you divided the 52 GRUs among processors.

---

# 3. Performance Evaluation

Complete the following table.

| CPU Cores | Runtime(T_p) | Speedup S(p) | Parallel Efficiency E(p) |
|---:|---:|---:|---:|
|1|||| 
|2|||| 
|3|||| 
|4|||| 
|Max||||

Compute

- Speedup: S(p)=T1/Tp
- Parallel efficiency: E(p)=S(p)/p

Discuss:

- Does runtime decrease ideally?
- Is speedup linear as the number of cores increases?
- Are these strong- or weak-scaling experiments?
- Which processor count provides the best compromise between runtime and efficiency?

---

# 4. Recommendation and Reflection

Provide recommendations for a research group planning larger distributed simulations.

Discuss:

- major scalability bottlenecks;
- when adding processors becomes inefficient;
- whether larger watersheds (e.g., 1000 GURs) would benefit more from this strategy.

---

# 5. Reproducibility Appendix

Include:

- each experiment `run_SUMMA_mizuRoute.sh`
- each experiment `submit_run.sh`
- runtime and performance table
- CPU information. If you are unsure where to find this, run:
```bash
lscpu
```

