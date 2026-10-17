# `dataset_representative`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/dataset_representative.f90)

Builds a lightweight representative lookup with exactly one selected run index per prepared Reynolds/Mach cell.

## Pipeline contract

Inputs are the validated dataset and its matching grouped structure. Cells created by successful grouping contain valid run indices and allocated nonempty alpha arrays. This module performs basic structural checks but is not a substitute for preparation or data validation. Keep dataset ordering unchanged after construction.

## Public interface

### `build_representative_dataset`

```fortran
call build_representative_dataset(dataset, grouped, representative, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `dataset` | `type(aero_dataset_type)` | in | no | Measurement storage; see the procedure-specific contract below. |
| `grouped` | `type(grouped_dataset_type)` | in | no | Nominal Reynolds/Mach groups with all matching dataset indices. |
| `representative` | `type(representative_dataset_type)` | out | no | One selected dataset index per nominal Reynolds/Mach combination. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `print_representative_report`

```fortran
call print_representative_report(dataset, representative)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `dataset` | `type(aero_dataset_type)` | in | no | Measurement storage; see the procedure-specific contract below. |
| `representative` | `type(representative_dataset_type)` | in | no | One selected dataset index per nominal Reynolds/Mach combination. |

## Behavior and implementation

For each cell, compare every candidate run's `maxval(alpha)-minval(alpha)`:

1. Prefer the largest alpha range.
2. Treat ranges differing by at most 1e-12 degrees as tied and prefer the larger sample count.
3. If both criteria tie, retain the first candidate in the grouped run-index list.

The output copies nominal labels and stores the chosen 1-based dataset index. It preserves Reynolds/Mach group order from grouping; it does not sort cells. Because catalogue discovery order is not guaranteed stable, a complete tie can select a different equivalent candidate if input order changes.

This is selection, not averaging, smoothing, uncertainty estimation or deletion. `data%runs` retains all runs; the lookup alone determines which measurements are used for coefficient queries. The widest-range criterion does not prove that a sweep is the least noisy or most accurate. Repeatability analysis is a separate consumer of all repeats.

`print_representative_report` uses the dataset indices to print nominal labels, selected CRM run ID and alpha coverage. It expects a successfully constructed structure.

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | stat | Construction succeeded |
| 1 | outer or selected cell | Reynolds groups or a cell run-index array are unallocated |
| 2 | outer or selected cell | No Reynolds groups or no run indices in a cell |
| 3 | outer or selected cell | Mach groups are unallocated, or a candidate index is outside dataset%runs |
| 4 | selected cell | No representative could be selected |

The wrapper forwards selection-helper statuses, so values 1–3 have context-dependent meanings. On failure the output may be partially allocated; do not query it. Not every malformed hand-built structure is rejected: normal operation relies on the successful grouping contract.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program representative_example
  use iso_fortran_env, only: real64
  use types
  use dataset_catalogue, only: build_run_catalogue
  use run_selection, only: select_runs
  use data_io, only: read_crm_dataset
  use dataset_validation, only: validate_dataset
  use dataset_grouping, only: group_dataset
  use dataset_representative, only: build_representative_dataset
  use dataset_representative, only: print_representative_report
  implicit none
  type(run_info_type), allocatable :: catalogue(:), selected(:)
  type(run_selection_type) :: selection
  type(aero_dataset_type) :: data
  type(dataset_validation_result_type) :: validity
  type(grouped_dataset_type) :: grouped
  type(representative_dataset_type) :: structure

  integer :: stat

  call build_run_catalogue('data/phase_2', catalogue, stat)
  if (stat /= 0) error stop 'catalogue failed'
  selection%config = 1
  selection%confts = 1
  selection%conft = 99
  call select_runs(catalogue, selection, selected)
  if (size(selected) == 0) error stop 'no selected runs'
  call read_crm_dataset(selected, data, stat)
  if (stat /= 0) error stop 'read failed'
  call validate_dataset(data, validity)
  if (.not. validity%is_valid) error stop 'invalid data'
  call group_dataset(data, grouped, stat)
  if (stat /= 0) error stop 'grouping failed'
  call build_representative_dataset(data, grouped, structure, stat)
  if (stat /= 0) error stop 'representatives failed'
  call print_representative_report(data, structure)
end program representative_example
```

## Dependencies and tests

Project dependencies: [types](types.md).

Coverage, fixtures, tolerances, commands and limitations:

- [Representative sweep selection](../tests/representative-selection.md).
- [Prepared coefficient queries and supported Mach gaps](../tests/coefficient-queries.md).

Relevant test/validation sources:

- [`test_dataset_representative.f90`](../../test/test_dataset_representative.f90)
- [`test_dataset_representative_integration.f90`](../../test/test_dataset_representative_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
