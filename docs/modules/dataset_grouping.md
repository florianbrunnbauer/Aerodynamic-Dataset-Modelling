# `dataset_grouping`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/dataset_grouping.f90)

Creates nominal Reynolds/Mach cells containing every matching dataset index, including repeated sweeps.

## Pipeline contract

Use a nonempty validated `aero_dataset_type` after configuration selection. The routine checks dataset storage existence but trusts run arrays, lengths and values. It does not filter configuration, inspect test identity or repair failed classifications.

## Public interface

### `group_dataset`

```fortran
call group_dataset(dataset, grouped, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `dataset` | `type(aero_dataset_type)` | in | no | Measurement storage; see the procedure-specific contract below. |
| `grouped` | `type(grouped_dataset_type)` | out | no | Nominal Reynolds/Mach groups with all matching dataset indices. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `print_grouping_report`

```fortran
call print_grouping_report(dataset, grouped)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `dataset` | `type(aero_dataset_type)` | in | no | Measurement storage; see the procedure-specific contract below. |
| `grouped` | `type(grouped_dataset_type)` | in | no | Nominal Reynolds/Mach groups with all matching dataset indices. |

## Behavior and implementation

For each run, calculate the sample-mean measured Mach and Reynolds number. Assign the nearest known nominal level, then require it to be within the classification tolerance:

| Quantity | Nominal levels | Tolerance |
|---|---|---|
| Mach | 0.70, 0.75, 0.80, 0.83, 0.85, 0.86, 0.87, 0.88, 0.92 | absolute difference <= 0.004 |
| Reynolds | 5e6, 19.8e6, 30e6 | absolute difference / nominal <= 0.02 |

The nearest-level search retains the earlier listed level on an exact distance tie. Classification uses means, not a requirement that every sample falls within tolerance.

The module appends Reynolds and Mach cells as first encountered and stores each run's position in `dataset%runs`. Group order is insertion order, not numerical order; later consumers must search or sort local indices. Metadata run IDs remain independent of these indices. No coefficient arrays are copied and no repeated runs are discarded.

`print_grouping_report` prints each cell's nominal labels, number of runs and CRM run IDs. The 2% grouping tolerance identifies an experimental group; it is separate from the user's flight-Re acceptance tolerance and does not establish an aerodynamic accuracy band. Hard-coded known levels make this module specific to the current CRM dataset.

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | stat | All runs classified and indexed |
| 1 | stat | dataset%runs is unallocated |
| 2 | stat | Dataset contains zero runs |
| 3 | stat | At least one measured mean Mach is outside classification tolerance |
| 4 | stat | At least one measured mean Reynolds is outside classification tolerance |

The failing run/mean is printed for statuses 3 and 4. Output may contain partially constructed cells; only consume it when stat is zero. Reordering the associated dataset afterward invalidates its indices.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program grouping_example
  use iso_fortran_env, only: real64
  use types
  use dataset_catalogue, only: build_run_catalogue
  use run_selection, only: select_runs
  use data_io, only: read_crm_dataset
  use dataset_validation, only: validate_dataset
  use dataset_grouping, only: group_dataset
  use dataset_grouping, only: print_grouping_report
  implicit none
  type(run_info_type), allocatable :: catalogue(:), selected(:)
  type(run_selection_type) :: selection
  type(aero_dataset_type) :: data
  type(dataset_validation_result_type) :: validity
  type(grouped_dataset_type) :: grouped

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
  call print_grouping_report(data, grouped)
end program grouping_example
```

## Dependencies and tests

Project dependencies: [types](types.md).

Relevant test/validation sources:

- [`test_dataset_grouping.f90`](../../test/test_dataset_grouping.f90)
- [`test_dataset_grouping_integration.f90`](../../test/test_dataset_grouping_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
