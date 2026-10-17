# `pchip_interpolation`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/pchip_interpolation.f90)

Evaluates a shape-preserving piecewise cubic Hermite interpolant using neighboring secant slopes to estimate knot derivatives.

## Pipeline contract

Equal-length finite real64 arrays, at least two points, strictly increasing x and a finite in-range query are required and checked. Both measured endpoints are queryable. There is no extrapolation or automatic fallback to another method, except that the two-point construction reduces to a straight line.

## Public interface

### `pchip_interpolate`

```fortran
call pchip_interpolate(interpolater_array, interpolant_array, interpolater_value, interpolated_value)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `interpolater_array(:)` | `real(real64)` | in | no | x(:): 1D interpolation coordinates; strictly increasing. |
| `interpolant_array(:)` | `real(real64)` | in | no | y(:): values corresponding one-to-one with x(:). |
| `interpolater_value` | `real(real64)` | in | no | Scalar x query; same units as x(:). |
| `interpolated_value` | `real(real64)` | out | no | Scalar result; same units as y(:). |

## Behavior and implementation

With $h_i=x_{i+1}-x_i$ and $\delta_i=(y_{i+1}-y_i)/h_i$, an interior derivative is zero if either adjacent slope is zero or their signs differ. Otherwise the code uses a weighted harmonic mean:

$$
w_1=2h_i+h_{i-1},\quad w_2=h_i+2h_{i-1},\quad
d_i=\frac{w_1+w_2}{w_1/\delta_{i-1}+w_2/\delta_i}.
$$

A private one-sided endpoint-derivative helper applies sign and magnitude limiters. The result on the bracketing interval is evaluated with cubic Hermite basis functions using the two values and endpoint derivatives. This preserves monotone shape in monotone data and suppresses artificial extrema; it is not a global polynomial fit or a measurement-noise filter. First derivatives are continuous, while second derivatives need not be.

An exact knot returns its original y value after input checks. All interval widths, slopes and knot derivatives are allocated/calculated on each non-knot call; the implementation does not cache a fitted interpolator. A typical interior segment depends on four neighboring measured points through its two derivatives, with endpoint rules near boundaries.

Algorithm reference: [SciPy PchipInterpolator derivative rules](https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.PchipInterpolator.html), also identified in the source. SciPy is not a runtime dependency.

## Errors and status handling

Invalid input terminates with a `PCHIP:` diagnostic and `error stop`. Checks cover point count, unequal sizes, nonfinite x/y/query, duplicate or descending x, and extrapolation. The test suite runs expected fatal-input cases in separate processes. Finite inputs alone do not guarantee safe arithmetic for arbitrarily extreme magnitudes or spacings.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program pchip_interpolation_example
  use iso_fortran_env, only: real64
  use pchip_interpolation, only: pchip_interpolate
  implicit none
  real(real64) :: x(5), y(5), value
  x = [0.0_real64,1.0_real64,2.0_real64,3.0_real64,4.0_real64]
  y = 2.0_real64*x
  call pchip_interpolate(x, y, 1.5_real64, value)
  print *, value ! 3.0, up to floating-point roundoff
end program pchip_interpolation_example
```

## Dependencies and tests

Project dependencies: No project-module dependency..

Coverage, fixtures, tolerances, commands and limitations:

- [Interpolation algorithm regression tests](../tests/interpolation-regression.md).
- [Prepared coefficient queries and supported Mach gaps](../tests/coefficient-queries.md).
- [Held-out interpolation validation](../tests/interpolation-validation.md).

Relevant test/validation sources:

- [`test_pchip_interpolation.f90`](../../test/test_pchip_interpolation.f90)
- [`test_coefficient_query_v2.f90`](../../test/test_coefficient_query_v2.f90)
- [`validate_interpolation_methods.f90`](../../test/validate_interpolation_methods.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
