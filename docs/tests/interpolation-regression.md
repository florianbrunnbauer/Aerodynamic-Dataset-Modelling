# Interpolation algorithm regression tests

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/linear_interpolation.f90`](../../src/linear_interpolation.f90) — [module reference](../modules/linear_interpolation.md).
- [`src/pchip_interpolation.f90`](../../src/pchip_interpolation.f90) — [module reference](../modules/pchip_interpolation.md).
- [`src/akima_interpolation.f90`](../../src/akima_interpolation.f90) — [module reference](../modules/akima_interpolation.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_linear_interpolation.f90`](../../test/test_linear_interpolation.f90).
- [`test_pchip_interpolation.f90`](../../test/test_pchip_interpolation.f90).
- [`test_akima_interpolation.f90`](../../test/test_akima_interpolation.f90).

## Behavior tested and why

| Method | Behavior checked | Why |
|---|---|---|
| Linear | Endpoints, internal knot, interior points in all four intervals of a non-affine curve; uneven spacing | Detect wrong bracketing or interval weights. |
| PCHIP | Every knot; straight lines and constants on an uneven grid; fixed nonlinear references; two-point fallback; three-point endpoint sign/cap rules; sampled segment bounds and monotonicity in both directions with a plateau | Verify shape-preserving slope rules and small-input behavior. |
| Akima | Every knot; straight lines and constants on an uneven grid; fixed nonlinear references; five-point zero-weight fallback | Verify classical Akima derivatives, endpoint handling and fallback. |

PCHIP and Akima also launch isolated child invocations for empty/too-short inputs, unequal array lengths, descending/duplicate x, queries below/above the range, and NaN/infinity in x, y or the query. Each child must exit nonzero **and** emit the expected method-prefixed diagnostic. A nonzero exit alone is insufficient.

These tests compare implementation behavior to known results. For prediction error at unseen samples, see [held-out interpolation validation](interpolation-validation.md).

## Test data, reference values and tolerances

The linear uniform grid is `x=[-5,0,5,10,15]`, `y=[-0.5,0,1,0.5,1.5]`. Midpoint references are `-0.25,0.5,0.75,1.0`; endpoint/knot references use stored values. On `x=[-5,-1,2,8,15]`, `y=[-0.5,0,0.6,1.2,0.5]`, queries `-4,6,2` return `-0.375,1.0,0.6`. Absolute error must be `<=1e-10`.

PCHIP/Akima use `x=[0,0.6,1.5,2,3.8,5]`, `y=[0,1,1.5,1.4,2,1.8]`. The source identifies its fixed references as SciPy 1.17.0 `PchipInterpolator` and `Akima1DInterpolator(method="akima")`; Python/SciPy are not runtime dependencies.

| Query | PCHIP reference | Akima reference |
|---:|---:|---:|
| 0.2 | 0.40859940400170286 | 0.41211052322163438 |
| 0.9 | 1.244572158365262 | 1.2606654273320943 |
| 1.8 | 1.4352 | 1.4286541975603924 |
| 2.7 | 1.6016460905349796 | 1.6207416570629056 |
| 4.6 | 1.9170370370370373 | 1.9326164874551972 |

Their value comparison is `abs(actual-reference) <= 1e-12*max(1,abs(reference))`, and explicitly fails NaNs. Straight-line and constant cases use `2*x-3` and `-2.5` at 41 points. PCHIP checks 21 points per segment within endpoint bounds using `1e-12` slack, and monotonicity at 200 steps for each sign.

PCHIP's two-point example returns 2 at x=0.5 from `([0,2],[1,5])`. Three-point endpoint references are 0.071875, 6.85, 0.578125 and -5.890625 for the cases in its source. Akima's five-point example `x=[0,1,2,3,4]`, `y=[0,1,2,5,8]` expects 1.375 and 3.375 at x=1.5 and 2.5 when the central derivative weights vanish.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_linear_interpolation
fpm test --profile debug test_pchip_interpolation
fpm test --profile debug test_akima_interpolation
```

A numeric failure prints a case label and, for the reference helpers, actual/expected values. For rejection failures, distinguish inability to launch the child, unexpected successful acceptance, and a missing expected diagnostic. The parent creates and deletes `test_pchip_rejection.log` or `test_akima_rejection.log`; concurrent copies of the same executable in one directory can collide. Expected child errors are captured in those logs and are not failures when the parent passes.

## What these tests do not establish

Linear's standalone test has no invalid-input child cases and its `abs(error)>tol` helper does not explicitly reject NaNs. PCHIP's shape properties are sampled examples, not a proof for every grid. Akima is not tested or claimed to be monotonicity-preserving or free of overshoot. Fixed references do not establish aerodynamic prediction accuracy, behavior for all extreme numeric scales, derivative continuity by explicit measurement, or every failure path.
