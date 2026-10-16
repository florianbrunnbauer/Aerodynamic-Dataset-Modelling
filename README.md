# Aerodynamic Dataset Modelling

A Fortran command-line tool for exploring aerodynamic datasets and estimating lift, drag, and pitching moment at supported flight conditions.

The application prepares NASA Common Research Model (CRM) wind-tunnel runs, queries aerodynamic coefficients in angle of attack and Mach number, and combines them with a standard atmosphere and user-supplied reference geometry to calculate dimensional loads. The project also includes an XFOIL NACA 0012 example and numerical validation programs.

[Quick start](#quick-start) · [Using the application](#using-the-application) · [Model and limits](#model-and-limits) · [Documentation](#documentation) · [Tests](#tests-and-interpolation-validation) · [Data and references](#data-and-references)

## What it does

- Catalogues CRM CSV files and selects runs by aircraft configuration.
- Validates measurements, groups runs by nominal Reynolds and Mach number, and selects one representative sweep per combination.
- Interpolates `Cl`, `Cd`, and `Cm` using linear, PCHIP, or classical Akima interpolation in angle of attack, followed by linear interpolation in Mach.
- Calculates atmospheric properties, true airspeed, dynamic pressure, Reynolds number, aerodynamic loads, and signed `Cl/Cd`.
- Checks an entered altitude or finds an altitude matching the selected dataset Reynolds number.
- Provides unit tests, dataset integration tests, repeatability analysis, and interpolation validation.

## Quick start

### Requirements

- A modern Fortran compiler, such as GNU Fortran, with support for the language features used by the project, including `findloc`.
- [Fortran Package Manager (fpm)](https://fpm.fortran-lang.org/install/index.html), available on your `PATH`.
- A Linux environment, or WSL with Ubuntu on Windows. The catalogue currently uses the Unix `find` command and `/tmp`; native Windows execution is not supported by that implementation.

There are no external Fortran library dependencies in `fpm.toml`. The included GitHub Actions workflow is configured for Ubuntu 24.04, GNU Fortran 14, and fpm 0.13.0.

### Build and run

Clone or download the repository, then open a terminal in its root directory—the directory containing `fpm.toml`:

```bash
gfortran --version
fpm --version

fpm build --profile debug
fpm run
```

Run from the repository root so the relative paths to the bundled datasets resolve correctly. The program asks for the CSV directory interactively; its default is `data/phase_2`.

## Using the application

1. **Choose a CRM data directory.** The catalogue searches recursively for CSV files and inspects their run metadata. Use a directory containing CRM run files rather than mixing in unrelated CSV formats.
2. **Select a configuration** using `CONFIG`, `CONFTS`, and `CONFT`. The current defaults are `1`, `1`, and `99`, respectively. Consult the NASA run log for the meaning of these codes.
3. **Enter reference geometry:** area in m², Reynolds reference length in m, and pitching-moment reference chord in m. Use the definitions and scale appropriate to the dataset; the two reference lengths are separate inputs.
4. **Set the allowed Reynolds mismatch as a percentage.** Entering `1` means 1%. This is an acceptance policy, not an experimentally established accuracy bound.
5. **Select one of the available nominal Reynolds groups** from the displayed menu.
6. Choose **Query a flight condition**, then enter Mach and angle of attack in degrees.
7. Select the alpha interpolation method and Mach-coordinate mode. Defaults are **Akima** and **measured Mach at the requested alpha**. Sweep-mean measured Mach is also available.
8. Either enter a **geometric altitude between 0 and 32,000 m**, or ask the program to find a Reynolds-matched altitude for the chosen Mach and fixed reference length.

Accepted conditions display coefficients, `Cl/Cd`, atmospheric properties, Reynolds diagnostics, lift and drag in N, and pitching moment in N·m. Rejected conditions display the reason and any available diagnostics; loads are calculated only after acceptance.

The menu also lets you change the dataset/configuration or geometry/policy. Press Enter to accept a displayed default, enter `q` at any prompt to quit, or select `0` in the main menu to exit.

## How the data pipeline works

Preparation runs once per dataset/configuration selection:

1. **Catalogue:** inspect CSV metadata without loading every measurement array.
2. **Select:** retain runs matching the requested configuration.
3. **Read:** load the selected runs into `data%runs`.
4. **Validate:** check allocation, array lengths, finite values, alpha ordering, duplicate alpha measurements, and Mach/Reynolds validity.
5. **Group:** classify runs by their measured mean Reynolds and Mach numbers.
6. **Choose representatives:** select the sweep with the widest alpha range for each Reynolds/Mach combination; use measurement count to break range ties.

`data` retains all selected runs, including repeats. `structure` stores the nominal Reynolds/Mach groups and indices of their representative runs. Repeated runs are not averaged or deleted from the measurement storage.

For each query, the coefficient model uses representatives from the selected Reynolds group. It evaluates the coefficients in alpha within the required sweeps, then interpolates those values linearly in Mach. Sweeps without the requested alpha are skipped: the model can interpolate across a gap using the nearest supported sweep on either side. It rejects extrapolation and duplicate or crossing local Mach coordinates.

## Model and limits

The implemented load calculations are:

$$
V=Ma\cdot a,\qquad q=\frac{1}{2}\rho V^2,\qquad
Re=\frac{\rho V\ell_{\mathrm{ref}}}{\mu}
$$

$$
L=qS_{\mathrm{ref}}C_l,\qquad D=qS_{\mathrm{ref}}C_d,\qquad
M=qS_{\mathrm{ref}}c_{\mathrm{ref}}C_m.
$$

- **Reynolds number is a discrete dataset selection.** There is no interpolation or correction between Reynolds groups. The calculated flight Reynolds number must satisfy the caller's tolerance relative to the selected nominal group.
- **Atmosphere:** the implemented U.S. Standard Atmosphere 1976 model covers 0–32 km geometric altitude and returns temperature, pressure, density, sound speed, and dynamic viscosity.
- **Supported conditions depend on the selected configuration and available sweeps.** The grouping code recognizes nominal Reynolds levels of 5, 19.8, and 30 million, and Mach levels from 0.70 to 0.92. This does not imply that every combination is present in the supplied data.
- **Mach coordinates matter.** Nominal Mach labels identify and order sweeps. Interpolation uses measured `Mach(alpha)` by default, or measured sweep means when selected. The CLI restricts input to the nominal Mach bounds; the query then checks actual alpha/Mach support.
- **Interpolation is not an accuracy guarantee.** Wider gaps between supported sweeps may increase error. Akima requires at least five points in each required sweep; linear and PCHIP accept two.
- **Reference conventions are preserved.** Loads retain coefficient signs and the dataset's pitching-moment reference point. Geometry inputs must be consistent with the coefficient definitions.
- **This is a dataset-based analysis tool.** It does not establish trim, lift–weight balance, aircraft performance limits, dynamic stability, or an operational flight envelope. `Cl/Cd` is calculated for the requested condition; an automatic efficiency search is not implemented.

## Documentation

Start with the [architecture](docs/architecture.md) for data ownership, the preparation/query flow, validation responsibilities and numerical policy. The [module reference](docs/modules/README.md) documents every module's public interface, units, behavior, errors, examples and test links.

| Area | Module references |
|---|---|
| Shared records | [types](docs/modules/types.md) |
| Discovery and loading | [dataset_catalogue](docs/modules/dataset_catalogue.md), [run_selection](docs/modules/run_selection.md), [data_io](docs/modules/data_io.md) |
| Preparation | [dataset_validation](docs/modules/dataset_validation.md), [dataset_grouping](docs/modules/dataset_grouping.md), [dataset_representative](docs/modules/dataset_representative.md) |
| Diagnostics | [dataset_characterisation](docs/modules/dataset_characterisation.md), [dataset_repeatability](docs/modules/dataset_repeatability.md) |
| Interpolation | [linear_interpolation](docs/modules/linear_interpolation.md), [pchip_interpolation](docs/modules/pchip_interpolation.md), [akima_interpolation](docs/modules/akima_interpolation.md) |
| Queries and physics | [coefficient_query](docs/modules/coefficient_query.md), [standard_atmosphere](docs/modules/standard_atmosphere.md), [flight_condition_validation](docs/modules/flight_condition_validation.md), [aerodynamic_properties](docs/modules/aerodynamic_properties.md) |

## Tests and interpolation validation

Run the complete suite from the repository root:

```bash
fpm test --profile debug
```

The suite includes numerical interpolation tests, synthetic preparation tests, integration tests using the bundled CRM files, atmosphere and load tests, and flight-condition validation. Some programs create temporary files or export validation results. The [CI workflow](.github/workflows/tests.yml) builds and runs the suite on pushes, pull requests, and manual dispatches.

To run the atmosphere test alone:

```bash
fpm test test_standard_atmosphere
```

For the CRM interpolation comparison:

```bash
fpm test validate_interpolation_methods -- data/phase_2 interpolation_validation
```

This program compares linear, PCHIP, and Akima alpha interpolation through leave-one-alpha-point-out and leave-one-Mach-sweep-out validation, with linear Mach interpolation. It reports MAE, RMSE, and maximum absolute error for `Cl`, `Cd`, and `Cm`, and writes:

- `interpolation_validation_points.csv`
- `interpolation_validation_summary.csv`

These results characterize the tested curves and held-out intervals; they are not error bounds for every possible query.

## Repository guide

| Location | Purpose |
|---|---|
| [`app/main.f90`](app/main.f90) | Interactive application and result reporting |
| [`src/`](src/) | Readers, preparation pipeline, interpolation, coefficient queries, atmosphere, flight-condition checks, and load calculations |
| [`docs/`](docs/architecture.md) | Architecture and complete module reference |
| [`test/`](test/) | Unit tests, integration tests, and interpolation validation programs |
| [`data/phase_2/`](data/phase_2/) | Bundled CRM Test 197 run CSVs |
| [`data/naca0012.csv`](data/naca0012.csv) | XFOIL NACA 0012 polar used by the original reader/interpolation example |
| [`fpm.toml`](fpm.toml) | Package configuration and automatic executable/test discovery |
| [`.github/workflows/tests.yml`](.github/workflows/tests.yml) | Build and test automation |

## Data and references

- **CRM measurements:** NASA Common Research Model, National Transonic Facility Test 197. See [experimental results and run logs](https://commonresearchmodel.larc.nasa.gov/experimental-data/) and [Test 197 run data](https://commonresearchmodel.larc.nasa.gov/experimental-data/ntf-experimental-results/test-197-run-data/). The CRM reader currently uses `WCALPHA`, `WCMACH`, `CREYN`, `WCCLC`, `WCCDC`, and `WCCMC`; its interpretation is tied to those specific columns.
- **NACA 0012 example:** an XFOIL-generated polar from [AirfoilTools](http://airfoiltools.com/polar/csv?polar=xf-n0012-il-1000000), with Reynolds number 1 million and Mach 0.5, as recorded in the CSV header. It is a numerical polar, not a wind-tunnel measurement.
- **Atmosphere:** [U.S. Standard Atmosphere, 1976, NASA-TM-X-74335](https://ntrs.nasa.gov/citations/19770009539).

## License

The project code is released under the [MIT License](LICENSE). External datasets retain their original provenance and applicable usage terms; the project license does not replace those terms.
