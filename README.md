# High-Performance Parallel Computing for Hydrologic Modeling

This repository contains data and scripts related to the *High-Performance Parallel Computing for Hydrologic Modeling* module on [HydroLearn](https://hydrolearn.org/). The activity focuses on running the SUMMA hydrologic model for the Bow River at Banff, Alberta, Canada, with two example cases:
- [Distributed model execution with SUMMA and mizuRoute](https://github.com/tristanmontoya/hydrolearn-hpc/tree/main/bow_at_banff_distributed_execution)
- [Lumped model calibration with SUMMA and OSTRICH](https://github.com/tristanmontoya/hydrolearn-hpc/tree/main/bow_at_banff_lumped_calibration)

Much of the content in this repository is based on the original SUMMA parameter estimation workflows provided at https://github.com/CH-Earth/summa_calib, adapted for use in the HydroLearn HPC course and execution on the [virtual HPC cluster](https://github.com/tristanmontoya/vhpc-hydrotools).

## Prerequisites

The examples use the following tools, which are pre-installed on the virtual HPC cluster:

- Python 3.12 for repository scripts (available from [python.org/downloads](https://www.python.org/downloads/) or a version/package manager like `pyenv`, `conda`, or `uv`).
- `summa.exe` for SUMMA model execution (tested with `v3.3.0`; available at [CH-Earth/summa](https://github.com/CH-Earth/summa)).
- `mizuRoute.exe` for routing model execution (tested with `v1.2.3`; available at [ESCOMP/mizuRoute](https://github.com/ESCOMP/mizuRoute)) plus NCO commands `ncks`, `ncap2`, and `ncrcat` for the distributed execution case (available via `apt install nco` on Ubuntu/Debian or `brew install nco` on macOS).
- `ostrich` for the lumped calibration case (tested with source release `v21.03.16`; available at [DOI-BOR/ostrich](https://github.com/DOI-BOR/ostrich), although note that the calibration logs report the version number as the compilation date rather than the source tag).

The Python scripts are tested with Python 3.12, and the required packages are listed in `requirements.txt`. To create a local virtual environment and install the required packages, run:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Scripts use `PYTHON` when set, otherwise `python`. SUMMA scripts use `SUMMA_EXE` when set, otherwise `summa.exe`; the distributed routing script also supports `MIZUROUTE_EXE`.

## Acknowledgements

This repository was developed by Hongli Liu at Montana State University and Tristan Montoya at the University of Saskatchewan with funding support from the Cooperative Institute for [Research to Operations in Hydrology (CIROH)](https://ciroh.ua.edu/).
