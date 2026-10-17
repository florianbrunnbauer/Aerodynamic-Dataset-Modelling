# Dynamic pressure, loads and lift-to-drag ratio

[Test index](README.md) · [Module index](../modules/README.md) · [Repository home](../../README.md)

## Source files covered

- [`src/aerodynamic_properties.f90`](../../src/aerodynamic_properties.f90) — [module reference](../modules/aerodynamic_properties.md).

Shared records come from [`src/types.f90`](../../src/types.f90). Dependencies exercised by an integration path are additional coverage, not independent proof of those modules.

## Test programs

- [`test_aerodynamic_properties.f90`](../../test/test_aerodynamic_properties.f90).

## Behavior tested and why

The test verifies dynamic pressure, coefficient-to-load scaling, signed lift/moment and Cl/Cd, the equivalence of lift/drag and Cl/Cd for the example, quadratic speed scaling and zero-speed loads. Rejection cases cover nonpositive density, negative speed, nonfinite values, invalid pressure/area/chord, zero drag coefficient and numeric overflow. Load failures must clear all three outputs to NaN together.

## Test data, reference values and tolerances

These are synthetic arithmetic references, not CRM geometry. Density 1.2 kg/m³ and speed 100 m/s give q=6000 Pa. With `(Cl,Cd,Cm)=(0.5,0.025,-0.04)`, S=10 m² and chord=2 m, expected loads are L=30000 N, D=1500 N and M=-4800 N·m; Cl/Cd=20. With negative Cl, positive Cm, S=20 and chord=4, references are -60000 N, 3000 N and 19200 N·m. Doubling speed gives q=24000 Pa; zero speed gives zero q and loads. Signed Cl/Cd is also checked at -20.

Numeric tolerance is `abs(actual-reference) <= 1e-12*max(1,abs(reference))`. Status/NaN assertions are exact. `huge`/`tiny` inputs deliberately provoke pressure, ratio and moment overflow; these are error-handling probes, not realistic conditions.

## Running the tests and interpreting failures

Run from the repository root, using the [environment and failure guidance](README.md#running-and-interpreting-the-suite):

```bash
fpm test --profile debug test_aerodynamic_properties
```

Numeric failures point to units, missing factors, coefficient signs or incorrect area/chord scaling. Status/NaN failures indicate validation or partial-output handling. A runtime configured to trap floating-point overflow before the module checks its result can stop during the deliberate overflow cases; inspect compiler flags as well as the reported case.

## What these tests do not establish

It does not verify geometry conventions, coefficient accuracy, moment-reference transformations, atmosphere inputs, trim or aircraft performance. No real-data load baseline or complete CLI workflow is exercised. Tested invalid examples do not exhaust every parameter combination or prove numeric behavior at all extreme scales.
