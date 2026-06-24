#!/usr/bin/env bash
set -euo pipefail

# Resolve the basin directory from this runner location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
basin_dir="$(cd "${script_dir}/.." && pwd -P)"
repo_dir="$(cd "${basin_dir}/.." && pwd -P)"

# Use the basin directory as the base for OSTRICH and model paths
cd "${basin_dir}"

# Select the repository Python environment when available
python_exe="${PYTHON:-}"
if [ -z "${python_exe}" ]; then
    if [ -x "${repo_dir}/.venv/bin/python" ]; then
        python_exe="${repo_dir}/.venv/bin/python"
    elif command -v python3 >/dev/null 2>&1; then
        python_exe="python3"
    else
        python_exe="python"
    fi
fi

# Allow local hydrotools executables to be overridden
ostrich_exe="${OSTRICH_EXE:-ostrich}"
summa_exe="${SUMMA_EXE:-summa.exe}"

# Remove stale runtime logs for a fresh local calibration
rm -f Ost*.txt model_run.log

# Check executables before entering the calibration loop
if ! command -v "${ostrich_exe}" >/dev/null 2>&1; then
    echo "Missing OSTRICH executable: ${ostrich_exe}" >&2
    echo "Set OSTRICH_EXE to the full path of an OSTRICH binary." >&2
    exit 1
fi

if ! command -v "${summa_exe}" >/dev/null 2>&1; then
    echo "Missing SUMMA executable: ${summa_exe}" >&2
    echo "Set SUMMA_EXE to the full path of a SUMMA binary." >&2
    exit 1
fi

# Share executable choices with each OSTRICH trial
export PYTHON="${python_exe}"
export SUMMA_EXE="${summa_exe}"

"${ostrich_exe}"
