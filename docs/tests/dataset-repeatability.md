# Repeatability across repeated sweeps

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/dataset_repeatability.f90`](../../src/dataset_repeatability.f90) — [module reference](../modules/dataset_repeatability.md).
- [`src/linear_interpolation.f90`](../../src/linear_interpolation.f90) — [module reference](../modules/linear_interpolation.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_dataset_repeatability.f90`](../../test/test_dataset_repeatability.f90).
- [`test_dataset_repeatability_integration.f90`](../../test/test_dataset_repeatability_integration.f90).

## Behavior tested and why

The synthetic test checks repeated-group detection, exclusion of a singleton, overlap restriction, choice of the densest grid inside that overlap, and coefficient mean/sample standard deviation/spread after interpolation. The integration test exercises real loading, validation and grouping, then checks two repeated groups and structural/finite/nonnegative properties of their results.

## Test data, reference values and tolerances

Three synthetic Mach-0.70 runs at Re `5e6` use different alpha grids and coefficient offsets `0, +d, -d`. A fourth run at Mach 0.75 is a singleton and must be ignored. The common interval is `[0.5,4.5]` degrees; run 103 supplies `[0.5,1.5,2.5,3.5,4.5]` because it has the most points inside that interval.

| Coefficient | Expected mean at alpha a | Sample std (n−1 denominator) | Max−min spread |
|---|---|---:|---:|
| Cl | `2*a + 1` | 0.1 | 0.2 |
| Cd | `0.02 + 0.005*a` | 0.002 | 0.004 |
| Cm | `-0.05 - 0.01*a` | 0.01 | 0.02 |

The synthetic numeric assertions require absolute error `< 1e-10`; counts are exact. Linear relationships make grid interpolation analytically exact apart from rounding.

CRM `(1,1,99)` expects 97 catalogue entries and 12 selected runs. Repeated groups are Mach 0.70 (runs 39,50,52) and 0.85 (44,51,53), each with three runs and nominal Re within `< 1` of `5e6`. Common alpha limits must be within `< 0.01` degrees of `2.235/5.220` and `2.266/5.155`, respectively. The integration test requires at least two grid points, increasing finite alpha, correctly sized finite statistics and nonnegative std/spread. It does not fix real coefficient means/std/spreads numerically.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_dataset_repeatability
fpm test --profile debug test_dataset_repeatability_integration
```

Wrong synthetic std values often distinguish population normalization from the required sample normalization. Grid failures suggest overlap or reference-grid selection errors. In real data, first inspect grouping and common alpha limits; finite/nonnegative checks alone do not identify whether a changed coefficient statistic is scientifically reasonable.

## What these tests do not establish

These tests do not estimate total experimental uncertainty, confidence intervals or systematic bias. They do not remove differences in actual measured Mach/Re between repeats, validate nonlinear regridding error, or cover all no-overlap/invalid-input cases. The real-data report is not a fixed accuracy threshold or full numerical regression oracle.
