#!/usr/bin/env bash
#SBATCH --job-name=bow_lumped_pdds
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --ntasks-per-node=2
#SBATCH --mem-per-cpu=400M
#SBATCH --time=02:00:00
#SBATCH --output=slurm-%x-%j.out
set -euo pipefail

# Use the executables available on PATH
export PYTHON="${PYTHON:-python}"
export SUMMA_EXE="${SUMMA_EXE:-summa.exe}"
export PARALLEL_CALIBRATION_ROOT="${PWD}"

# Start OSTRICH
srun --kill-on-bad-exit=1 OstrichMPI
