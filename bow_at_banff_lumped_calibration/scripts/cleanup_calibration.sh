#!/usr/bin/env bash
set -euo pipefail

# Resolve the calibration case directory from this script location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
case_dir="$(cd "${script_dir}/.." && pwd -P)"

# Remove runtime scratch files while preserving output_archive
cd "${case_dir}"
for runtime_path in ostrich_worker_* Ost*.txt model_run.log slurm-*.out; do
    if [ -e "${runtime_path}" ]; then
        rm -rf -- "${runtime_path}"
    fi
done
