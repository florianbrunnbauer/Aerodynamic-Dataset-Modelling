# `data_io`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/data_io.f90)

Reads the XFOIL example and CRM CSV measurements. CRM inspection and reading are separate so configuration selection can happen before full loading.

## Pipeline contract

CRM calls return integer statuses. Check them before accessing output arrays, and run `validate_dataset` after loading: parsing is not validation of alpha order, finiteness, configuration consistency or aerodynamic suitability. Input files must remain unchanged during the two reading passes.

`read_airfoil_data` is a separate, header-dependent reader returning `aerodynamic_dataset_type`; it is not used by the CRM command-line pipeline.

## Public interface

### `read_airfoil_data`

```fortran
call read_airfoil_data(filename, dataset)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `filename` | `character(len=*)` | in | no | Input file path; relative paths are resolved against the working directory. |
| `dataset` | `type(aerodynamic_dataset_type)` | out | no | Output container with one XFOIL-style polar in polars(1). |

### `inspect_crm_run`

```fortran
call inspect_crm_run(filename, info, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `filename` | `character(len=*)` | in | no | Input file path; relative paths are resolved against the working directory. |
| `info` | `type(run_info_type)` | out | no | Metadata for one run, including its file path. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `read_crm_run`

```fortran
call read_crm_run(info, run, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `info` | `type(run_info_type)` | in | no | Metadata for one run, including its file path. |
| `run` | `type(aero_run_type)` | out | no | One CRM run with aligned measurement arrays. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

### `read_crm_dataset`

```fortran
call read_crm_dataset(selected_runs, dataset, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `selected_runs(:)` | `type(run_info_type)` | in | no | Metadata entries for the files selected for loading. |
| `dataset` | `type(aero_dataset_type)` | out | no | Measurement storage; see the procedure-specific contract below. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

## Behavior and implementation

### XFOIL-style polar

`read_airfoil_data` reads seven numeric fields in order: `Alpha, Cl, Cd, Cdp, Cm, Top_Xtr, Bot_Xtr`. Only alpha, Cl, Cd and Cm are retained. Header records named `Reynolds number` and `Mach` provide scalar conditions; one polar is returned in `dataset%polars(1)`. The reader counts rows, rewinds, allocates arrays, then stores values. It uses a 512-character line buffer.

Use the header-bearing `data/naca0012.csv`. The included headerless file is not a standalone supported input for this routine because it lacks the required condition metadata. Metadata-present flags are initialized in their declarations (Fortran implicit SAVE); repeated calls should not be relied on to detect missing metadata reliably. This routine does not provide the CRM validation contract.

### CRM metadata and measurements

`inspect_crm_run` reads the header and first numeric measurement row. It finds `TEST`, `RUN`, `SERIES`, `CONFIG`, `CONFTS`, and `CONFT`, converts their values with `nint`, and records the file path. Metadata consistency across later rows is not checked.

`read_crm_run` copies `info` and reads all rows twice using a 20,000-character line buffer. Required column names are case-sensitive:

| CSV column | Stored field | Conversion / units |
|---|---|---|
| WCALPHA | alpha(:) | degrees, unchanged |
| WCMACH | mach(:) | dimensionless, unchanged |
| CREYN | reynolds(:) | multiply by 1e6; CSV values are in millions |
| WCCLC | cl(:) | dimensionless |
| WCCDC | cd(:) | dimensionless |
| WCCMC | cm(:) | dimensionless |

Column order can vary; extra columns are parsed into a temporary numeric row but not retained. The helpers split simple comma-delimited header names and use list-directed numeric reads; this is not a general quoted-field CSV parser. Blank or malformed CRM data rows cause failure.

`read_crm_dataset` allocates one run per selected metadata entry and preserves the selection order. A zero-length selection produces an allocated empty dataset with status zero; dataset validation rejects that empty dataset. On a run failure, loading stops and the output may be only partially populated. Discard it or retry the pipeline; do not use it as a successful dataset.

## Errors and status handling

`read_airfoil_data` terminates with `error stop` on its detected opening, reading, header, condition or data-format failures; it has no recoverable `stat` argument.

CRM statuses are local to each procedure:

| Value | inspect_crm_run | read_crm_run |
|---|---|---|
| 0 | Success | Success |
| 1 | Cannot open file | Cannot open file |
| 2 | Cannot read header | Cannot read header |
| 3 | Missing metadata column | Missing aerodynamic column |
| 4 | Cannot read first measurement row | First-pass file read failed |
| 5 | Cannot parse first row | First-pass numeric parse failed |
| 6 | — | No numeric rows |
| 7 | — | Cannot reread header |
| 8 | — | Second-pass file read failed |
| 9 | — | Second-pass numeric parse failed |

`read_crm_dataset`: 0 means all requested reads succeeded; 1 means a run failed. It prints the failed run ID but does not return that run's detailed reader status separately. Output arrays and metadata are usable only after a successful call.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program read_crm_example
  use types, only: run_info_type, aero_dataset_type
  use data_io, only: inspect_crm_run, read_crm_dataset
  implicit none
  type(run_info_type) :: info
  type(aero_dataset_type) :: data
  integer :: stat
  call inspect_crm_run('data/phase_2/t197R39.csv', info, stat)
  if (stat /= 0) error stop 'inspection failed'
  call read_crm_dataset([info], data, stat)
  if (stat /= 0) error stop 'reading failed'
  print *, data%runs(1)%info%run, size(data%runs(1)%alpha)
  ! Next call validate_dataset before grouping or coefficient queries.
end program read_crm_example
```

## Dependencies and tests

Project dependencies: [types](types.md).

Relevant test/validation sources:

- [`test_data_io.f90`](../../test/test_data_io.f90)
- [`test_crm_run_inspection.f90`](../../test/test_crm_run_inspection.f90)
- [`test_read_crm_run.f90`](../../test/test_read_crm_run.f90)
- [`test_crm_dataset_reader.f90`](../../test/test_crm_dataset_reader.f90)
- [`test_crm_dataset_integration.f90`](../../test/test_crm_dataset_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
