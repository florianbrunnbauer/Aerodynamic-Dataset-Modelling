# Nominal Reynolds and Mach grouping

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/dataset_grouping.f90`](../../src/dataset_grouping.f90) — [module reference](../modules/dataset_grouping.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_dataset_grouping.f90`](../../test/test_dataset_grouping.f90).
- [`test_dataset_grouping_integration.f90`](../../test/test_dataset_grouping_integration.f90).

## Behavior tested and why

The unit test groups six synthetic runs by measured means and checks nominal group counts and run membership, including retention of repeats and exclusion of a run belonging to another Mach group. The integration test validates the selected real data before grouping and checks the complete nominal group layout. These assertions protect index-based organization without relying on filesystem order.

## Test data, reference values and tolerances

Synthetic run IDs 101/102/104 have mean Mach/Re `(0.7005,4.99e6)`, `(0.6995,5.01e6)` and `(0.7015,4.98e6)` and must share the nominal `(5e6,0.70)` cell. Run 103 `(0.7508,5e6)` belongs to `(5e6,0.75)`. Runs 201 `(0.7007,19.75e6)` and 202 `(0.7492,19.85e6)` produce the 19.8-million group with Mach 0.70 and 0.75. Each run has three points with Mach deviations ±0.0002 and Reynolds multipliers 0.999, 1 and 1.001.

For CRM `(1,1,99)`, 97 catalogue entries lead to 12 runs, one Re group at `5e6`, and:

| Nominal Mach | 0.70 | 0.75 | 0.80 | 0.83 | 0.85 | 0.86 | 0.87 | 0.88 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Runs in cell | 3 | 1 | 1 | 1 | 3 | 1 | 1 | 1 |

Labels are located by exact `findloc` equality and counts/memberships are exact; no numerical assertion tolerance is used. The examples exercise classification tolerance indirectly, without testing its boundaries.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_dataset_grouping
fpm test --profile debug test_dataset_grouping_integration
```

A missing label or wrong membership points to measured-mean calculation, nominal classification or stored run indices. The integration test prints the grouping report. Its opening banner incorrectly says dataset validation integration; identify it by the executable/source name and final grouping messages.

## What these tests do not establish

The tests do not cover every recognized Reynolds/Mach level, threshold-edge classification, out-of-catalogue conditions or all invalid-input statuses. Group membership does not establish identical physical conditions, agreement between repeats, interpolation support at every alpha, or a complete rectangular Mach/Re grid.
