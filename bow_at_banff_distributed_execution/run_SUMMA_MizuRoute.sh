#!/usr/bin/env bash
set -euo pipefail

# Resolve paths from this runner location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
scripts_path="${script_dir}/../scripts"

# Use the basin directory as the base for relative model paths
cd "${script_dir}"

# Define model configuration paths
summa_filemanager="model/settings/SUMMA/fileManager.txt"
route_control="model/settings/mizuRoute/mizuroute.control"
summa_run_script="${SUMMA_RUN_SCRIPT:-summa_run.sh}"
log_file="${script_dir}/model_run.log"

# Allow executable names to be overridden by the environment
summa_exe="${SUMMA_EXE:-summa.exe}"
route_exe="${MIZUROUTE_EXE:-mizuRoute.exe}"

# Read a setting from a SUMMA or mizuRoute text configuration file
read_from_summa_route_config() {
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
require_file "${summa_run_script}"
require_file "${scripts_path}/concat_summa_ouputs.py"

# Log a model-run phase to stdout and the run log
log_step() {
    local message="$1"
    echo "--- ${message} ---"
    date | awk -v message="${message}" \
        '{printf("%s: %s\n",$0,message)}' >> "${log_file}"
}

# Read paths and output names from the preconfigured model files
summa_settings_path="$(read_from_summa_route_config \
    "${summa_filemanager}" "settingsPath")"
summa_output_path="$(read_from_summa_route_config \
    "${summa_filemanager}" "outputPath")"
summa_out_file_prefix="$(read_from_summa_route_config \
    "${summa_filemanager}" "outFilePrefix")"
summa_attribute_file="$(read_from_summa_route_config \
    "${summa_filemanager}" "attributeFile")"
summa_attribute_file="${summa_settings_path}/${summa_attribute_file}"
route_output_path="$(read_from_summa_route_config \
    "${route_control}" "<output_dir>")"
route_out_file_prefix="$(read_from_summa_route_config \
    "${route_control}" "<case_name>")"

# Check if the attribute file exists before trying to read the GRU count
require_file "${summa_attribute_file}"

# Count GRUs for the SUMMA run script
n_gru="$(ncks -Cm -v gruId -m "${summa_attribute_file}" \
    | awk '$1 == "gru" && $2 == "=" {print $3; exit}')"
if [ -z "${n_gru}" ]; then
    echo "Unable to determine GRU count from ${summa_attribute_file}" >&2
    exit 1
fi

# Run SUMMA through the configurable script
log_step "run summa"
mkdir -p "${summa_output_path}"
rm -f "${summa_output_path}/${summa_out_file_prefix}"*
SUMMA_EXE="${summa_exe}" \
SUMMA_FILEMANAGER="${summa_filemanager}" \
N_GRU="${n_gru}" \
bash "${summa_run_script}"

# Merge split GRU outputs into one file for routing
log_step "concatenate summa outputs"
python "${scripts_path}/concat_summa_ouputs.py" \
    --summa-filemanager "${summa_filemanager}"

# Shift daily SUMMA output times to the mizuRoute convention
log_step "post-process summa output"
summa_output_file="${summa_output_path}/${summa_out_file_prefix}_day.nc"
ncap2 -h -O -s 'time[time]=time-86400' \
    "${summa_output_file}" "${summa_output_file}"

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
    || [ "${route_output_files[0]:-}" != "${route_merged_file}" ]; then
    ncrcat -O -h "${route_output_files[@]}" "${route_merged_file}"
fi

log_step "done with model run"