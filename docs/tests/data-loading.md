# Dataset discovery, selection and loading

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/dataset_catalogue.f90`](../../src/dataset_catalogue.f90) — [module reference](../modules/dataset_catalogue.md).
- [`src/run_selection.f90`](../../src/run_selection.f90) — [module reference](../modules/run_selection.md).
- [`src/data_io.f90`](../../src/data_io.f90) — [module reference](../modules/data_io.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_data_io.f90`](../../test/test_data_io.f90).
- [`test_crm_run_inspection.f90`](../../test/test_crm_run_inspection.f90).
- [`test_read_crm_run.f90`](../../test/test_read_crm_run.f90).
- [`test_dataset_catalogue.f90`](../../test/test_dataset_catalogue.f90).
- [`test_run_matching.f90`](../../test/test_run_matching.f90).
- [`test_run_selection_dataset.f90`](../../test/test_run_selection_dataset.f90).
- [`test_crm_dataset_reader.f90`](../../test/test_crm_dataset_reader.f90).
- [`test_crm_dataset_integration.f90`](../../test/test_crm_dataset_integration.f90).

## Behavior tested and why

| Program | Behavior checked | Purpose |
|---|---|---|
| `test_data_io` | XFOIL header Reynolds/Mach and four selected alpha/Cl/Cd/Cm rows | Detect header/column parsing regressions. |
| `test_crm_run_inspection` | CRM metadata for run 39 | Ensure selection receives the intended identifiers. |
| `test_read_crm_run` | Six arrays have 35 points; first corrected measurement agrees with constants | Detect incorrect measurement columns or Reynolds scaling. |
| `test_dataset_catalogue` | Discovery succeeds and catalogue is nonempty; prints entries | Basic filesystem/metadata smoke check. |
| `test_run_matching` | Matching configuration accepted; individual CONFIG/CONFTS/CONFT mismatches rejected | Verify exact matching of all configuration fields. |
| `test_run_selection_dataset` | Every returned run matches the requested configuration | Verify filtering on actual metadata. |
| `test_crm_dataset_reader` | Loaded count matches selection and 12 references; run IDs preserved; alpha/Cl sizes agree; first row matches by filename | Check multi-file loading and association with selected metadata. |
| `test_crm_dataset_integration` | Exactly 97 catalogue entries, 12 selected/loaded runs, TEST/RUN/SERIES/configuration preservation, nonempty and equal-length arrays | Exercise catalogue → selection → reader together. |

## Test data, reference values and tolerances

The CRM fixture is `data/phase_2`, selecting `(CONFIG, CONFTS, CONFT) = (1, 1, 99)`. The dataset-reader reference filenames are runs 39, 41, 42, 43, 44, 46, 47, 48, 50, 51, 52 and 53. Its hard-coded first-row arrays are compared with **exact real equality**, with no numeric tolerance. These are parsing regression references from the bundled CSVs, not predictions.

Run 39 metadata is TEST 197, RUN 39, SERIES 11, CONFIG 1, CONFTS 1 and CONFT 99. Its first measurement is:

| Quantity | Reference | Absolute tolerance |
|---|---:|---:|
| Alpha [deg] | -2.89024 | 1e-8 |
| Mach | 0.700381 | 1e-8 |
| Reynolds | 4,995,140 | 1 |
| Cl | -0.144471 | 1e-8 |
| Cd | 0.0159214 | 1e-8 |
| Cm | -0.0278011 | 1e-8 |

For `data/naca0012.csv`, the header references are Re = 1e6 and Mach = 0.5. Rows 1, 2, 146 and 147 use absolute tolerance `1e-10`:

| Quantity | Four expected values |
|---|---|
| Alpha [deg] | -18.5, -18.25, 18.25, 18.5 |
| Cl | -1.2258, -1.2456, 1.2485, 1.2284 |
| Cd | 0.10236, 0.09505, 0.09493, 0.10229 |
| Cm | -0.0012, -0.0049, 0.0046, 0.0008 |

The XFOIL array helper explicitly rejects NaNs. `expected_rows = 147` supplies row indices; the test does **not** separately assert that the complete loaded array has exactly 147 rows.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_data_io
fpm test --profile debug test_crm_run_inspection
fpm test --profile debug test_read_crm_run
fpm test --profile debug test_dataset_catalogue
fpm test --profile debug test_run_matching
fpm test --profile debug test_run_selection_dataset
fpm test --profile debug test_crm_dataset_reader
fpm test --profile debug test_crm_dataset_integration
```

Check the working directory, fixture files and Unix `find` availability before diagnosing parsing. A 97/12 count failure may indicate changed fixture contents or selection metadata. First-row failures point to column mapping, unit conversion or changed CSV values. Use the filename/run label, not discovery order, to locate a reference mismatch.

## What these tests do not establish

These tests do not verify every measurement, arbitrary CSV layouts, malformed-file recovery, absent headers, recursive-discovery edge cases or native Windows support. The standalone catalogue test has no fixed count assertion, and the standalone selection test would accept an empty selection; the combined integration test supplies the stronger 97/12 checks. Cdp and transition-location checks in the XFOIL test are commented out. Successful parsing does not validate wind-tunnel corrections or measurement accuracy.
