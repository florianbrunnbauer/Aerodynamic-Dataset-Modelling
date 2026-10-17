# `coefficient_query`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/coefficient_query.f90)

Queries Cl, Cd and Cm from a prepared representative dataset at one selected Reynolds group, angle of attack and Mach number.

## Pipeline contract

Prepare `data` through selection, reading and validation, then build `structure` through grouping and representative selection. Both arguments must refer to the same unchanged run ordering. `reynolds_group_index` is a 1-based array position, not the nominal Reynolds value. The module trusts upstream array, configuration and classification guarantees; it performs small reference guards and query-specific checks. It neither interpolates between Reynolds groups nor extrapolates alpha or Mach.

## Public interface

### `query_coefficients`

```fortran
call query_coefficients(data, structure, reynolds_group_index, alpha_query, mach_query, cl, cd, cm, &
    stat, alpha_method, use_mean_mach)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `data` | `type(aero_dataset_type)` | in | no | Validated measurement storage corresponding to structure. |
| `structure` | `type(representative_dataset_type)` | in | no | Representative lookup built from the same data; preserve data%runs ordering. |
| `reynolds_group_index` | `integer` | in | no | 1-based position in structure%reynolds_groups, not a Reynolds value. |
| `alpha_query` | `real(real64)` | in | no | Requested angle of attack [degrees]. |
| `mach_query` | `real(real64)` | in | no | Requested dimensionless Mach number. |
| `cl` | `real(real64)` | out | no | Dimensionless signed lift coefficient. |
| `cd` | `real(real64)` | out | no | Dimensionless signed drag coefficient. |
| `cm` | `real(real64)` | out | no | Dimensionless signed pitching-moment coefficient. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |
| `alpha_method` | `character(len=*)` | in | yes | Optional case-sensitive 'linear', 'pchip', or 'akima'; default 'akima'. |
| `use_mean_mach` | `logical` | in | yes | Optional logical; default false uses measured Mach(alpha), true uses measured sweep means. |

### `query_status_message`

```fortran
message = query_status_message(stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `stat` | `integer` | in | no | Procedure-specific integer status; inspect the tables on this page. |

Returns an allocatable character string; it does not print the message. Unknown integers return the module's unknown-status message.

## Behavior and implementation

The implementation sorts local representative indices by nominal Mach without changing `data` or `structure`. For each sweep it checks whether the requested alpha lies in that run's closed alpha range. Unsupported sweeps are excluded from the interpolation candidates.

By default each supported sweep's Mach coordinate is its measured Mach interpolated **linearly in alpha**, independently of the selected coefficient method. With `use_mean_mach=.true.`, the coordinate is the mean measured Mach of that sweep. Nominal Mach labels establish sweep order; they are not the default interpolation coordinates.

Supported Mach coordinates must be strictly increasing in nominal order, including across unsupported gaps. Crossed or duplicate supported coordinates reject the query. Exact-coordinate matching uses a tolerance of `64*epsilon(real64)*max(1,abs(mach_query),maxval(abs(supported_coordinates)))`.

An exact Mach match evaluates only that sweep. Otherwise the nearest supported lower and upper coordinates bracket the query. Thus nominal sweeps `[0.70,0.75,0.80]` with alpha support `[true,false,true]` can interpolate between the first and third sweeps if their actual Mach coordinates bracket the request. Any number of unsupported interior sweeps can be skipped. This does not permit extrapolation beyond the supported coordinates. Nominal outer limits are used only to distinguish some failure diagnostics when no supported bracket exists.

For each selected sweep the code evaluates Cl, Cd and Cm in alpha using the requested method, then combines the two sweep results linearly in Mach:

$$C=(1-w)C_{\mathrm{low}}+wC_{\mathrm{high}},\qquad
w=\frac{Ma-Ma_{\mathrm{low}}}{Ma_{\mathrm{high}}-Ma_{\mathrm{low}}}.$$

`alpha_method` is case-sensitive after trimming/left adjustment: `linear` requires at least two points, `pchip` at least two, and the default `akima` at least five. These minima apply even at an exact alpha knot. There is no silent method fallback. Supported-grid ordering is checked before exact matching, so another supported sweep with a crossed coordinate can invalidate an otherwise exact-coordinate request.

The module does not average repeats, change the selected configuration, perform atmospheric calculations, or validate the physical applicability of a nominal Reynolds group.

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | query_ok | Coefficients returned. |
| 1 | query_empty_dataset | Prepared data or selected Mach sweeps absent. |
| 2 | query_invalid_structure | Representative run index outside data%runs. |
| 3 | query_invalid_input | Nonfinite alpha/Mach, or Mach <= 0. |
| 4 | query_invalid_method | Unknown alpha method. |
| 5 | query_alpha_outside | No usable alpha support for the request. |
| 6 | query_mach_outside | No supported Mach bracket/exact match. |
| 7 | query_insufficient_points | Selected run too short for the method. |
| 8 | query_invalid_mach_grid | Supported Mach coordinates duplicate, cross or fail grid checks. |
| 9 | query_invalid_reynolds_group | Selected group index out of bounds. |
| 10 | query_nonfinite_result | Interpolation produced nonfinite coefficients. |

Outputs are initialized to quiet NaNs. Use coefficients only after `query_ok`. Low-level interpolation routines retain their own fatal checks: the query interface is not a safe validator for arbitrary corrupted arrays. The historically named `test_coefficient_query_v2.f90` imports the current module `coefficient_query`. The interpolation-validation program measures method behavior on its own retained-run setup; it is not a complete validation of every current representative-query path.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program example_coefficient_query
  use iso_fortran_env, only: real64
  use types
  use dataset_catalogue, only: build_run_catalogue
  use run_selection, only: select_runs
  use data_io, only: read_crm_dataset
  use dataset_validation, only: validate_dataset
  use dataset_grouping, only: group_dataset
  use dataset_representative, only: build_representative_dataset
  use coefficient_query, only: query_coefficients, query_status_message
  implicit none
  type(run_info_type), allocatable :: catalogue(:), selected(:)
  type(run_selection_type) :: selection
  type(aero_dataset_type) :: data
  type(dataset_validation_result_type) :: validity
  type(grouped_dataset_type) :: grouped
  type(representative_dataset_type) :: structure
  real(real64) :: cl, cd, cm
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
  call query_coefficients(data, structure, 1, 1.0_real64, 0.8_real64, &
                          cl, cd, cm, stat, alpha_method='akima')
  if (stat /= 0) then
    print *, query_status_message(stat)
    stop 1
  end if
  print *, cl, cd, cm
end program example_coefficient_query
```

## Dependencies and tests

Project dependencies: [types](types.md), [linear_interpolation](linear_interpolation.md), [pchip_interpolation](pchip_interpolation.md), [akima_interpolation](akima_interpolation.md).

Coverage, fixtures, tolerances, commands and limitations:

- [Prepared coefficient queries and supported Mach gaps](../tests/coefficient-queries.md).
- [Flight-condition acceptance and Reynolds-matched altitude](../tests/flight-conditions.md).
- [Held-out interpolation validation](../tests/interpolation-validation.md).

Relevant test/validation sources:

- [`test_coefficient_query_v2.f90`](../../test/test_coefficient_query_v2.f90)
- [`validate_interpolation_methods.f90`](../../test/validate_interpolation_methods.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
