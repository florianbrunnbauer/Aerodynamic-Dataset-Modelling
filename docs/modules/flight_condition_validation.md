# `flight_condition_validation`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/flight_condition_validation.f90)

Applies a caller-selected Reynolds acceptance policy to a physical flight condition, then delegates supported coefficient lookup to coefficient_query.

## Pipeline contract

Requires the same prepared `data`/`structure` pair as `coefficient_query`. `reynolds_group_index` selects a representative group; its nominal Reynolds number is the acceptance target. No separate target value is accepted by `validate_flight_condition`. `flight_condition_type` is defined in `types` and re-exported here. Reference length must match the physical Reynolds definition intended by the caller.

## Public interface

### `validate_flight_condition`

```fortran
call validate_flight_condition(data, structure, reynolds_group_index, altitude, mach, alpha, &
    reference_length, reynolds_tolerance, condition, stat, alpha_method, use_mean_mach)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `data` | `type(aero_dataset_type)` | in | no | Validated measurement storage corresponding to structure. |
| `structure` | `type(representative_dataset_type)` | in | no | Representative lookup built from the same data; preserve data%runs ordering. |
| `reynolds_group_index` | `integer` | in | no | 1-based position in structure%reynolds_groups, not a Reynolds value. |
| `altitude` | `real(real64)` | in | no | Geometric altitude above sea level [m]. |
| `mach` | `real(real64)` | in | no | Dimensionless Mach number; positive for flight calculations. |
| `alpha` | `real(real64)` | in | no | Requested angle of attack [degrees]. |
| `reference_length` | `real(real64)` | in | no | Positive characteristic length used to define Reynolds number [m]. |
| `reynolds_tolerance` | `real(real64)` | in | no | Relative fraction in [0,1); 0.01 means a 1% acceptance tolerance. |
| `condition` | `type(flight_condition_type)` | out | no | Shared flight_condition_type, with acceptance flag and retained diagnostics. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |
| `alpha_method` | `character(len=*)` | in | yes | Optional case-sensitive 'linear', 'pchip', or 'akima'; default 'akima'. |
| `use_mean_mach` | `logical` | in | yes | Optional logical; default false uses measured Mach(alpha), true uses measured sweep means. |

### `find_reynolds_matched_altitude`

```fortran
call find_reynolds_matched_altitude(mach, reference_length, target_reynolds, altitude, stat, &
    altitude_tolerance)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `mach` | `real(real64)` | in | no | Dimensionless Mach number; positive for flight calculations. |
| `reference_length` | `real(real64)` | in | no | Positive characteristic length used to define Reynolds number [m]. |
| `target_reynolds` | `real(real64)` | in | no | Positive dimensionless Reynolds number targeted by the altitude solver. |
| `altitude` | `real(real64)` | out | no | Geometric altitude above sea level [m]. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |
| `altitude_tolerance` | `real(real64)` | in | yes | Optional positive altitude bracket width [m]; default 0.01 m. |

### `flight_status_message`

```fortran
message = flight_status_message(stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `stat` | `integer` | in | no | Procedure-specific integer status; inspect the tables on this page. |

Returns an allocatable character string; it does not print the message. Unknown integers return the module's unknown-status message.

## Behavior and implementation

Validation proceeds in this order:

1. Check finite flight inputs, positive Mach/length, relative Reynolds tolerance in `[0,1)`, and small prepared-structure references.
2. Record the selected nominal Reynolds number. Calculate observed Reynolds minima/maxima across **all representative sweeps in that group**, including alpha-unsupported sweeps. Unselected repeats and other Reynolds groups do not contribute to these diagnostics.
3. Calculate atmosphere, speed $V=Ma\cdot a$, dynamic pressure and physical Reynolds number $Re=\rho VL/\mu$. Reynolds evaluation uses logarithms to avoid unsafe intermediate products.
4. Compare physical Re with the selected nominal Re. Accept this policy stage when

$$|Re-Re_0|\le tRe_0+64\epsilon\max(Re,Re_0).$$

5. Only after that comparison succeeds, call `query_coefficients`, forwarding the requested alpha method and Mach-coordinate mode. Set `accepted=.true.` only when the coefficient query succeeds too.

Tolerance `t` is a relative fraction: 0.01 means 1%, not 1. It is an explicit caller policy, distinct from grouping tolerances and from numerical roundoff. Passing this policy is not an accuracy claim or interpolation in Reynolds. The observed range is diagnostic; it is not substituted for the nominal target or the policy.

`find_reynolds_matched_altitude` is a separate physical helper. At fixed Mach and reference length it bisects decreasing standard-atmosphere Re over geometric altitude `[0,32000]` m. The target must fall within the endpoint Reynolds range. The default altitude tolerance is 0.01 m and controls **bracket width**, not Reynolds error; the returned altitude is the bracket midpoint. Endpoint/exact midpoint matches can return immediately. Non-progress or 100 iterations without convergence returns solver failure.

The solver does not inspect the dataset or guarantee alpha/Mach support. Use a selected group's nominal Re as its target, then call validation. A zero Reynolds policy tolerance can reject a numerically approximate altitude solution even when the solver met its altitude tolerance. An illustrative one-metre length in an example is not the actual CRM reference length.

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | flight_ok | Condition accepted, or altitude solve succeeded. |
| 1 | flight_invalid_input | Nonfinite/out-of-contract flight, solver or tolerance input. |
| 2 | flight_atmosphere_failure | Atmosphere rejected altitude; inspect atmosphere_stat. |
| 3 | flight_numeric_failure | Physical calculation not representable. |
| 4 | flight_invalid_dataset | Prepared dataset/groups/sweeps absent. |
| 6 | flight_reynolds_mismatch | Physical Re outside the explicit policy. |
| 7 | flight_coefficient_failure | Query rejected; inspect coefficient_stat. |
| 8 | flight_no_matching_altitude | Target Re outside endpoint range. |
| 9 | flight_solver_failure | Requested altitude precision not reached. |
| 10 | flight_invalid_reynolds_group | Group position out of bounds. |
| 11 | flight_invalid_structure | Invalid nominal Re or representative index. |
| -1 | flight_not_evaluated | Sentinel in nested status fields before a stage executes. |

There is no status 5. `flight_status_message` maps the returned statuses; the -1 sentinel uses its unknown-status branch. On rejection `accepted` stays false and coefficients stay NaN unless the delegated query produced them successfully. Earlier computed diagnostics remain available. In particular Reynolds-policy rejection leaves `coefficient_stat=-1`; it is not a coefficient-interpolation failure. The altitude solver initializes its output to NaN on failure.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program example_flight_condition
  use iso_fortran_env, only: real64
  use types
  use dataset_catalogue, only: build_run_catalogue
  use run_selection, only: select_runs
  use data_io, only: read_crm_dataset
  use dataset_validation, only: validate_dataset
  use dataset_grouping, only: group_dataset
  use dataset_representative, only: build_representative_dataset
  use flight_condition_validation, only: validate_flight_condition, &
     find_reynolds_matched_altitude, flight_status_message
  implicit none
  type(run_info_type), allocatable :: catalogue(:), selected(:)
  type(run_selection_type) :: selection
  type(aero_dataset_type) :: data
  type(dataset_validation_result_type) :: validity
  type(grouped_dataset_type) :: grouped
  type(representative_dataset_type) :: structure
  type(flight_condition_type) :: condition
  real(real64) :: altitude, nominal_re
  real(real64), parameter :: length = 1.0_real64 ! illustrative only
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
  nominal_re = structure%reynolds_groups(1)%nominal_reynolds
  call find_reynolds_matched_altitude(0.8_real64, length, nominal_re, altitude, stat)
  if (stat /= 0) then
    print *, flight_status_message(stat)
    stop 1
  end if
  call validate_flight_condition(data, structure, 1, altitude, 0.8_real64, &
       1.0_real64, length, 0.01_real64, condition, stat)
  if (stat /= 0) then
    print *, flight_status_message(stat), condition%coefficient_stat
    stop 1
  end if
  print *, condition%accepted, condition%reynolds, condition%cl
end program example_flight_condition
```

## Dependencies and tests

Project dependencies: [types](types.md), [standard_atmosphere](standard_atmosphere.md), [aerodynamic_properties](aerodynamic_properties.md), [coefficient_query](coefficient_query.md).

Relevant test/validation sources:

- [`test_flight_condition_validation.f90`](../../test/test_flight_condition_validation.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
