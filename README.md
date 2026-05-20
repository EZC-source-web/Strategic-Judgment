# Strategic-Judgment

Clean MATLAB replication skeleton for the paper **"The judgmental strategy of
professional forecasters"**.

The goal of this repository is to provide a cross-platform, reproducible code
base for rebuilding the empirical pipeline: parsing Survey of Professional
Forecasters density forecasts, constructing benchmark forecasts, computing
scoring rules and PIT diagnostics, running SS-STARX/STAR-type tests, and
exporting paper-ready outputs.

Raw data and generated outputs should not be committed. The repository contains
only source code, documentation, and lightweight placeholders.

## Prerequisites

- MATLAB R2018b or newer.
- No mandatory toolbox is required for the current smoke test.
- Optional later-stage work may use the Statistics and Machine Learning Toolbox
  for distribution functions or estimation conveniences, but core utilities in
  this skeleton avoid toolbox-only functions where practical.

## Folder Structure

```text
.
|-- config/              Project configuration
|-- scripts/             Ordered pipeline steps
|-- src/
|   |-- benchmarks/      Benchmark forecast construction
|   |-- io/              Input/output helpers
|   |-- scoring_rules/   Log score, CRPS, and related scoring code
|   |-- spf/             SPF density parser
|   |-- ss_starx/        SS-STARX and STAR linearity tests
|   `-- utils/           Shared utilities
|-- data/raw/            User-supplied raw data, not versioned
|-- out/                 Generated outputs, not versioned
|-- paper/               Lightweight TeX/BibTeX placeholders for later
`-- tests/               Lightweight tests and smoke checks
```

Legacy material may still exist in top-level historical folders. New
replication code should live in the structure above.

## How To Run

From MATLAB, set the working directory to the repository root and run:

```matlab
run_all
```

`run_all.m` loads `config/default_config.m`, adds the project paths, creates
output folders under `out/`, and executes the pipeline steps in order:

1. `S00_smoke_test`
2. `S10_parse_spf`
3. `S20_build_benchmark`
4. `S30_compute_scores_pit`
5. `S40_run_ss_tests`
6. `S90_export_outputs`

On a fresh clone with no raw data, the smoke test runs end-to-end and later
steps create empty standardized cache files with clear TODO messages.

## Raw Data Policy

Place raw input files under:

```text
data/raw/
```

For example, later SPF density files can be organized under
`data/raw/spf/`. The `data/` directory is ignored by git except for
`data/raw/README_data.md`, so raw files remain local to the machine running the
replication.

## Outputs

All generated files should go under:

```text
out/
```

Typical subfolders are `out/cache/`, `out/logs/`, `out/figures/`, and
`out/tables/`. The full `out/` directory is ignored by git.
