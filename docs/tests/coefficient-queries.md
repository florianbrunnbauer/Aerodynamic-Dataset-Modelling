# Prepared coefficient queries and supported Mach gaps

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/coefficient_query.f90`](../../src/coefficient_query.f90) — [module reference](../modules/coefficient_query.md).
- [`src/dataset_validation.f90`](../../src/dataset_validation.f90) — [module reference](../modules/dataset_validation.md).
- [`src/dataset_grouping.f90`](../../src/dataset_grouping.f90) — [module reference](../modules/dataset_grouping.md).
- [`src/dataset_representative.f90`](../../src/dataset_representative.f90) — [module reference](../modules/dataset_representative.md).
- [`src/linear_interpolation.f90`](../../src/linear_interpolation.f90) — [module reference](../modules/linear_interpolation.md).
- [`src/pchip_interpolation.f90`](../../src/pchip_interpolation.f90) — [module reference](../modules/pchip_interpolation.md).
- [`src/akima_interpolation.f90`](../../src/akima_interpolation.f90) — [module reference](../modules/akima_interpolation.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_coefficient_query_v2.f90`](../../test/test_coefficient_query_v2.f90).

## Behavior tested and why

The program combines focused query checks with synthetic integration through the actual validation, grouping and representative modules. It verifies all three alpha methods followed by linear Mach interpolation; exact measured points; explicit Reynolds-group selection; unordered representative entries; indirect dataset indices; exclusion of unselected repeats; authoritative caller-selected representatives; and selected checks that inputs retain their ordering/values.

It exercises exact-sweep queries without requiring neighboring alpha coverage, bridging unsupported middle sweeps, method-specific minimum point counts, and the measured mean-Mach option. Rejection checks cover empty data/structures, invalid group/index/input/method, alpha/Mach outside support and duplicate/crossing local Mach grids, including grids that pass static validation and mean grouping. Checked failures require the expected status and NaN Cl/Cd/Cm.

A separate support-pattern loop tests eight masks across five nominal Mach sweeps, both Mach-coordinate modes, three alpha methods and 41 Mach requests per combination. Its independent bracket oracle selects the nearest supported lower/upper levels. This makes incorrect gap handling observable even when several intervening sweeps lack alpha support.

## Test data, reference values and tolerances

The base grid is alpha `[0,0.6,1.5,2.8,4]` degrees; nominal Mach entries are deliberately ordered `[0.92,0.70,0.80]`. Measured Mach is `nominal + 0.001*alpha`. At Re `5e6`, the analytic coefficient oracle is:

- `Cl = 0.1*alpha + 2*Mach`
- `Cd = 0.01 + 0.003*alpha + 0.02*Mach`
- `Cm = -0.05 - 0.007*alpha + 0.03*Mach`

Other-Re runs at `30e6` add offsets `(+10,+0.1,-0.2)`; unselected repeats add 100 to Cl. These deliberate differences expose accidental averaging, re-selection or use of another group. Coefficient comparisons require absolute error **less than** `1e-12`.

The nonlinear six-point fixture and fixed method values match the [algorithm regression page](interpolation-regression.md), then add known Mach-dependent terms. Gap cases use levels `[0.70,0.75,0.80,0.85,0.86]`, permuted entries `[5,2,1,4,3]` and masks `[0,1,3,5,10,17,21,31]`. At alpha=2, supported coordinates shift by 0.0002 in pointwise mode or 0.0001 in mean mode. `Cl=nominal_Mach**2`, with scaled Cd/Cm, makes the correct **linear bracket** result distinguishable from a quadratic prediction or a different bracket.

Statuses, index assertions and NaN predicates are exact. The broad gap-rejection loop requires a non-success status and NaNs, whereas named rejection cases check specific status constants.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_coefficient_query_v2
```

Run by the filename-derived target `test_coefficient_query_v2`, despite the Fortran program declaration being `test_coefficient_query`. A coefficient mismatch can indicate wrong representative indexing, Mach coordinates, alpha dispatch or bracket selection. A status failure prints actual/expected integers before the label. If static preparation passes but a query rejects a crossing grid, that rejection is intentional.

## What these tests do not establish

This is a synthetic pipeline test, not a CRM-file-to-query integration baseline. It does not establish Reynolds interpolation, aerodynamic accuracy, a universal error bound across wide Mach gaps, recovery from arbitrary corrupted arrays, or every status/message path (including explicit forcing of `query_nonfinite_result`). It checks selected input-preservation properties rather than a byte-for-byte immutability comparison. The [CRM validator](interpolation-validation.md) calls low-level interpolators directly and does not validate every prepared-query path.
