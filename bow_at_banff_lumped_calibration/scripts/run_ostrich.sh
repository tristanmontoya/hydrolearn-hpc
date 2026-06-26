#!/usr/bin/env bash
#SBATCH --job-name=bow_at_banff_parallel_calibration
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --time=02:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Use the executables available on PATH
export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

echo "SLURM_NTASKS=$SLURM_NTASKS"
echo "SLURM_TASKS_PER_NODE=$SLURM_TASKS_PER_NODE"
echo "SLURM_JOB_NUM_NODES=$SLURM_JOB_NUM_NODES"

# Replaced `ostrich` with `OstrichMPI` to enable parallel calibration
srun -n $SLURM_NTASKS OstrichMPI
