# HydroLearn HPC Module Activity

This repository contains data and scripts related to the *High-Performance Parallel
Computing for Hydrologic Modeling* module on
[HydroLearn](https://hydrolearn.org/). The activity focuses on running the SUMMA
hydrologic model for the Bow River at Banff, Alberta, Canada. Much of the content
in this repository is based on the original SUMMA parameter estimation workflows
provided at https://github.com/CH-Earth/summa_calib, adapted for use in the
HydroLearn HPC course and execution on the
[virtual HPC cluster](https://github.com/tristanmontoya/vhpc-hydrotools).

## Python environment

The Python scripts are tested with Python 3.12. To reproduce the environment outside
the virtual HPC cluster, create a local virtual environment and install the pinned
dependencies:

```sh
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

The Python environment covers the Python scripts in this repository. Running the full
SUMMA and mizuRoute examples also requires the external model executables and NCO
command-line tools.

## Acknowledgements

This repository was developed by Hongli Liu at Montana State University and Tristan Montoya
at the University of Saskatchewan with funding support from the Cooperative Institute
for [Research to Operations in Hydrology (CIROH)](https://ciroh.ua.edu/).
