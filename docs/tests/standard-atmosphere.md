# Standard atmosphere numerical behavior

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/standard_atmosphere.f90`](../../src/standard_atmosphere.f90) — [module reference](../modules/standard_atmosphere.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_standard_atmosphere.f90`](../../test/test_standard_atmosphere.f90).

## Behavior tested and why

The test compares atmosphere properties with rounded published references identified in the source as U.S. Standard Atmosphere 1976, NASA-TM-X-74335, Table 10 and Table I pages 55, 56, 57 and 62. It distinguishes geometric from geopotential altitude, checks continuity around the 11 and 20 km geopotential boundaries, and checks positivity/finiteness and decreasing pressure/density on a 0–32 km geometric grid.

A centered pressure difference at 5, 15 and 25 km checks hydrostatic balance in geometric coordinates. Negative/out-of-range/huge and NaN/infinite altitude cases must produce the expected rejection status and NaNs in all returned properties and heights. A later valid call must recover successfully.

## Test data, reference values and tolerances

All comparisons in `close_to` are purely relative: `abs(actual-reference) <= relative_tolerance*abs(reference)`.

| Location | Reference values asserted | Relative tolerance |
|---|---|---|
| Sea level | T=288.15 K, p=101325 Pa | 1e-12 |
| Sea level | rho=1.2250 kg/m³, a=340.294 m/s | 1e-5 |
| Sea level | mu=1.7894e-5 Pa·s | 2e-5 |
| 5 km geometric | T=255.676 K; p=54048 Pa; rho=0.73643 kg/m³ | T: 5e-6; p/rho: 5e-5 |
| 10 km geometric | T=223.252 K; p=26499 Pa; rho=0.41351 kg/m³ | T: 5e-6; p/rho: 5e-5 |
| 10 km geopotential | T=223.15 K; p=26436 Pa; rho=0.41271 kg/m³ | T/converted height: 1e-12; p/rho: 5e-5 |
| 11 km geopotential | T=216.65 K; p=22632 Pa | T: 1e-12; p: 5e-5 |
| 15 km geopotential | T=216.65 K | 1e-12 |
| 20 km geopotential | T=216.65 K; p=5474.9 Pa | T: 1e-12; p: 5e-5 |
| 30 km geopotential | T=226.65 K; p=1171.9 Pa; rho=0.018012 kg/m³ | T: 1e-12; p/rho: 5e-5 |

Geopotential heights are mapped to geometric input using `z=R*h/(R-h)`, `R=6356766 m`. Boundary continuity uses offsets of ±0.001 m in geometric height and relative tolerance `1e-6` for T, p, rho, sound speed and viscosity. The domain grid has 1 km spacing including 0 and 32000 m. Hydrostatic checks use ±1 m and reference `-rho*9.80665*(R/(R+z))**2` with relative tolerance `1e-7`.

Rejected finite inputs include -0.001 m, the upper limit +0.001 m and the largest representable finite real. NaN and both signed infinities check invalid-altitude status.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_standard_atmosphere
```

Read the named height/property in the failure label. A 10 km temperature disagreement may signal geometric/geopotential confusion rather than a layer-equation error. Boundary and hydrostatic failures help isolate conversion/continuity errors. Reference tolerances accommodate printed rounding; do not replace rounded references with excessively tight comparisons.

## What these tests do not establish

It does not establish actual weather, humidity effects, atmospheric validity above 32 km or below sea level, aircraft performance, or an independent reference for every output at every altitude. Grid monotonicity and boundary continuity are sampled checks. Published-value provenance is recorded in the test source; these tests do not fetch external references when run.
