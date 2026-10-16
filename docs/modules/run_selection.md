# `run_selection`

[Module index](README.md) · [Architecture](../architecture.md) · [Repository home](../../README.md) · [Source](../../src/run_selection.f90)

Filters catalogue entries by the three configuration fields selected in the CLI.

## Pipeline contract

Catalogue entries must already have valid metadata. Assign every member of `run_selection_type` before use: it has no initialized wildcard/default values. This module does not load measurement arrays or validate data.

## Public interface

### `run_matches`

```fortran
matches = run_matches(info, selection)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `info` | `type(run_info_type)` | in | no | Metadata for one run, including its file path. |
| `selection` | `type(run_selection_type)` | in | no | Exact CONFIG, CONFTS and CONFT filters. |

Returns a logical value; this function is pure.

### `select_runs`

```fortran
call select_runs(catalogue, selection, selected_runs)
```

| Argument | Type | Intent | Optional | Meaning / units |
|---|---|---|---|---|
| `catalogue(:)` | `type(run_info_type)` | in | no | Run metadata entries, without the full measurement arrays. |
| `selection` | `type(run_selection_type)` | in | no | Exact CONFIG, CONFTS and CONFT filters. |
| `selected_runs(:)` | `type(run_info_type)` | out | no | Metadata entries for the files selected for loading. |

## Behavior and implementation

`run_matches` returns true only when CONFIG, CONFTS and CONFT all match exactly. There is no wildcard mode, range matching, Reynolds filter, Mach filter, test-ID filter or series filter.

`select_runs` counts matches, allocates exactly that many entries, then copies them in original catalogue order. A zero-match result is an allocated array of length zero. Repeated runs and distinct tests with matching configuration fields remain present. If one experiment/test identity is required, enforce that as part of the input-directory or preparation policy; this selector does not establish it.

## Errors and status handling

Neither procedure returns an integer status. Test `size(selected_runs) > 0` before treating the selection as a usable dataset.

## Usage example

Run this example from the repository root after linking the project modules.

```fortran
program selection_example
  use types, only: run_info_type, run_selection_type
  use run_selection, only: select_runs, run_matches
  implicit none
  type(run_info_type) :: catalogue(2)
  type(run_info_type), allocatable :: selected(:)
  type(run_selection_type) :: selection
  catalogue(1) = run_info_type(197,39,1,1,1,99,'data/phase_2/t197R39.csv')
  catalogue(2) = run_info_type(197,69,1,2,0,0,'example-other.csv')
  selection%config = 1
  selection%confts = 1
  selection%conft = 99
  call select_runs(catalogue, selection, selected)
  print *, size(selected), run_matches(catalogue(1), selection)
end program selection_example
```

## Dependencies and tests

Project dependencies: [types](types.md).

Relevant test/validation sources:

- [`test_run_matching.f90`](../../test/test_run_matching.f90)
- [`test_run_selection_dataset.f90`](../../test/test_run_selection_dataset.f90)
- [`test_crm_dataset_integration.f90`](../../test/test_crm_dataset_integration.f90)

These links point to the existing test implementations; this page does not claim that every edge case or aerodynamic operating condition is validated.
