#!/usr/bin/env bash
set -euo pipefail

# Resolve the basin directory from this archive script location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
basin_dir="$(cd "${script_dir}/.." && pwd -P)"
case_dir="${PARALLEL_CALIBRATION_ROOT:-${basin_dir}}"

# Use the basin directory as the base for relative model paths
cd "${basin_dir}"

# Define local model and output paths
summa_filemanager="model/settings/SUMMA/fileManager.txt"
trial_param_file="model/settings/SUMMA/trialParams.nc"
output_archive="${OUTPUT_ARCHIVE_DIR:-${case_dir}/output_archive}"
results_dir="results"

# Read a setting from the SUMMA file manager
read_from_summa_config() {
    local input_file="$1"
    local setting="$2"
    local line
    local info

    line="$(grep -m 1 "^${setting}" "${input_file}")"
    info="${line%%!*}"
    info="$(printf '%s\n' "${info}" | cut -d ' ' -f 2- | xargs)"
    info="${info%\'}"
    info="${info#\'}"
    printf '%s\n' "${info}"
}

# Refresh the archive so it contains only the current best trial
if [ -z "${output_archive}" ] || [ "${output_archive}" = "/" ]; then
    echo "Unsafe archive path: ${output_archive}" >&2
    exit 1
fi

mkdir -p "${output_archive}"
find "${output_archive}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

# Archive files associated with the current best trial
summa_output_path="$(read_from_summa_config "${summa_filemanager}" "outputPath")"
summa_out_file_prefix="$(read_from_summa_config "${summa_filemanager}" "outFilePrefix")"
summa_day_file="${summa_output_path}/${summa_out_file_prefix}_day.nc"
trial_param_priori="${trial_param_file%.nc}.priori.nc"

cp -p "${summa_filemanager}" "${output_archive}/"
cp -p "${trial_param_file}" "${output_archive}/"

if [ -f "${trial_param_priori}" ]; then
    cp -p "${trial_param_priori}" "${output_archive}/"
fi

if [ -f "${summa_day_file}" ]; then
    cp -p "${summa_day_file}" "${output_archive}/"
fi

for output_file in "${results_dir}/KGE.txt" \
    "${results_dir}/streamflow_simulated.csv" \
    "${results_dir}/obs_vs_sim.png" \
    Ost*.txt \
    ostrich/multipliers.* \
    model_run.log; do
    if [ -f "${output_file}" ]; then
        cp -p "${output_file}" "${output_archive}/"
    fi
done
