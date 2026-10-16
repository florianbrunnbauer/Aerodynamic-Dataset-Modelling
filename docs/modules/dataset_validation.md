# `dataset_validation`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/dataset_validation.f90)

Establishes the measurement-array guarantees required by characterization, grouping and coefficient queries.

## Pipeline contract

Call after reading and before numerical preparation. Validation reports problems; it does not sort, delete, repair or interpolate measurements. On success the six arrays are allocated, contain at least two aligned finite samples, and alpha is strictly increasing through the combination of sorted-order and duplicate checks.

## Public interface

### `validate_run`

```fortran
call validate_run(current_run, result)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `current_run` | `type(aero_run_type)` | in | no | One CRM run to validate. |
| `result` | `type(validation_result_type)` | out | no | Run/dataset validation flags and counters; no integer status is returned. |

### `validate_dataset`

```fortran
call validate_dataset(dataset, result)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `dataset` | `type(aero_dataset_type)` | in | no | Measurement storage; see the procedure-specific contract below. |
| `result` | `type(dataset_validation_result_type)` | out | no | Run/dataset validation flags and counters; no integer status is returned. |

## Behavior and implementation

`validate_run` checks allocation first, then point count, then matching sizes. These failures return early. It then counts nonfinite elements, checks exact repeated alpha values, checks nondecreasing alpha order, and rejects negative Mach or nonpositive Reynolds values. The duplicate check makes successful alpha ordering strictly increasing even though `alpha_sorted` alone means nondecreasing.

`n_duplicate_alpha` counts later occurrences that repeat any previous alpha, not all duplicate pairs. `n_invalid_values` counts nonfinite elements across all six arrays, not the number of affected rows. A size mismatch resets `n_points` to zero. Flags for checks not reached retain their initialized values; read them together with `is_valid` and earlier failure flags.

`validate_dataset` rejects unallocated/empty run storage, allocates one result per run, counts passing/failing runs, and sets dataset validity from the invalid-run count. It does not check that all runs have the same configuration, belong to one Reynolds group, have distinct Mach values or provide five points for Akima. Measured Mach equal to zero is accepted here; flight queries require positive query Mach and valid positive local Mach coordinates.

The source contains a private `print_validation_report` helper, but it is not exported. External callers should inspect result fields or implement their own report. Duplicate detection is quadratic in the number of alpha samples; it is preparation work rather than a per-query scan.

## Errors and status handling

No integer status is returned. Inspect `result%is_valid` first, then the detailed flags and counters documented in [types](types.md). An invalid dataset must not be passed into preparation or query routines that trust this contract. Validation of nonfinite data is not a general floating-point exception boundary: later comparisons still occur after the finite-value scan, and trapping builds can stop on invalid arithmetic/comparisons.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program validation_example
  use types, only: run_info_type, aero_dataset_type, dataset_validation_result_type
  use data_io, only: inspect_crm_run, read_crm_dataset
  use dataset_validation, only: validate_dataset
  implicit none
  type(run_info_type) :: info
  type(aero_dataset_type) :: data
  type(dataset_validation_result_type) :: validity
  integer :: stat
  call inspect_crm_run('data/phase_2/t197R39.csv', info, stat)
  if (stat /= 0) error stop 'inspection failed'
  call read_crm_dataset([info], data, stat)
  if (stat /= 0) error stop 'reading failed'
  call validate_dataset(data, validity)
  if (.not. validity%is_valid) error stop 'validation failed'
  print *, validity%n_runs, validity%n_valid_runs
end program validation_example
```

## Dependencies and tests

Project dependencies: [types](types.md).

Relevant test/validation sources:

- [`test_run_validation.f90`](../../test/test_run_validation.f90)
- [`test_dataset_validation.f90`](../../test/test_dataset_validation.f90)
- [`test_dataset_validation_integration.f90`](../../test/test_dataset_validation_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
