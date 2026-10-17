# `dataset_repeatability`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/dataset_repeatability.f90)

Quantifies coefficient differences between repeated sweeps in the same prepared nominal Reynolds/Mach cell.

## Pipeline contract

Pass the complete validated dataset and its grouped structure, before discarding access to repeated indices. This module is a diagnostic branch, not part of representative selection or the interactive load query. It trusts run-index allocation, index bounds, finite arrays and increasing alpha established upstream. Do not pass a representative structure in place of grouped data.

## Public interface

### `analyse_repeatability`

```fortran
call analyse_repeatability(dataset, grouped, result, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `dataset` | `type(aero_dataset_type)` | in | no | Measurement storage; see the procedure-specific contract below. |
| `grouped` | `type(grouped_dataset_type)` | in | no | Nominal Reynolds/Mach groups with all matching dataset indices. |
| `result` | `type(dataset_repeatability_type)` | out | no | Per-repeated-group common grid, means, sample standard deviations and spreads. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `print_repeatability_report`

```fortran
call print_repeatability_report(result)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `result` | `type(dataset_repeatability_type)` | in | no | Per-repeated-group common grid, means, sample standard deviations and spreads. |

## Behavior and implementation

Only cells with more than one run are analyzed. For each repeated cell:

1. Intersect all measured alpha ranges: lower bound is the maximum of run minima; upper bound is the minimum of run maxima.
2. Select the run with the most measured points inside that intersection. A count tie retains the first candidate.
3. Use those measured alpha points as the common evaluation grid. This is not a uniform grid or the union of all samples.
4. Linearly interpolate every repeated run onto that grid, separately for Cl, Cd and Cm.
5. Calculate the mean, sample standard deviation and full spread at each alpha.

For values $C_j$ from $n$ runs:

$$
\overline C=\frac{1}{n}\sum_j C_j,\qquad
s=\sqrt{\frac{\sum_j(C_j-\overline C)^2}{n-1}},\qquad
\Delta C=\max_j C_j-\min_j C_j.
$$

The `alpha_min/max` fields describe the shared interval, while `alpha(:)` contains the chosen reference run's points inside it; its endpoints need not equal the interval boundaries. Results contain nominal labels, run count, grid count and nine coefficient-statistics arrays. `print_repeatability_report` prints summary extrema of these results.

Linear alignment is used regardless of the alpha method selected in the interactive application. Statistics include alignment interpolation effects and experimental variation; they are not a calibrated uncertainty model or independent validation of predicted flight conditions. There is no Mach/Re correction between repeated sweeps within a nominal cell. No-repeat input succeeds with `n_groups=0` and an allocated empty result array. A failure in one repeated cell stops the entire analysis and can leave partial results.

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | stat | Success, including no repeated cells |
| 1 | stat | Grouped Reynolds array is unallocated |
| 2 | stat | Repeated runs have no common alpha interval |
| 3 | stat | No reference run has at least two measured points inside the common interval |

These are not comprehensive malformed-input guards. Downstream calls to the linear interpolator can terminate on a violated input contract. Only print or consume results after a successful return.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program repeatability_example
  use iso_fortran_env, only: real64
  use types
  use dataset_catalogue, only: build_run_catalogue
  use run_selection, only: select_runs
  use data_io, only: read_crm_dataset
  use dataset_validation, only: validate_dataset
  use dataset_grouping, only: group_dataset
  use dataset_repeatability, only: analyse_repeatability, print_repeatability_report
  implicit none
  type(run_info_type), allocatable :: catalogue(:), selected(:)
  type(run_selection_type) :: selection
  type(aero_dataset_type) :: data
  type(dataset_validation_result_type) :: validity
  type(grouped_dataset_type) :: grouped
  type(dataset_repeatability_type) :: repeatability
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
  call analyse_repeatability(data, grouped, repeatability, stat)
if (stat /= 0) error stop 'repeatability failed'
call print_repeatability_report(repeatability)
end program repeatability_example
```

## Dependencies and tests

Project dependencies: [types](types.md), [linear_interpolation](linear_interpolation.md).

Coverage, fixtures, tolerances, commands and limitations:

- [Repeatability across repeated sweeps](../tests/dataset-repeatability.md).

Relevant test/validation sources:

- [`test_dataset_repeatability.f90`](../../test/test_dataset_repeatability.f90)
- [`test_dataset_repeatability_integration.f90`](../../test/test_dataset_repeatability_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
