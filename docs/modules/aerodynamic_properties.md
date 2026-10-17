# `aerodynamic_properties`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/aerodynamic_properties.f90)

Converts density/speed to dynamic pressure and coefficients to dimensional loads or lift-to-drag ratio.

## Pipeline contract

These are standalone SI calculations. The caller supplies coefficients and reference geometry consistent with the dataset definitions. The module does not select data, calculate atmosphere, enforce Reynolds policy, shift the moment reference point, or transform force axes.

## Public interface

### `calculate_dynamic_pressure`

```fortran
call calculate_dynamic_pressure(rho, speed, q, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `rho` | `real(real64)` | in | no | Positive density [kg/m^3]. |
| `speed` | `real(real64)` | in | no | Nonnegative speed magnitude [m/s]. |
| `q` | `real(real64)` | out | no | Nonnegative dynamic pressure [Pa]. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `calculate_aerodynamic_loads`

```fortran
call calculate_aerodynamic_loads(cl, cd, cm, q, reference_area, reference_chord, lift, drag, &
    pitching_moment, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `cl` | `real(real64)` | in | no | Dimensionless signed lift coefficient. |
| `cd` | `real(real64)` | in | no | Dimensionless signed drag coefficient. |
| `cm` | `real(real64)` | in | no | Dimensionless signed pitching-moment coefficient. |
| `q` | `real(real64)` | in | no | Nonnegative dynamic pressure [Pa]. |
| `reference_area` | `real(real64)` | in | no | Positive reference area used in the coefficient definitions [m^2]. |
| `reference_chord` | `real(real64)` | in | no | Positive pitching-moment reference length [m]. |
| `lift` | `real(real64)` | out | no | Signed lift [N]. |
| `drag` | `real(real64)` | out | no | Signed drag [N]. |
| `pitching_moment` | `real(real64)` | out | no | Signed moment about the original reference point [N m]. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `calculate_lift_to_drag`

```fortran
call calculate_lift_to_drag(cl, cd, ratio, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `cl` | `real(real64)` | in | no | Dimensionless signed lift coefficient. |
| `cd` | `real(real64)` | in | no | Dimensionless signed drag coefficient. |
| `ratio` | `real(real64)` | out | no | Signed Cl/Cd; dimensionless. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

## Behavior and implementation

The implemented relationships are

$$q=\tfrac12\rho V^2,\qquad L=C_LqS,\qquad D=C_DqS,\qquad M=C_MqS\bar c,\qquad L/D=C_L/C_D.$$

Density must be finite and positive; speed finite and nonnegative. Zero speed produces zero dynamic pressure. Load inputs require finite coefficients, nonnegative dynamic pressure and strictly positive finite reference area/chord. With zero dynamic pressure all three loads are zero. Signed coefficients, including a negative Cd, retain their signs; this routine does not decide whether such coefficients are physically suitable.

Dynamic pressure uses an overflow guard before multiplication. Loads use checked multiplication, including zero-factor handling. Outputs are committed only after all three loads have been calculated successfully. Lift-to-drag checks division overflow and rejects exactly zero drag coefficient. These checks protect representability; no aerodynamic uncertainty or geometry validation is implied.

Use the actual reference area and moment reference length associated with the supplied coefficients. Moment output remains about the original coefficient reference point.

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | properties_ok | Requested quantities returned. |
| 1 | properties_invalid_input | Nonfinite input or invalid density, speed, q, area or chord. |
| 2 | properties_zero_drag | Lift-to-drag requested with Cd=0. |
| 3 | properties_nonfinite_result | Result cannot be represented safely. |

Returned real outputs are quiet NaNs on failure. Each call has its own status; a successful pressure calculation does not imply that subsequent loads/ratio succeeded.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program example_aerodynamic_properties
  use iso_fortran_env, only: real64
  use aerodynamic_properties
  implicit none
  real(real64) :: q, lift, drag, moment, ratio
  integer :: stat
  call calculate_dynamic_pressure(1.225_real64, 100.0_real64, q, stat)
  if (stat /= properties_ok) error stop 'pressure failed'
  call calculate_aerodynamic_loads(0.6_real64, 0.03_real64, -0.02_real64, &
                                  q, 2.0_real64, 0.5_real64, lift, drag, moment, stat)
  if (stat /= properties_ok) error stop 'loads failed'
  call calculate_lift_to_drag(0.6_real64, 0.03_real64, ratio, stat)
  if (stat /= properties_ok) error stop 'ratio failed'
  ! Illustrative geometry: q=6125 Pa, L=7350 N, D=367.5 N, M=-122.5 N m, L/D=20.
  print *, q, lift, drag, moment, ratio
end program example_aerodynamic_properties
```

## Dependencies and tests

Project dependencies: No project-module dependency..

Coverage, fixtures, tolerances, commands and limitations:

- [Dynamic pressure, loads and lift-to-drag ratio](../tests/aerodynamic-properties.md).
- [Flight-condition acceptance and Reynolds-matched altitude](../tests/flight-conditions.md).

Relevant test/validation sources:

- [`test_aerodynamic_properties.f90`](../../test/test_aerodynamic_properties.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
