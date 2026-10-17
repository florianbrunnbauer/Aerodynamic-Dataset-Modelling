# Held-out interpolation validation

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/data_io.f90`](../../src/data_io.f90) — [module reference](../modules/data_io.md).
- [`src/linear_interpolation.f90`](../../src/linear_interpolation.f90) — [module reference](../modules/linear_interpolation.md).
- [`src/pchip_interpolation.f90`](../../src/pchip_interpolation.f90) — [module reference](../modules/pchip_interpolation.md).
- [`src/akima_interpolation.f90`](../../src/akima_interpolation.f90) — [module reference](../modules/akima_interpolation.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`validate_linear_interpolation.f90`](../../test/validate_linear_interpolation.f90).
- [`validate_interpolation_methods.f90`](../../test/validate_interpolation_methods.f90).

## Behavior tested and why

These programs remove known coefficient observations from training and compare predictions with the held-out values. Their question is prediction error on specified data, distinct from regression checks of expected algorithm/API behavior. Both are located under `test/` and automatically run by the current fpm configuration.

### NACA fixed holdout

`validate_linear_interpolation` removes rows 21, 42, 63, 84, 105 and 126 **together**, trains on the remaining rows, and predicts Cl/Cd/Cm at the six removed alpha coordinates. It computes signed errors, absolute errors, maximum absolute error and RMSE. This is a fixed six-row holdout, not a separate leave-one-out fold per point. It enforces the fixture-specific limits below and can fail CI on excessive error.

### CRM method comparison

`validate_interpolation_methods` loads eight explicitly listed corrected CRM sweeps directly through inspection/reading, checks them, and sorts entire runs by measured mean Mach. It compares linear, PCHIP and classical Akima coefficient interpolation in alpha, always followed by **linear Mach interpolation** where needed.

1. **Alpha leave-one-point-out:** remove one interior point at a time in each sweep, retaining its other points. Endpoints are excluded to avoid extrapolation. Compare the prediction at the removed alpha against that point's measured coefficient.
2. **Leave-one-Mach-sweep-out:** exclude one whole interior Mach sweep. Only its immediate surviving lower/upper neighbors train that fold. Evaluate target measurements within their common alpha interval and measured Mach bracket; skip unsupported points. The two boundary Mach sweeps are not targets.

Support filtering is independent of coefficient method, so methods use the same eligible points within each fold. Pointwise Mach mode is a source constant, `use_pointwise_mach=.true.`: training Mach coordinates are interpolated linearly in alpha, and the target coordinate is its measured Mach. Setting the constant false requires rebuilding and uses sweep means instead. There is no command-line switch for that choice.

## Test data, reference values and tolerances

### NACA references and acceptance limits

The reference is the held-out Cl/Cd/Cm in `data/naca0012.csv`, an XFOIL polar at Re=1e6 and Mach=0.5. All error limits are in dimensionless coefficient units:

| Coefficient | Maximum absolute error limit | RMSE limit |
|---|---:|---:|
| Cl | 6e-3 | 3e-3 |
| Cd | 4e-4 | 2e-4 |
| Cm | 8e-4 | 4e-4 |

A metric greater than its limit fails; equality passes. These are hard-coded validation thresholds, not machine-roundoff tolerances or demonstrated universal bounds. The current source prints pass/fail information but has detailed successful metric prints commented out; it exports no CSV. Its threshold comparisons do not explicitly reject NaNs.

### CRM data and metrics

Files are `t197R39.csv`, `t197R41.csv`, `t197R42.csv`, `t197R43.csv`, `t197R44.csv`, `t197R46.csv`, `t197R47.csv` and `t197R48.csv` under the chosen directory. Runs must agree in TEST/CONFIG/CONFTS/CONFT, match their expected IDs, have at least six points, equal-sized finite arrays, strictly increasing alpha and positive Mach/Re. Mean Reynolds must be within **±5% of 5e6**. That 5% is a data-selection guard, not an accuracy acceptance limit. Finite unique sweep-mean Mach levels and nonempty supported Mach folds are required.

For signed error `e=predicted−reference`, reported coefficient metrics are:

- `MAE = sum(abs(e))/N`
- `RMSE = sqrt(sum(e**2)/N)`
- `max_abs_error = max(abs(e))`

Alpha references are removed samples; Mach references are measurements from the excluded sweep. Pooled console results are **point-weighted**, not an unweighted average of fold metrics. There is **no prediction-accuracy pass/fail threshold** for the CRM comparison. Nonfinite results/errors and invalid setup are fatal.

The default outputs, overwritten on each run, are:

| File | Contents |
|---|---|
| `interpolation_validation_points.csv` | Validation kind, held-out and training run IDs, alpha/Mach and bracket coordinates, method/coefficient, reference, prediction and signed error. |
| `interpolation_validation_summary.csv` | Per-fold/method/coefficient counts (`n_evaluated`, `n_candidates`, skipped alpha/Mach), mean Mach labels, MAE, RMSE and maximum error. |

Alpha folds have `n_candidates = n_points−2` and zero skipped counts. Mach folds start with all target points and record support exclusions. Summary CSVs contain fold rows; pooled metrics are printed to the console rather than added as pooled CSV rows.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug validate_linear_interpolation
fpm test --profile debug validate_interpolation_methods
```

The commands above use default paths. To supply a CRM input directory and output prefix, run:

```bash
fpm test --profile debug validate_interpolation_methods -- data/phase_2 interpolation_validation
```

The program accepts at most two arguments. A prefix such as `results/comparison` writes `results/comparison_points.csv` and `results/comparison_summary.csv`; create the parent directory first. Reusing a prefix replaces existing outputs.

For NACA failures, compare the reported coefficient metric with its limit and inspect changed input rows or interpolation behavior. A CRM nonzero exit means setup, support, I/O or numerical execution failed; a successful exit does **not** mean prediction errors are acceptable for an application. Inspect counts, skipped points, fold gap widths and coefficient-specific errors before comparing methods. Keep alpha-only and alpha+Mach results separate, and do not compare raw Cl/Cd/Cm error magnitudes as though their scales were identical.

## What these tests do not establish

Neither experiment gives universal error bounds, confidence intervals, experimental uncertainty or aerodynamic validity beyond the chosen samples. NACA uses numerical XFOIL output, not independent wind-tunnel truth. CRM holds out observations from one configuration/nominal Reynolds group; it performs no Reynolds interpolation, repeat averaging, boundary extrapolation or independent campaign validation. Mach-fold error includes both alpha and Mach interpolation effects and measurement variation; removing a sweep changes gap width.

The CRM program bypasses catalogue selection, grouping, representative selection and `query_coefficients`, using a fixed retained-run setup and low-level interpolation directly. It therefore does not validate every current prepared-query path, missing-middle-sweep policy, flight-condition acceptance, atmosphere or dimensional loads. See [coefficient-query regression tests](coefficient-queries.md) for those query contracts.
