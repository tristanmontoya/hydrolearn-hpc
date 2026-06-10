#!/usr/bin/env bash
set -euo pipefail

# Use the basin directory as the base for relative model paths
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
basin_dir="$(cd "${script_dir}/.." && pwd -P)"
cd "${basin_dir}"

# Read settings provided by the model runner
summa_exe="${SUMMA_EXE:-summa.exe}"
summa_filemanager="${SUMMA_FILEMANAGER:-model/settings/SUMMA/fileManager.txt}"
n_gru="${N_GRU:?N_GRU must be set by run_SUMMA_MizuRoute.sh}"

# Run each GRU sequentially
for gru_index in $(seq 1 "${n_gru}"); do
    "${summa_exe}" -g "${gru_index}" 1 -r never -m "${summa_filemanager}"
done
