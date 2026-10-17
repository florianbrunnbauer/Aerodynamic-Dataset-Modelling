# Tests and interpolation validation

[Repository home](../../README.md) · [Architecture](../architecture.md) · [Module index](../modules/README.md)

This index documents the current executable test sources by the functionality they verify. Related unit and integration programs share a page. Each page identifies covered source files, assertions and rationale, fixtures/reference values/tolerances, execution and failure diagnosis, and limits of the evidence.

The repository has **26 regression/integration programs** and **two held-out interpolation validation programs**. The distinction is their purpose, not their folder: all 28 are automatically discovered under `test/` by `fpm.toml` (`auto-tests = true`). Synthetic integration tests also occur inside the coefficient-query and flight-condition executables, not only files named `_integration`.

Regression tests check expected behavior: known numeric results, structural contracts, selection rules and failure statuses. Held-out validation measures prediction error after excluding data from training. The NACA validation additionally enforces fixed error thresholds; the CRM comparison has no accuracy threshold. See the separate [interpolation validation page](interpolation-validation.md).

## Functionality index

Use each listed name as the fpm test target (without `.f90`). The source-file links and exact checks are on the corresponding page.

| Documentation page | Executable targets |
|---|---|
| [Dataset discovery, selection and loading](data-loading.md) | `test_data_io`, `test_crm_run_inspection`, `test_read_crm_run`, `test_dataset_catalogue`, `test_run_matching`, `test_run_selection_dataset`, `test_crm_dataset_reader`, `test_crm_dataset_integration` |
| [Run and dataset validity](dataset-validation.md) | `test_run_validation`, `test_dataset_validation`, `test_dataset_validation_integration` |
| [Nominal Reynolds and Mach grouping](dataset-grouping.md) | `test_dataset_grouping`, `test_dataset_grouping_integration` |
| [Representative sweep selection](representative-selection.md) | `test_dataset_representative`, `test_dataset_representative_integration` |
| [Run and dataset characterisation](dataset-characterisation.md) | `test_dataset_characterisation`, `test_dataset_characterisation_integration` |
| [Repeatability across repeated sweeps](dataset-repeatability.md) | `test_dataset_repeatability`, `test_dataset_repeatability_integration` |
| [Interpolation algorithm regression tests](interpolation-regression.md) | `test_linear_interpolation`, `test_pchip_interpolation`, `test_akima_interpolation` |
| [Prepared coefficient queries and supported Mach gaps](coefficient-queries.md) | `test_coefficient_query_v2` |
| [Standard atmosphere numerical behavior](standard-atmosphere.md) | `test_standard_atmosphere` |
| [Dynamic pressure, loads and lift-to-drag ratio](aerodynamic-properties.md) | `test_aerodynamic_properties` |
| [Flight-condition acceptance and Reynolds-matched altitude](flight-conditions.md) | `test_flight_condition_validation` |
| [Held-out interpolation validation](interpolation-validation.md) | `validate_linear_interpolation`, `validate_interpolation_methods` |

## Running and interpreting the suite

Use a modern Fortran compiler and fpm, in Linux or WSL, from the repository root containing `fpm.toml`. Catalogue-based tests require the implementation's Unix `find` command and `/tmp`. Preserve `data/naca0012.csv` and the bundled `data/phase_2` tree. There are no external Fortran library dependencies; fixed SciPy-derived reference constants do not require Python/SciPy at test time.

```bash
fpm build --profile debug
fpm test --profile debug
```

Run a single program by its filename stem:

```bash
fpm test --profile debug test_dataset_grouping
fpm test --profile debug test_dataset_grouping_integration
fpm test --profile debug test_coefficient_query_v2
```

The last target's source declares `program test_coefficient_query`; the target remains the filename stem. Each functionality page lists exact commands for its programs.

A successful regression executable finishes normally and generally prints `PASSED`, `PASS: ... assertions` or an equivalent success message. Some programs stop on the first failed check; others accumulate `FAILED` messages and call `error stop 1` at the end. Do not infer coverage from the count of printed lines or assume every printed report field is asserted. Some older opening banners are copied from other programs: use the fpm target/source and final messages to identify the test.

Separate compiler/build failures from executable assertion failures. For a failing executable:

1. Rerun that target alone and inspect its first failure label, actual/expected values or status.
2. For real-data failures, confirm root-relative paths and unchanged fixture contents/configuration before changing code or expected values.
3. For synthetic numeric failures, inspect the documented reference equation and tolerance. Tolerances vary by test; they are not interchangeable.
4. For expected rejection cases, check the status and output-state contract. PCHIP/Akima parents deliberately run failing child processes and verify their diagnostics; a passing parent means those rejections worked.

Integer counts, flags, status codes and nominal labels generally use exact comparisons. Numeric tests variously use absolute error, relative error or `tol*max(1,abs(reference))`; individual pages state the implemented rule. These small numeric tolerances are regression comparison policies, not measurement uncertainty. CRM fixture count checks intentionally couple several integration programs to 97 catalogue entries and 12 selected `(CONFIG,CONFTS,CONFT)=(1,1,99)` runs; replacing/expanding the dataset requires reviewing those baselines.

The suite writes CRM validation CSVs in the working directory by default and replaces them on repeat runs. PCHIP/Akima rejection tests temporarily write method-specific log files and delete them after checking. Avoid concurrent copies of the same target in the same working directory. Nondefault floating-point trap flags may intercept deliberate overflow cases before module status handling executes.

## Continuous integration

The repository's [Fortran Tests workflow](../../.github/workflows/tests.yml) is configured for pushes, pull requests and manual dispatches. It uses Ubuntu 24.04, GCC/GFortran 14 and fpm 0.13.0, checks key fixture paths, lists discovered test sources, builds in debug mode and runs `fpm test --profile debug`. Both validation executables consequently run in CI too. The workflow currently does not upload their result CSVs as artifacts or enforce CRM error limits.

## Scope of the evidence

These pages describe assertions present in the uploaded source, not a claim that the suite has been executed while preparing this documentation. There is no dedicated `types` executable; shared records are exercised through readers, preparation, queries, atmosphere and flight-condition tests. There is no automated CLI prompt/session test in the current suite. Printed reports generally lack exact formatting baselines, and several module failure/status-message paths have no dedicated test. Page-specific exclusions explain the important remaining limits.

A passing suite supports the implemented contracts on its fixtures. It does not certify wind-tunnel correction accuracy, universal interpolation error bounds, real weather, aircraft trim or an operational flight envelope.
