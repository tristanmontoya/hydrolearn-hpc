#!/bin/bash
#SBATCH --job-name=summa_distributed
#SBATCH --output=summa_%j.out
#SBATCH --error=summa_%j.err
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=300MB

# run the workflow
./scripts/run_SUMMA_mizuRoute.sh
