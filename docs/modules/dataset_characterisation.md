# `dataset_characterisation`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/dataset_characterisation.f90)

Summarizes measured alpha, Mach and Reynolds coverage without changing or classifying the data.

## Pipeline contract

Pass already validated, allocated, nonempty runs. This module has no defensive allocation, size or finite-value checks and no status output. For a dataset, each included run must satisfy the same contract.

## Public interface

### `characterise_run`

```fortran
call characterise_run(run, result)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `run` | `type(aero_run_type)` | in | no | One CRM run with aligned measurement arrays. |
| `result` | `type(run_characterisation_type)` | out | no | Summary statistics for the supplied run(s). |

### `characterise_dataset`

```fortran
call characterise_dataset(dataset, result)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `dataset` | `type(aero_dataset_type)` | in | no | Measurement storage; see the procedure-specific contract below. |
| `result` | `type(dataset_characterisation_type)` | out | no | Summary statistics for the supplied run(s). |

### `print_characterisation_report`

```fortran
call print_characterisation_report(result)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `result` | `type(dataset_characterisation_type)` | in | no | Summary statistics for the supplied run(s). |

## Behavior and implementation

`characterise_run` copies the run metadata, stores the number of samples, and calculates minimum/maximum alpha plus measured Mach and Reynolds means and extrema. Means are ordinary unweighted arithmetic sample means; they are not nominal set points or time-weighted statistics.

`characterise_dataset` preserves dataset order and creates one summary per run. `print_characterisation_report` prints run ID, sample count, alpha range, measured Mach statistics and mean Reynolds number to standard output. Characterization is a diagnostic branch after validation; it is not a required step in the interactive preparation pipeline and does not select representatives.

## Errors and status handling

No integer statuses are defined. Invalid inputs can cause runtime errors or undefined/nonfinite summaries; the caller is responsible for prior validation.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program characterisation_example
  use iso_fortran_env, only: real64
  use types
  use dataset_catalogue, only: build_run_catalogue
  use run_selection, only: select_runs
  use data_io, only: read_crm_dataset
  use dataset_validation, only: validate_dataset
  use dataset_characterisation, only: characterise_dataset, print_characterisation_report
  implicit none
  type(run_info_type), allocatable :: catalogue(:), selected(:)
  type(run_selection_type) :: selection
  type(aero_dataset_type) :: data
  type(dataset_validation_result_type) :: validity
  type(dataset_characterisation_type) :: summary
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
  call characterise_dataset(data, summary)
call print_characterisation_report(summary)
end program characterisation_example
```

## Dependencies and tests

Project dependencies: [types](types.md).

Coverage, fixtures, tolerances, commands and limitations:

- [Run and dataset characterisation](../tests/dataset-characterisation.md).

Relevant test/validation sources:

- [`test_dataset_characterisation.f90`](../../test/test_dataset_characterisation.f90)
- [`test_dataset_characterisation_integration.f90`](../../test/test_dataset_characterisation_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
