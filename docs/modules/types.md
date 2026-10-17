# `types`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/types.f90)

Defines the shared data model. There are no procedures, status codes, file operations or automatic validation in this module. All declared derived types are public; real fields use `real64` and indices/counters use default integers.

## Ownership and index invariants

- `aero_dataset_type%runs` owns all selected CRM measurements, including repeated sweeps.
- `grouped_dataset_type` holds every matching dataset index in each nominal cell.
- `representative_dataset_type` holds one chosen dataset index in each nominal cell. It does not contain coefficient arrays or average repeated sweeps.
- Every `run_index`/`run_indices` value refers to the exact associated dataset's current array order. Reloading, removing or reordering runs requires rebuilding the structures.
- `reference_conditions%re_number_position` selects a Reynolds group in the representative structure. It is neither a physical Reynolds number nor a run index.
- `aerodynamic_dataset_type%polars` belongs to the separate XFOIL path. Do not confuse it with `aero_dataset_type%runs`.

The atmosphere and flight-condition modules re-export the types defined here; there is one shared declaration of each type.

## Public types and fields

Allocatable components start unallocated. Explicit scalar defaults are listed below; absence of a scalar initializer is not a meaningful zero default. Nested derived objects inherit the initialization rules of their own components. Zero-initialized result/geometry fields do not imply valid measurements or usable geometry.

### `aerodynamic_polar_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `reynolds` | `real(real64)` | not explicitly initialized | Dimensionless Reynolds number; scalar for a polar, per-sample for a CRM run. |
| `mach` | `real(real64)` | not explicitly initialized | Dimensionless Mach; scalar for a polar, per-sample for a CRM run. |
| `alpha(:)` | `real(real64), allocatable` | unallocated | Angle of attack [degrees]; aligned measurement/evaluation coordinates. |
| `cl(:)` | `real(real64), allocatable` | unallocated | Signed dimensionless lift coefficient. |
| `cd(:)` | `real(real64), allocatable` | unallocated | Signed dimensionless drag coefficient. |
| `cm(:)` | `real(real64), allocatable` | unallocated | Signed dimensionless pitching-moment coefficient. |

### `aerodynamic_dataset_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `polars(:)` | `type(aerodynamic_polar_type), allocatable` | unallocated | Independent XFOIL-style polar objects. |

### `run_info_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `test` | `integer` | not explicitly initialized | CRM experiment/test identifier. |
| `run` | `integer` | not explicitly initialized | CRM run identifier; not a dataset array index. |
| `series` | `integer` | not explicitly initialized | CRM series identifier. |
| `config` | `integer` | not explicitly initialized | Configuration code. |
| `confts` | `integer` | not explicitly initialized | Trips-related configuration code. |
| `conft` | `integer` | not explicitly initialized | Tails-related configuration code. |
| `filename` | `character(len=:), allocatable` | unallocated | Input file path used by the reader. |

### `aero_run_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `info` | `type(run_info_type)` | not explicitly initialized | Metadata belonging to a run or its summary. |
| `alpha(:)` | `real(real64), allocatable` | unallocated | Angle of attack [degrees]; aligned measurement/evaluation coordinates. |
| `mach(:)` | `real(real64), allocatable` | unallocated | Dimensionless Mach; scalar for a polar, per-sample for a CRM run. |
| `reynolds(:)` | `real(real64), allocatable` | unallocated | Dimensionless Reynolds number; scalar for a polar, per-sample for a CRM run. |
| `cl(:)` | `real(real64), allocatable` | unallocated | Signed dimensionless lift coefficient. |
| `cd(:)` | `real(real64), allocatable` | unallocated | Signed dimensionless drag coefficient. |
| `cm(:)` | `real(real64), allocatable` | unallocated | Signed dimensionless pitching-moment coefficient. |

### `aero_dataset_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `runs(:)` | `type(aero_run_type), allocatable` | unallocated | Run measurements or per-run results, depending on the declared type. |

### `run_selection_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `config` | `integer` | not explicitly initialized | Configuration code. |
| `confts` | `integer` | not explicitly initialized | Trips-related configuration code. |
| `conft` | `integer` | not explicitly initialized | Tails-related configuration code. |

### `validation_result_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `is_valid` | `logical` | .true. | Combined validation result, initially true before checks. |
| `arrays_allocated` | `logical` | .true. | Whether required measurement arrays are allocated. |
| `consistent_sizes` | `logical` | .true. | Whether all six measurement arrays have equal size. |
| `enough_points` | `logical` | .true. | At least two samples. |
| `values_finite` | `logical` | .true. | All checked measurements are finite. |
| `alpha_sorted` | `logical` | .true. | Nondecreasing alpha; duplicate check is separate. |
| `mach_reynolds_valid` | `logical` | .true. | Measured Mach is nonnegative and Reynolds positive. |
| `n_points` | `integer` | 0 | Number of samples or evaluation-grid points. |
| `n_duplicate_alpha` | `integer` | 0 | Count of samples repeating an earlier exact alpha value. |
| `n_invalid_values` | `integer` | 0 | Total nonfinite elements across all six measurement arrays. |

### `dataset_validation_result_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `is_valid` | `logical` | .true. | Combined validation result, initially true before checks. |
| `n_runs` | `integer` | 0 | Number of runs in this result/group. |
| `n_valid_runs` | `integer` | 0 | Number of runs passing all checks. |
| `n_invalid_runs` | `integer` | 0 | Number of runs failing at least one check. |
| `run_results(:)` | `type(validation_result_type), allocatable` | unallocated | Per-run validation details in dataset order. |

### `run_characterisation_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `info` | `type(run_info_type)` | not explicitly initialized | Metadata belonging to a run or its summary. |
| `n_points` | `integer` | 0 | Number of samples or evaluation-grid points. |
| `alpha_min` | `real(real64)` | 0.0_real64 | Minimum/common lower alpha bound [degrees]. |
| `alpha_max` | `real(real64)` | 0.0_real64 | Maximum/common upper alpha bound [degrees]. |
| `mach_mean` | `real(real64)` | 0.0_real64 | Arithmetic sample mean of measured Mach. |
| `mach_min` | `real(real64)` | 0.0_real64 | Minimum measured Mach. |
| `mach_max` | `real(real64)` | 0.0_real64 | Maximum measured Mach. |
| `reynolds_mean` | `real(real64)` | 0.0_real64 | Arithmetic sample mean of measured Reynolds. |
| `reynolds_min` | `real(real64)` | 0.0_real64 | Minimum measured Reynolds. |
| `reynolds_max` | `real(real64)` | 0.0_real64 | Maximum measured Reynolds. |

### `dataset_characterisation_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `n_runs` | `integer` | 0 | Number of runs in this result/group. |
| `runs(:)` | `type(run_characterisation_type), allocatable` | unallocated | Run measurements or per-run results, depending on the declared type. |

### `mach_group_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `nominal_mach` | `real(real64)` | 0.0_real64 | Classified Mach label; not automatically a query coordinate. |
| `run_indices(:)` | `integer, allocatable` | unallocated | All matching 1-based positions in data%runs; not metadata run IDs. |

### `reynolds_group_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `nominal_reynolds` | `real(real64)` | 0.0_real64 | Classified Reynolds level / selected flight-Re acceptance target. |
| `mach_groups(:)` | `type(mach_group_type), allocatable` | unallocated | Nested Mach cells for one nominal Reynolds level. |

### `grouped_dataset_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `reynolds_groups(:)` | `type(reynolds_group_type), allocatable` | unallocated | Nested nominal Reynolds groups. |

### `repeatability_group_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `nominal_reynolds` | `real(real64)` | 0.0_real64 | Classified Reynolds level / selected flight-Re acceptance target. |
| `nominal_mach` | `real(real64)` | 0.0_real64 | Classified Mach label; not automatically a query coordinate. |
| `n_runs` | `integer` | 0 | Number of runs in this result/group. |
| `n_points` | `integer` | 0 | Number of samples or evaluation-grid points. |
| `alpha_min` | `real(real64)` | 0.0_real64 | Minimum/common lower alpha bound [degrees]. |
| `alpha_max` | `real(real64)` | 0.0_real64 | Maximum/common upper alpha bound [degrees]. |
| `alpha(:)` | `real(real64), allocatable` | unallocated | Angle of attack [degrees]; aligned measurement/evaluation coordinates. |
| `cl_mean(:)` | `real(real64), allocatable` | unallocated | Mean coefficient across runs |
| `cl_std(:)` | `real(real64), allocatable` | unallocated | Sample standard deviation across runs (n-1 denominator) |
| `cl_spread(:)` | `real(real64), allocatable` | unallocated | Maximum minus minimum coefficient across runs |
| `cd_mean(:)` | `real(real64), allocatable` | unallocated | Mean coefficient across runs |
| `cd_std(:)` | `real(real64), allocatable` | unallocated | Sample standard deviation across runs (n-1 denominator) |
| `cd_spread(:)` | `real(real64), allocatable` | unallocated | Maximum minus minimum coefficient across runs |
| `cm_mean(:)` | `real(real64), allocatable` | unallocated | Mean coefficient across runs |
| `cm_std(:)` | `real(real64), allocatable` | unallocated | Sample standard deviation across runs (n-1 denominator) |
| `cm_spread(:)` | `real(real64), allocatable` | unallocated | Maximum minus minimum coefficient across runs |

### `dataset_repeatability_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `n_groups` | `integer` | 0 | Number of analyzed repeated groups. |
| `groups(:)` | `type(repeatability_group_type), allocatable` | unallocated | Repeated-group result objects. |

### `representative_mach_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `nominal_mach` | `real(real64)` | 0.0_real64 | Classified Mach label; not automatically a query coordinate. |
| `run_index` | `integer` | 0 | One representative 1-based position in data%runs. |

### `representative_reynolds_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `nominal_reynolds` | `real(real64)` | 0.0_real64 | Classified Reynolds level / selected flight-Re acceptance target. |
| `mach_groups(:)` | `type(representative_mach_type), allocatable` | unallocated | Nested Mach cells for one nominal Reynolds level. |

### `representative_dataset_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `reynolds_groups(:)` | `type(representative_reynolds_type), allocatable` | unallocated | Nested nominal Reynolds groups. |

### `atmosphere_state_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `geometric_altitude` | `real(real64)` | 0.0_real64 | Height above sea level [m], atmosphere input convention. |
| `geopotential_altitude` | `real(real64)` | 0.0_real64 | Converted geopotential height [m], used by layer equations. |
| `temperature` | `real(real64)` | 0.0_real64 | Static temperature [K]. |
| `pressure` | `real(real64)` | 0.0_real64 | Static pressure [Pa]. |
| `density` | `real(real64)` | 0.0_real64 | Density [kg/m^3]. |
| `speed_of_sound` | `real(real64)` | 0.0_real64 | Local sound speed [m/s]. |
| `dynamic_viscosity` | `real(real64)` | 0.0_real64 | Dynamic viscosity [Pa s]. |

### `flight_condition_type`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `air` | `type(atmosphere_state_type)` | not explicitly initialized | Shared atmosphere_state_type for the evaluated condition. |
| `accepted` | `logical` | .false. | True only after full flight-condition validation succeeds. |
| `atmosphere_stat` | `integer` | -1 | Original atmosphere status; -1 means not evaluated. |
| `coefficient_stat` | `integer` | -1 | Original coefficient-query status; -1 means not evaluated. |
| `alpha` | `real(real64)` | 0.0_real64 | Angle of attack [degrees]; aligned measurement/evaluation coordinates. |
| `mach` | `real(real64)` | 0.0_real64 | Dimensionless Mach; scalar for a polar, per-sample for a CRM run. |
| `reference_length` | `real(real64)` | 0.0_real64 | Reynolds characteristic length [m]. |
| `nominal_reynolds` | `real(real64)` | 0.0_real64 | Classified Reynolds level / selected flight-Re acceptance target. |
| `reynolds_tolerance` | `real(real64)` | 0.0_real64 | Relative flight-Re tolerance; 0.01 means 1%. |
| `speed` | `real(real64)` | 0.0_real64 | True airspeed [m/s]. |
| `dynamic_pressure` | `real(real64)` | 0.0_real64 | Dynamic pressure [Pa]. |
| `reynolds` | `real(real64)` | 0.0_real64 | Dimensionless Reynolds number; scalar for a polar, per-sample for a CRM run. |
| `relative_reynolds_mismatch` | `real(real64)` | 0.0_real64 | Absolute mismatch from nominal divided by nominal. |
| `observed_reynolds_min` | `real(real64)` | 0.0_real64 | Minimum across selected representative sweeps, not all loaded repeats. |
| `observed_reynolds_max` | `real(real64)` | 0.0_real64 | Maximum across selected representative sweeps, not all loaded repeats. |
| `cl` | `real(real64)` | 0.0_real64 | Signed dimensionless lift coefficient. |
| `cd` | `real(real64)` | 0.0_real64 | Signed dimensionless drag coefficient. |
| `cm` | `real(real64)` | 0.0_real64 | Signed dimensionless pitching-moment coefficient. |

### `reference_conditions`

| Field | Declaration | Initial state | Meaning / units |
|---|---|---|---|
| `reference_length` | `real(real64)` | 0.0_real64 | Reynolds characteristic length [m]. |
| `reference_area` | `real(real64)` | 0.0_real64 | Coefficient reference area [m^2]. |
| `reference_chord` | `real(real64)` | 0.0_real64 | Moment reference length [m]. |
| `re_tolerance` | `real(real64)` | 0.0_real64 | User flight-Re policy as a relative fraction, not percent. |
| `re_number_position` | `integer` | 0 (integer) | 1-based selected Reynolds-group position; zero is unselected. |

## Usage example

```fortran
program types_example
  use iso_fortran_env, only: real64
  use types, only: aero_dataset_type, representative_dataset_type
  implicit none
  type(aero_dataset_type) :: data
  type(representative_dataset_type) :: structure
  integer :: index
  ! Storage illustration only: this is not yet a fully populated validated run.
  allocate(data%runs(1), structure%reynolds_groups(1))
  data%runs(1)%info%run = 39
  data%runs(1)%alpha = [0.0_real64,1.0_real64]
  structure%reynolds_groups(1)%nominal_reynolds = 5.0e6_real64
  allocate(structure%reynolds_groups(1)%mach_groups(1))
  structure%reynolds_groups(1)%mach_groups(1)%nominal_mach = 0.7_real64
  structure%reynolds_groups(1)%mach_groups(1)%run_index = 1
  index = structure%reynolds_groups(1)%mach_groups(1)%run_index
  print *, index, data%runs(index)%info%run, data%runs(index)%alpha
end program types_example
```

## Dependencies and tests

Depends only on the intrinsic `iso_fortran_env` module. There is no dedicated types-only test source. Reader, grouping, representative, coefficient-query and flight-condition tests exercise these types through their public module interfaces. Start with [representative selection](dataset_representative.md) and [coefficient queries](coefficient_query.md) for index usage.

Coverage, fixtures, tolerances, commands and limitations:

- [Dataset discovery, selection and loading](../tests/data-loading.md).
- [Representative sweep selection](../tests/representative-selection.md).
- [Prepared coefficient queries and supported Mach gaps](../tests/coefficient-queries.md).
- [Flight-condition acceptance and Reynolds-matched altitude](../tests/flight-conditions.md).

