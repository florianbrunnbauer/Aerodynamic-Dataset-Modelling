# Representative sweep selection

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/dataset_representative.f90`](../../src/dataset_representative.f90) — [module reference](../modules/dataset_representative.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_dataset_representative.f90`](../../test/test_dataset_representative.f90).
- [`test_dataset_representative_integration.f90`](../../test/test_dataset_representative_integration.f90).

## Behavior tested and why

The unit test verifies that alpha span has priority over point count, that more points break equal-span ties, and that a single-run group selects its only member. The integration test runs the real preparation pipeline and checks representative indices resolve to expected CRM run IDs. This protects the distinction between array positions and metadata run numbers.

## Test data, reference values and tolerances

Synthetic runs 101 and 102 both span `[-2,4]` degrees with 4 and 7 points; 102 must win. Run 103 has 9 points but spans only `[0,4]`, so it must lose. Run 104 alone spans `[-1,1]` and represents its second Mach group. Expected dataset positions are 2 and 4.

The integration fixture `(1,1,99)` expects 97 catalogue entries, 12 selected runs and one nominal Re group at `5e6`. At nominal Mach `[0.70,0.75,0.80,0.83,0.85,0.86,0.87,0.88]`, representatives must be CRM runs `[39,41,42,43,44,46,47,48]`. Each representative index must be within the loaded dataset. Labels and indices use exact comparisons; no numeric reference tolerance is applied.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_dataset_representative
fpm test --profile debug test_dataset_representative_integration
```

For a wrong representative, inspect alpha endpoint span first, then sample count, then the group membership and index mapping. The integration report displays selected real runs. A changed CSV sweep can legitimately change selection, but update the expected IDs only after checking why.

## What these tests do not establish

They do not establish that the chosen sweep is the most accurate or least noisy, nor test every empty/malformed grouping case, near-equal-span boundary or final tie. They do not prove averaging, uncertainty reduction or universal preservation of all input fields. Repeatability is evaluated separately.
