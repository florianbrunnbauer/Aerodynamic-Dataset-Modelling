# Run and dataset characterisation

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/dataset_characterisation.f90`](../../src/dataset_characterisation.f90) — [module reference](../modules/dataset_characterisation.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_dataset_characterisation.f90`](../../test/test_dataset_characterisation.f90).
- [`test_dataset_characterisation_integration.f90`](../../test/test_dataset_characterisation_integration.f90).

## Behavior tested and why

The unit test checks point count, alpha endpoints, measured Mach mean/min/max and Reynolds mean for one controlled sweep. The integration test reads and validates the selected CRM data, checks the characterisation has 12 runs and prints its report. This verifies basic summaries and compatibility with the preparation pipeline; printed fields are not automatically numeric assertions.

## Test data, reference values and tolerances

The synthetic sweep has alpha `[-2,0,2,4]`, Mach `[0.849,0.850,0.851,0.850]`, and Re `[4.98e6,5e6,5.02e6,5e6]`. Expected values are 4 points, alpha min/max `-2/4` degrees, Mach mean/min/max `0.850/0.849/0.851` and Reynolds mean `5e6`. Numeric comparisons require absolute error **less than** `1e-10`; the count is exact.

The integration test expects 97 catalogue entries and 12 selected/characterised runs for CRM `(1,1,99)`, with successful reading and validation. It does not compare real-data summary numbers to fixed references.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_dataset_characterisation
fpm test --profile debug test_dataset_characterisation_integration
```

A synthetic mean mismatch suggests averaging or field-assignment errors; endpoint failures suggest incorrect min/max handling. An integration count failure concerns selection or result assembly. Its opening banner says dataset validation integration; use the executable name to distinguish it. Inspect the report manually when investigating unasserted fields.

## What these tests do not establish

There are no assertions for all statistics exposed by the module, all coefficient fields, Reynolds extrema, invalid inputs, empty datasets or exact report formatting. The synthetic coefficient arrays are allocated but not populated; they supply no coefficient-statistics oracle. Real report output is a smoke check, not a regression baseline for every printed value.
