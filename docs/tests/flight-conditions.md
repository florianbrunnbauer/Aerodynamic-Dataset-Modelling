# Flight-condition acceptance and Reynolds-matched altitude

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/flight_condition_validation.f90`](../../src/flight_condition_validation.f90) — [module reference](../modules/flight_condition_validation.md).
- [`src/standard_atmosphere.f90`](../../src/standard_atmosphere.f90) — [module reference](../modules/standard_atmosphere.md).
- [`src/aerodynamic_properties.f90`](../../src/aerodynamic_properties.f90) — [module reference](../modules/aerodynamic_properties.md).
- [`src/coefficient_query.f90`](../../src/coefficient_query.f90) — [module reference](../modules/coefficient_query.md).
- [`src/dataset_validation.f90`](../../src/dataset_validation.f90) — [module reference](../modules/dataset_validation.md).
- [`src/dataset_grouping.f90`](../../src/dataset_grouping.f90) — [module reference](../modules/dataset_grouping.md).
- [`src/dataset_representative.f90`](../../src/dataset_representative.f90) — [module reference](../modules/dataset_representative.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_flight_condition_validation.f90`](../../test/test_flight_condition_validation.f90).

## Behavior tested and why

The program checks accepted states, speed/q/Re/coefficients, representative-only Reynolds diagnostics, explicit Reynolds-group choice, and forwarding of alpha methods and mean-Mach mode. It checks mismatch rejection before querying coefficients, inclusive policy boundaries, retained physical diagnostics after a mismatch, and underlying atmosphere/query statuses after their failures.

It covers invalid inputs, empty data/structures, bad representative indices, invalid nominal Reynolds and numeric overflow; rejected conditions must be unaccepted with NaN coefficients. Synthetic integration runs through actual validation, grouping and representative selection for two Reynolds groups. Another case verifies that flight queries bridge a middle sweep without alpha support.

The altitude solver must recover a known interior root, accept exact roots at 0 and 32000 m, reject targets outside the achievable range and reject invalid solver tolerance/target. Its interior solution is fed back through full flight validation.

## Test data, reference values and tolerances

The synthetic condition is 10000 m geometric altitude, Mach 0.75, alpha 1 degree and nominal Re=5e6. The test first calculates the atmosphere and chooses a **synthetic fixed reference length** `ell=Re*mu/(rho*0.75*a)` to make this condition match. This is a fixture construction, not a production policy for changing geometry to pass validation.

Two sweeps at Mach 0.70/0.80 use alpha `[0,0.5,1.5,2.5,4]` and the affine equations on the [coefficient-query page](coefficient-queries.md). Expected coefficients are Cl=1.6, Cd=0.028 and Cm=-0.0345. A second group at Re=30e6 needs six times the reference length and has Cl=11.6. Offset/short repeated runs must not alter representative-only results.

Most numeric comparisons use `abs(actual-reference) <= 1e-12*max(1,abs(reference))`. Increasing length by 2% must produce a 0.02 mismatch (comparison tolerance `1e-11`), be rejected by a 0.01 policy and be accepted at the 0.02 boundary. Policy inputs are fractions, not percentages; zero mismatch tolerance is exercised. A 5e6 physical Re against the 30e6 group has expected relative mismatch 5/6. Modified representative Reynolds arrays must report extrema 5e6−1e4 and 5e6+2e4 without changing nominal Re.

The interior altitude search requests `altitude_tolerance=1e-5 m`, must recover 10000 m with absolute error `<1e-5 m`, and must pass revalidation at relative Re tolerance `1e-8`. Endpoint altitude roots use exact equality. All status/acceptance/NaN predicates are exact.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_flight_condition_validation
```

Inspect the top-level flight status first, then `atmosphere_stat` or `coefficient_stat`. On Reynolds mismatch, coefficient status is expected to remain `flight_not_evaluated` and speed/q remain available. An altitude-search failure can concern input validity, a missing root within 0–32 km, or solver accuracy. The matched fixture depends on the atmosphere module, so an atmosphere regression may propagate here.

## What these tests do not establish

This verifies acceptance policy and module integration on synthetic data. It does not establish aerodynamic similarity solely from Reynolds agreement, real-flight validity, CRM-file-to-flight integration, uncertainty limits, trim, lift-weight balance or an operational envelope. Some reference physics is calculated with the same atmosphere implementation, so the independent rounded-reference atmosphere tests remain important. The tests do not validate every CLI prompt or every status-message string.
