# `akima_interpolation`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/akima_interpolation.f90)

Evaluates classical Akima piecewise cubic Hermite interpolation. This is the default alpha method in coefficient queries, not modified Akima (MAKIMA).

## Pipeline contract

Requires at least five total measured points, equal finite arrays, strictly increasing x and a finite query within the full closed data range. Missing neighbors at the boundaries are supplied through extrapolated slope estimates, so the usable x range is not shortened.

## Public interface

### `akima_interpolate`

```fortran
call akima_interpolate(interpolater_array, interpolant_array, interpolater_value, interpolated_value)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `interpolater_array(:)` | `real(real64)` | in | no | x(:): 1D interpolation coordinates; strictly increasing. |
| `interpolant_array(:)` | `real(real64)` | in | no | y(:): values corresponding one-to-one with x(:). |
| `interpolater_value` | `real(real64)` | in | no | Scalar x query; same units as x(:). |
| `interpolated_value` | `real(real64)` | out | no | Scalar result; same units as y(:). |

## Behavior and implementation

First compute measured interval slopes $\delta_i$. Two additional slopes at each end are constructed by linear continuation of the first/last slope differences. At knot $i$:

$$
w_1=|\delta_{i+1}-\delta_i|,\quad
w_2=|\delta_{i-1}-\delta_{i-2}|,\quad
d_i=\frac{w_1\delta_{i-1}+w_2\delta_i}{w_1+w_2}.
$$

When the weight sum is no larger than `32*epsilon(real64)*scale`, where scale is the largest absolute local slope, the implementation uses the mean of the two adjacent slopes. This handles constant/linear data and local floating-point roundoff. The bracketing segment is evaluated with cubic Hermite basis functions.

A typical fully interior segment depends on six measured points through the derivative estimates. That is not a requirement for three real points on each side of every query: endpoint slope rules allow evaluation from the first through the last measured x. The five-point contract is enforced even for exact-knot queries. Exact knots return their stored values after checks.

Akima is local and continuously differentiable but does not provide PCHIP's monotonicity guarantee; it can overshoot. The code recalculates slopes/derivatives for each non-knot query and has no cached fitted object. It does not smooth experimental noise or improve Mach interpolation by itself.

Reference: H. Akima (1970), as cited in the source; see the [classical Akima definition](https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.Akima1DInterpolator.html). SciPy is a reference for numerical tests, not a runtime dependency.

## Errors and status handling

Invalid input terminates with an `AKIMA:` diagnostic and `error stop`: fewer than five points, unequal lengths, nonfinite x/y/query, non-increasing x, or out-of-range query. Expected fatal-input cases are tested through child invocations. The module deliberately does not invent fallback behavior for short arrays.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program akima_interpolation_example
  use iso_fortran_env, only: real64
  use akima_interpolation, only: akima_interpolate
  implicit none
  real(real64) :: x(5), y(5), value
  x = [0.0_real64,1.0_real64,2.0_real64,3.0_real64,4.0_real64]
  y = 2.0_real64*x
  call akima_interpolate(x, y, 1.5_real64, value)
  print *, value ! 3.0, up to floating-point roundoff
end program akima_interpolation_example
```

## Dependencies and tests

Project dependencies: No project-module dependency..

Relevant test/validation sources:

- [`test_akima_interpolation.f90`](../../test/test_akima_interpolation.f90)
- [`test_coefficient_query_v2.f90`](../../test/test_coefficient_query_v2.f90)
- [`validate_interpolation_methods.f90`](../../test/validate_interpolation_methods.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
