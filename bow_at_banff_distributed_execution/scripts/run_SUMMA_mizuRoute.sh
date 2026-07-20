#!/usr/bin/env bash
set -euo pipefail

# Run from the basin directory
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Define model configuration paths
summa_filemanager="model/settings/SUMMA/fileManager.txt"
route_control="model/settings/mizuRoute/mizuRoute.control"
concat_summa_script="scripts/concat_summa_outputs.py"
diagnostics_script="scripts/calculate_run_diagnostics.py"
log_file="model_run.log"

# Allow executable names to be overridden by the environment
python_exe="${PYTHON:-python}"
summa_exe="${SUMMA_EXE:-summa.exe}"
route_exe="${MIZUROUTE_EXE:-mizuRoute.exe}"

# Read a setting from a SUMMA or mizuRoute text configuration file
read_config_value() {
    local input_file="$1"
    local setting="$2"
    grep -m 1 "^${setting}" "${input_file}" | cut -d '!' -f 1 | cut -d ' ' -f 2- | xargs
}

# Stop early when required inputs are missing
require_file() {
    local input_file="$1"
    if [ ! -f "${input_file}" ]; then
        echo "Missing required file: ${input_file}" >&2
        exit 1
    fi
}

# Require the necessary files for this model run
require_file "${summa_filemanager}"
require_file "${route_control}"
require_file "${concat_summa_script}"
require_file "${diagnostics_script}"

# Log a model-run phase to stdout and the run log
log_step() {
    local message="$1"
    echo "--- ${message} ---"
    printf '%s: %s\n' "$(date)" "${message}" >> "${log_file}"
}

# Read paths and output names from the preconfigured model files
summa_settings_path="$(read_config_value "${summa_filemanager}" "settingsPath")"
summa_output_path="$(read_config_value "${summa_filemanager}" "outputPath")"
summa_out_file_prefix="$(read_config_value "${summa_filemanager}" "outFilePrefix")"
summa_attribute_file="$(read_config_value "${summa_filemanager}" "attributeFile")"
summa_attribute_file="${summa_settings_path%/}/${summa_attribute_file}"
route_output_path="$(read_config_value "${route_control}" "<output_dir>")"
route_out_file_prefix="$(read_config_value "${route_control}" "<case_name>")"

# Check if the attribute file exists before trying to read the GRU count
require_file "${summa_attribute_file}"

# Count GRUs from the SUMMA attributes
n_gru="$(ncks -Cm -v gruId -m "${summa_attribute_file}" \
    | awk '$1 == "gru" && $2 == "=" {n = $3} END {if (n != "") print n}')"
if [ -z "${n_gru}" ]; then
    echo "Unable to determine GRU count from ${summa_attribute_file}" >&2
    exit 1
fi

# Run all GRUs in one SUMMA process
log_step "run summa"
mkdir -p "${summa_output_path}"
rm -f "${summa_output_path}/${summa_out_file_prefix}"*
"${summa_exe}" -m "${summa_filemanager}" -g 1 "${n_gru}" -r never

# Merge SUMMA outputs into one file for routing
log_step "concatenate summa outputs"
"${python_exe}" "${concat_summa_script}" --summa-filemanager "${summa_filemanager}"

# Shift daily SUMMA output times to the mizuRoute convention
log_step "post-process summa output"
summa_output_file="${summa_output_path}/${summa_out_file_prefix}_day.nc"
ncap2 -h -O -s 'time[time]=time-86400' "${summa_output_file}" "${summa_output_file}"

# Run mizuRoute on the merged SUMMA output
log_step "run mizuRoute"
mkdir -p "${route_output_path}"
rm -f "${route_output_path}/${route_out_file_prefix}"*
"${route_exe}" "${route_control}"

# Merge mizuRoute outputs when the run produced split output files
route_merged_file="${route_output_path}/${route_out_file_prefix}.mizuRoute.nc"
shopt -s nullglob
route_output_files=("${route_output_path}/${route_out_file_prefix}"*)
shopt -u nullglob

# Check if mizuRoute produced any output files, and merge them if there are multiple
if [ "${#route_output_files[@]}" -eq 0 ]; then
    echo "No mizuRoute output files found in ${route_output_path}" >&2
    exit 1
elif [ "${#route_output_files[@]}" -gt 1 ] \
    || [ "${route_output_files[0]}" != "${route_merged_file}" ]; then
    ncrcat -O -h "${route_output_files[@]}" "${route_merged_file}"
fi

# Calculate run diagnostics from the merged mizuRoute output
log_step "calculate diagnostics"
"${python_exe}" "${diagnostics_script}" --sim-file "${route_merged_file}" \
    --obs-file "obs/obs_flow.CAN_05BB001.cfs.csv" --output-dir "results" \
    --start-date "2003-10-01" --end-date "2005-09-30" --make-plot

log_step "done with model run"
