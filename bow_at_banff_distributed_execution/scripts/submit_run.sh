#!/bin/bash
#SBATCH --job-name=bow-distributed
#SBATCH --output=slurm-%x-%j.out
#SBATCH --error=slurm-%x-%j.err
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=300MB

# run the workflow
./scripts/run_SUMMA_mizuRoute.sh
