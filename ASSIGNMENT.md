# 1.5.1 Activity Overview

In this activity, you will apply the HPC concepts introduced in this module to representative hydrologic modeling workflows. The goal is not to focus on hydrologic model development or theory, but to understand how computational workloads can be structured and mapped onto HPC resources in a practical setting. To this end, you will take the role of a **research computing specialist advising a hydrologic modeling group**. The group has working serial workflows, but they need guidance on how to map those workflows onto HPC resources, evaluate performance, and decide when parallel execution is worthwhile.

The workflows use [SUMMA](https://github.com/CH-Earth/summa) (Structure for Unifying Multiple Modeling Alternatives) for hydrologic simulation, [mizuRoute](https://github.com/ESCOMP/mizuRoute) for routing runoff from spatial units to the basin outlet, and [OSTRICH](https://github.com/DOI-BOR/ostrich) (Optimization Software Toolkit for Research Involving Computational Heuristics) for model calibration. 

The activity files, scripts, data, and a list of required software tools are available in the [HydroLearn HPC GitHub repository](https://github.com/tristanmontoya/hydrolearn-hpc). You can run the examples on the [virtual HPC cluster](https://github.com/tristanmontoya/vhpc-hydrotools), where the required tools are pre-installed, or on an actual Slurm cluster with the required software installed. If installing the required software on your own system, use [SUMMA v3.3.0](https://github.com/CH-Earth/summa/releases/tag/v3.3.0) (commit [`1edb7c5`](https://github.com/CH-Earth/summa/commit/1edb7c5)), [mizuRoute v1.2.3](https://github.com/ESCOMP/mizuRoute/releases/tag/v1.2.3) (commit [`104ef34`](https://github.com/ESCOMP/mizuRoute/commit/104ef34)), and [OSTRICH v21.03.16](https://github.com/DOI-BOR/ostrich/releases/tag/v21.03.16) (commit [`11630fa`](https://github.com/DOI-BOR/ostrich/commit/11630fa)) to match the versions installed on the virtual HPC cluster and ensure that you are able to run the provided scripts without modification.

Two example scenarios are provided to illustrate different types of computational demand in hydrologic modeling workflows. You may complete one or both of them depending on your interests or research needs, but both assess the same underlying HPC concepts. The scenarios consist of the following simulation workflows, both of which involve predicting the streamflow at the Bow River at Banff, Alberta, Canada using SUMMA:

- **Scenario 1:** A distributed hydrologic model workflow, where computational cost arises from a single SUMMA-mizuRoute simulation that can be parallelized across spatial units.
- **Scenario 2:** A lumped model calibration workflow, where computational cost arises from running a large number of independent SUMMA simulations within OSTRICH.

For each scenario that you complete, submit one practical, concise technical memo describing your findings and recommendations as either a Markdown file or a PDF document, written as if you were advising a hydrologic modeling group on best practices for accelerating their simulation workflows using parallel computing on HPC systems. Each memo should be self-contained and include the following sections:

1. Serial Workflow
2. Parallelization
3. Performance Evaluation
4. Recommendation and Reflection
5. Reproducibility Appendix

The assignment instructions will guide you through the steps needed to complete each section. Completing the activity and writing the memo will take between 60 and 120 minutes for each scenario.
