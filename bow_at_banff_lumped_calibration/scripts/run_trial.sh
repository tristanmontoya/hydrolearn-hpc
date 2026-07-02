#!/usr/bin/env bash
set -euo pipefail

# Resolve the basin directory from this trial script location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
basin_dir="$(cd "${script_dir}/.." && pwd -P)"

# Use the basin directory as the base for relative model paths
cd "${basin_dir}"

# Define local calibration paths
python_exe="${PYTHON:-python}"
summa_exe="${SUMMA_EXE:-summa.exe}"
summa_filemanager="model/settings/SUMMA/fileManager.txt"
summa_settings_path="model/settings/SUMMA"
trial_param_file="${summa_settings_path}/trialParams.nc"
multiplier_template="ostrich/multipliers.tpl"
multiplier_values="ostrich/multipliers.txt"
diagnostics_script="scripts/calculate_lumped_diagnostics.py"
stat_output="results/KGE.txt"
log_file="${basin_dir}/model_run.log"
failed_kge="-999.000000"

# Ensure failed trials can write the objective file before diagnostics run
mkdir -p "${stat_output%/*}"

# Read a setting from a SUMMA text configuration file
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

# Stop early when a required file is missing
require_file() {
    local input_file="$1"
    if [ ! -f "${input_file}" ]; then
        echo "Missing required file: ${input_file}" >&2
        exit 1
    fi
}

# Log a calibration phase to stdout and the run log
log_step() {
    local message="$1"
    echo "--- ${message} ---"
    date | awk -v message="${message}" '{printf("%s: %s\n",$0,message)}' >> "${log_file}"
}

# Write a poor score so failed parameter sets cannot reuse stale results
write_failed_kge() {
    local message="$1"
    echo "${message}" >&2
    printf "%s\t#KGE\n" "${failed_kge}" > "${stat_output}"
    date | awk -v message="${message}" '{printf("%s: %s\n",$0,message)}' >> "${log_file}"
}

# Require files before touching generated outputs
require_file "${summa_filemanager}"
require_file "${trial_param_file%.nc}.priori.nc"
require_file "${multiplier_template}"
require_file "${multiplier_values}"
require_file "${diagnostics_script}"

# Read SUMMA output settings from the file manager
summa_output_path="$(read_from_summa_config "${summa_filemanager}" "outputPath")"
summa_out_file_prefix="$(read_from_summa_config "${summa_filemanager}" "outFilePrefix")"

if [ -z "${summa_output_path}" ] || [ "${summa_output_path}" = "/" ]; then
    echo "Unsafe SUMMA output path: ${summa_output_path}" >&2
    exit 1
fi

# Update SUMMA parameters from the OSTRICH multiplier file
log_step "update parameters"
"${python_exe}" scripts/update_param_trial.py \
    --multiplier-template "${multiplier_template}" \
    --multiplier-values "${multiplier_values}" --trial-param-file "${trial_param_file}"

# Remove stale diagnostics before the model execution
rm -f "${stat_output}" results/streamflow_simulated.csv results/obs_vs_sim.png

# Run SUMMA for the current trial
log_step "run summa"
mkdir -p "${summa_output_path}"
rm -f "${summa_output_path}/${summa_out_file_prefix}"*
if ! "${summa_exe}" -r never -m "${summa_filemanager}"; then
    write_failed_kge "summa failed for calibration trial"
    exit 0
fi

# Calculate streamflow diagnostics for the current trial
log_step "calculate diagnostics"
if ! "${python_exe}" "${diagnostics_script}" \
    --sim-file "${summa_output_path}/${summa_out_file_prefix}_day.nc" \
    --attributes-file "${summa_settings_path}/attributes.nc" \
    --obs-file "obs/obs_flow.CAN_05BB001.cfs.csv" --output-dir "results" \
    --start-date "2003-10-01" --end-date "2005-09-30" --make-plot; then
    write_failed_kge "diagnostics failed for calibration trial"
    exit 0
fi

# Ensure OSTRICH can read the response variable
if [ ! -f "${stat_output}" ]; then
    echo "Missing objective function file: ${stat_output}" >&2
    exit 1
fi

log_step "done with calibration trial"
