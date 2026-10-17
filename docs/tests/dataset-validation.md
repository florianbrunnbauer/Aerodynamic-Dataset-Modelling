# Run and dataset validity

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/dataset_validation.f90`](../../src/dataset_validation.f90) — [module reference](../modules/dataset_validation.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_run_validation.f90`](../../test/test_run_validation.f90).
- [`test_dataset_validation.f90`](../../test/test_dataset_validation.f90).
- [`test_dataset_validation_integration.f90`](../../test/test_dataset_validation_integration.f90).

## Behavior tested and why

`test_run_validation` accepts a four-point valid sweep and checks its point count, sorted flag and zero duplicate/invalid counts. It then independently injects a duplicate alpha, unsorted alpha, one NaN in Cl, and a shorter Cm array, checking rejection and the relevant diagnostics where asserted.

`test_dataset_validation` assembles one valid, one duplicate-alpha and one unsorted run. It checks aggregate validity/counts and selected per-run diagnostics. The integration program loads the bundled CRM configuration and requires every selected run to pass. Together these checks protect the structural assumptions needed before grouping or interpolation.

## Test data, reference values and tolerances

The synthetic base uses alpha `[-2, 0, 1, 2]` degrees, Mach `0.85`, Re `5e6`, Cl `[-0.2, 0, 0.1, 0.2]`, Cd `[0.030, 0.020, 0.021, 0.025]`, and Cm `-0.05`. Expected dataset counts are 3 total, 1 valid and 2 invalid; a duplicated alpha or injected NaN is counted once in the respective run case.

The integration fixture expects 97 catalogue entries, 12 selected runs for `(1,1,99)`, 12 valid and 0 invalid runs. Assertions compare flags and integer counts exactly; there is no floating-point reference tolerance in these tests. They do not probe the validator's alpha-equality tolerance boundary.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_run_validation
fpm test --profile debug test_dataset_validation
fpm test --profile debug test_dataset_validation_integration
```

A rejected synthetic valid run indicates an unexpected rule change or diagnostic regression. An accepted mutation indicates a missing structural guard. The run-level failure helper prints points, duplicates, invalid values, alpha ordering and Mach/Re validity. For integration failures, separate discovery/reading failures from the final validation report.

## What these tests do not establish

They do not exhaustively test unallocated/empty arrays, every nonfinite field, nonpositive Mach/Re, single-point runs or near-duplicate alpha thresholds. Validity means conformance to implemented structural rules; it does not establish aerodynamic plausibility, sufficient points for Akima, or a noncrossing query-specific Mach grid. The coefficient-query tests cover examples that pass static validation but fail the local Mach-grid check.
