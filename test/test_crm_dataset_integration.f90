program test_crm_dataset_integration

    use types, only: run_info_type, run_selection_type, aero_dataset_type
    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use data_io, only: read_crm_dataset

    implicit none

    type(run_info_type), allocatable :: catalogue(:)
    type(run_info_type), allocatable :: selected_runs(:)

    type(run_selection_type) :: selection
    type(aero_dataset_type) :: dataset

    integer :: stat, i, n_points

    print *
    print *, "========================================"
    print *, "Test: CRM dataset integration"
    print *, "========================================"
    print *

    ! ------------------------------------------------------------
    ! 1. Build catalogue from complete CRM dataset
    ! ------------------------------------------------------------

    call build_run_catalogue("data/phase_2", catalogue, stat)

    if (stat /= 0) then
        error stop "FAILED: catalogue creation"
    end if

    if (size(catalogue) /= 97) then
        error stop "FAILED: incorrect catalogue size"
    end if


    ! ------------------------------------------------------------
    ! 2. Select one aerodynamic configuration
    ! ------------------------------------------------------------

    selection%config = 1
    selection%confts = 1
    selection%conft  = 99


    call select_runs(catalogue, selection, selected_runs)


    if (size(selected_runs) /= 12) then
        error stop "FAILED: incorrect number of runs selected"
    end if


    ! ------------------------------------------------------------
    ! 3. Read complete selected dataset
    ! ------------------------------------------------------------

    call read_crm_dataset(selected_runs, dataset, stat)


    if (stat /= 0) then
        error stop "FAILED: CRM dataset loading"
    end if


    ! ------------------------------------------------------------
    ! 4. Number of loaded runs must equal selected runs
    ! ------------------------------------------------------------

    if (size(dataset%runs) /= size(selected_runs)) then
        error stop "FAILED: incorrect number of loaded runs"
    end if


    ! ------------------------------------------------------------
    ! 5. Validate every loaded run
    ! ------------------------------------------------------------

    do i = 1, size(dataset%runs)

        ! Metadata must correspond to selected run.
        if (dataset%runs(i)%info%run /= selected_runs(i)%run) then
            error stop "FAILED: RUN metadata mismatch"
        end if

        if (dataset%runs(i)%info%test /= selected_runs(i)%test) then
            error stop "FAILED: TEST metadata mismatch"
        end if

        if (dataset%runs(i)%info%series /= selected_runs(i)%series) then
            error stop "FAILED: SERIES metadata mismatch"
        end if


        ! Configuration must satisfy selection.
        if (dataset%runs(i)%info%config /= selection%config) then
            error stop "FAILED: CONFIG mismatch"
        end if

        if (dataset%runs(i)%info%confts /= selection%confts) then
            error stop "FAILED: CONFTS mismatch"
        end if

        if (dataset%runs(i)%info%conft /= selection%conft) then
            error stop "FAILED: CONFT mismatch"
        end if


        ! Run must contain measurement points.
        n_points = size(dataset%runs(i)%alpha)

        if (n_points == 0) then
            error stop "FAILED: empty aerodynamic run"
        end if


        ! All aerodynamic arrays must contain the same number
        ! of measurement points.
        if (size(dataset%runs(i)%mach) /= n_points) then
            error stop "FAILED: MACH array size"
        end if

        if (size(dataset%runs(i)%reynolds) /= n_points) then
            error stop "FAILED: Reynolds array size"
        end if

        if (size(dataset%runs(i)%cl) /= n_points) then
            error stop "FAILED: CL array size"
        end if

        if (size(dataset%runs(i)%cd) /= n_points) then
            error stop "FAILED: CD array size"
        end if

        if (size(dataset%runs(i)%cm) /= n_points) then
            error stop "FAILED: CM array size"
        end if

    end do


    print *, "Total catalogue entries: ", size(catalogue)
    print *, "Selected runs:           ", size(selected_runs)
    print *, "Loaded runs:             ", size(dataset%runs)

    print *
    print *, "PASSED: CRM dataset integration"
    print *


end program test_crm_dataset_integration