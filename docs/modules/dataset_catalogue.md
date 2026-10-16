# `dataset_catalogue`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/dataset_catalogue.f90)

Builds the lightweight catalogue used to select a CRM configuration before allocating measurement arrays.

## Pipeline contract

The directory must contain CRM files recognized by `inspect_crm_run`. Discovery is recursive and uses lowercase `*.csv`. One unreadable or incompatible CSV fails the catalogue; unrelated CSV formats are not silently skipped. No filtering or data validation happens here.

## Public interface

### `build_run_catalogue`

```fortran
call build_run_catalogue(directory, catalogue, stat)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `directory` | `character(len=*)` | in | no | Directory to search recursively for CRM CSV files. |
| `catalogue(:)` | `type(run_info_type)` | out | no | Run metadata entries, without the full measurement arrays. |
| `stat` | `integer` | out | no | Procedure-specific integer status; inspect the tables on this page. |

## Behavior and implementation

The module runs Unix `find` through `execute_command_line`, writes paths to `/tmp/aero_dataset_catalogue_<clock>.txt`, counts nonempty paths, allocates the catalogue and inspects each file. The temporary list is deleted on successful completion and most subsequent read/inspection failures.

The catalogue preserves file-discovery order, which is not guaranteed to be sorted or stable. A metadata `run` ID is not an array position. The implementation assumes a Unix shell, `/tmp`, ordinary newline-free paths and a writable temporary directory. Fixed buffers are 4,096 characters for paths and 8,192 for the command. Directory text is embedded in a shell command; ordinary local paths are intended, not arbitrary shell-expression input. Clock-derived temporary names are not a concurrency-safe uniqueness mechanism. Some early failure paths can leave the temporary list behind.

## Errors and status handling

| Value | Constant / context | Meaning |
|---|---|---|
| 0 | stat | Success |
| 1 | stat | Command could not be executed |
| 2 | stat | find returned a nonzero exit status |
| 3 | stat | Cannot open temporary list |
| 4 | stat | First list read failed |
| 5 | stat | No CSV files found |
| 6 | stat | Second list read failed |
| 7 | stat | At least one CRM inspection failed |

Do not assume the catalogue is allocated on failure. Status 5 explicitly returns `catalogue(0)`; other paths differ. Detailed inspection status is printed when status 7 occurs.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program catalogue_example
  use types, only: run_info_type
  use dataset_catalogue, only: build_run_catalogue
  implicit none
  type(run_info_type), allocatable :: catalogue(:)
  integer :: stat
  call build_run_catalogue('data/phase_2', catalogue, stat)
  if (stat /= 0) error stop 'catalogue failed'
  print *, 'Runs discovered:', size(catalogue)
end program catalogue_example
```

## Dependencies and tests

Project dependencies: [types](types.md), [data_io](data_io.md).

Relevant test/validation sources:

- [`test_dataset_catalogue.f90`](../../test/test_dataset_catalogue.f90)
- [`test_crm_dataset_integration.f90`](../../test/test_crm_dataset_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
