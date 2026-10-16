# `standard_atmosphere`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/standard_atmosphere.f90)

Calculates dry standard-atmosphere properties over geometric altitudes from 0 through 32,000 m.

## Pipeline contract

This module is independent of the dataset. Inputs are SI geometric altitude, not geopotential altitude. `atmosphere_state_type` is defined in `types` and re-exported here. The calculation is pure and returns a status rather than terminating on invalid altitude.

## Public interface

### `calculate_atmosphere`

```fortran
call calculate_atmosphere(altitude, state, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `altitude` | `real(real64)` | in | no | Geometric altitude above sea level [m]. |
| `state` | `type(atmosphere_state_type)` | out | no | Shared atmosphere_state_type; SI units and both altitude conventions. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `atmosphere_status_message`

```fortran
message = atmosphere_status_message(stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `stat` | `integer` | in | no | Procedure-specific integer status; inspect the tables on this page. |

Returns an allocatable character string; it does not print the message. Unknown integers return the module's unknown-status message.

## Behavior and implementation

Geometric altitude $z$ is converted to geopotential altitude $H$ with Earth radius $R_E=6\,356\,766$ m:

$$H=\frac{R_E z}{R_E+z}.$$

The model uses $g_0=9.80665$ m/s², $R=8314.32/28.9644$ J/(kg K), and $\gamma=1.4$. At sea level, $T_0=288.15$ K and $p_0=101325$ Pa. Layer boundaries are **geopotential**:

| H range | Temperature rule |
|---|---|
| Below 11,000 m | Lapse rate −0.0065 K/m |
| 11,000 to below 20,000 m | Isothermal at 216.65 K |
| 20,000 m and above within the supported geometric range | Lapse rate +0.001 K/m |

Pressure follows hydrostatic lapse-rate power laws or the isothermal exponential, with continuous layer base values. Derived quantities are

$$\rho=\frac{p}{RT},\qquad a=\sqrt{\gamma RT},\qquad
\mu=\frac{1.458\times10^{-6}T^{3/2}}{T+110.4}.$$

Outputs include both altitude conventions, temperature [K], pressure [Pa], density [kg/m³], speed of sound [m/s] and dynamic viscosity [Pa s]. `atmosphere_min_altitude=0` and `atmosphere_max_altitude=32000` are exported constants in metres, inclusive. The upper bound applies to geometric altitude, so it does not reach geopotential H=32,000 m.

This is a deterministic standard atmosphere, with no actual weather, humidity, wind or terrain correction. Reference: [U.S. Standard Atmosphere, 1976](https://ntrs.nasa.gov/citations/19770009539).

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | atmosphere_ok | Valid atmosphere returned. |
| 1 | atmosphere_invalid_altitude | Nonfinite altitude. |
| 2 | atmosphere_outside_range | Finite altitude outside [0,32000] m. |

On failure every state field, including both altitude fields, is a quiet NaN. Check the status before using any field.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program example_standard_atmosphere
  use iso_fortran_env, only: real64
  use standard_atmosphere
  implicit none
  type(atmosphere_state_type) :: air
  integer :: stat
  call calculate_atmosphere(10000.0_real64, air, stat)
  if (stat /= atmosphere_ok) then
    print *, atmosphere_status_message(stat)
    stop 1
  end if
  print *, air%temperature, air%pressure, air%density
  print *, air%speed_of_sound, air%dynamic_viscosity
end program example_standard_atmosphere
```

## Dependencies and tests

Project dependencies: [types](types.md).

Relevant test/validation sources:

- [`test_standard_atmosphere.f90`](../../test/test_standard_atmosphere.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
