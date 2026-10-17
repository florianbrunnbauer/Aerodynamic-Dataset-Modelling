# Module reference

[Repository home](../../README.md) · [Architecture](../architecture.md)

This reference covers every module currently in `src/`. Each page documents its preparation contract, public procedures and arguments, units, algorithms, failure handling, usage example, dependencies and links to functionality-based test documentation and relevant test sources. The `types` page instead lists the shared records and every component.

Start with the architecture and shared types, then follow catalogue → selection → reading → validation → grouping → representative selection. Read the coefficient and flight-condition pages for repeated queries. Characterisation and repeatability are optional analysis paths.

| Module | Responsibility |
|---|---|
| [`types`](types.md) | Shared measurement, grouping, result and session records. |
| [`data_io`](data_io.md) | CRM metadata/full readers and XFOIL example reader. |
| [`dataset_catalogue`](dataset_catalogue.md) | Recursive CSV discovery and metadata catalogue. |
| [`run_selection`](run_selection.md) | Exact configuration selection. |
| [`dataset_validation`](dataset_validation.md) | Dataset and run validation reports. |
| [`dataset_characterisation`](dataset_characterisation.md) | Summary statistics and printed descriptions. |
| [`dataset_grouping`](dataset_grouping.md) | Nominal Reynolds/Mach classification retaining repeats. |
| [`dataset_representative`](dataset_representative.md) | One representative run index per nominal combination. |
| [`dataset_repeatability`](dataset_repeatability.md) | Common-alpha repeat comparison and spread statistics. |
| [`linear_interpolation`](linear_interpolation.md) | Piecewise linear scalar interpolation. |
| [`pchip_interpolation`](pchip_interpolation.md) | Shape-preserving piecewise cubic interpolation. |
| [`akima_interpolation`](akima_interpolation.md) | Classical Akima piecewise cubic interpolation. |
| [`coefficient_query`](coefficient_query.md) | Alpha interpolation and supported Mach bracketing. |
| [`standard_atmosphere`](standard_atmosphere.md) | Dry standard atmosphere over 0–32 km geometric altitude. |
| [`flight_condition_validation`](flight_condition_validation.md) | Reynolds policy, coefficient delegation and altitude solver. |
| [`aerodynamic_properties`](aerodynamic_properties.md) | Dynamic pressure, dimensional loads and Cl/Cd. |

## Using the examples

Examples are complete Fortran programs, intended to be linked with the project's modules and run from the repository root. They use the bundled CRM configuration where needed. They are reference snippets rather than additional application executables; copying all of them into `app/` would add multiple programs. Geometry values explicitly marked illustrative are not CRM geometry definitions.

Preparation examples check each status and validation report before continuing. Query examples use group position 1 for brevity; an application should present/select the intended nominal Reynolds group explicitly. Keep `data%runs` ordering unchanged after building index structures.

## Tests

The [test index](../tests/README.md) groups related unit and integration programs by functionality. Each module page links directly to its corresponding coverage, fixtures, reference values, tolerances, execution commands and limitations, while retaining links to the test sources.

Run `fpm test --profile debug` from the repository root. The [held-out interpolation validation page](../tests/interpolation-validation.md) separately explains the NACA fixed holdout and CRM method comparison, including their different acceptance rules and exported results. A coverage link does not imply that every edge case or aerodynamic condition is validated.
