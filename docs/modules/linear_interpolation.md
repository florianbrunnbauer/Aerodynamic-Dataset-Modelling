# `linear_interpolation`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/linear_interpolation.f90)

Evaluates a piecewise linear interpolant at one scalar coordinate. Used both for alpha interpolation and for every Mach interpolation.

## Pipeline contract

Supply equal-length 1D real64 arrays with at least two points, strictly increasing x and finite physically/numerically meaningful values. The query must be inside the closed measured range. The routine detects size/order/range violations but does not explicitly check finite values.

## Public interface

### `linear_interpolate`

```fortran
call linear_interpolate(interpolater_array, interpolant_array, interpolater_value, interpolated_value)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `interpolater_array(:)` | `real(real64)` | in | no | x(:): 1D interpolation coordinates; strictly increasing. |
| `interpolant_array(:)` | `real(real64)` | in | no | y(:): values corresponding one-to-one with x(:). |
| `interpolater_value` | `real(real64)` | in | no | Scalar x query; same units as x(:). |
| `interpolated_value` | `real(real64)` | out | no | Scalar result; same units as y(:). |

## Behavior and implementation

The lower bracketing index is found with masked `maxloc`; the upper with masked `minloc`. An exact knot, including either endpoint, returns its stored value directly. Otherwise:

$$
y(x)=y_i+\frac{x-x_i}{x_{i+1}-x_i}(y_{i+1}-y_i).
$$

Only the bracketing two values influence an interval. The implementation scans the arrays rather than using binary search, has no persistent preprocessing/caching and does not sort input. Duplicate x values are rejected. x and query share units, while the result has y's units; the routine is not tied to alpha or any coefficient.

For CRM queries, static array guarantees come from preparation, while the query module establishes the current alpha/Mach domain before calling this routine. The public argument spellings `interpolater_*` and `interpolant_array` match the source and matter for keyword calls.

## Errors and status handling

Detected violations terminate with `error stop`; there is no `stat`. Checks cover fewer than two x points, unequal lengths, non-increasing x, and queries outside the closed interval. Nonfinite inputs are outside the contract and may evade these comparisons or lead to invalid indexing/arithmetic. Caller-side domain checking is required when an interactive program must recover rather than terminate.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program linear_interpolation_example
  use iso_fortran_env, only: real64
  use linear_interpolation, only: linear_interpolate
  implicit none
  real(real64) :: x(5), y(5), value
  x = [0.0_real64,1.0_real64,2.0_real64,3.0_real64,4.0_real64]
  y = 2.0_real64*x
  call linear_interpolate(x, y, 1.5_real64, value)
  print *, value ! 3.0, up to floating-point roundoff
end program linear_interpolation_example
```

## Dependencies and tests

Project dependencies: No project-module dependency..

Coverage, fixtures, tolerances, commands and limitations:

- [Interpolation algorithm regression tests](../tests/interpolation-regression.md).
- [Prepared coefficient queries and supported Mach gaps](../tests/coefficient-queries.md).
- [Held-out interpolation validation](../tests/interpolation-validation.md).

Relevant test/validation sources:

- [`test_linear_interpolation.f90`](../../test/test_linear_interpolation.f90)
- [`validate_linear_interpolation.f90`](../../test/validate_linear_interpolation.f90)
- [`test_coefficient_query_v2.f90`](../../test/test_coefficient_query_v2.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
