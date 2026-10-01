program test_run_selection_dataset

    use types, only: run_info_type, run_selection_type
    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs

    implicit none

    type(run_info_type), allocatable :: catalogue(:)
    type(run_info_type), allocatable :: selected_runs(:)

    type(run_selection_type) :: selection

    integer :: stat, i

    print *
    print *, "========================================"
    print *, "Test: CRM run selection dataset"
    print *, "========================================"
    print *

    call build_run_catalogue("data/phase_2", catalogue, stat)

    if (stat /= 0) then
        error stop "FAILED: catalogue creation"
    end if


    selection%config = 1
    selection%confts = 1
    selection%conft  = 99


    call select_runs(catalogue, selection, selected_runs)


    print *, "Total runs:    ", size(catalogue)
    print *, "Selected runs: ", size(selected_runs)


    do i = 1, size(selected_runs)
        
        if (selected_runs(i)%config /= selection%config) then
            error stop "Selected run has incorrect config."
        end if

        if (selected_runs(i)%confts /= selection%confts) then
            error stop "Selected run has incorrect confts."
        end if

        if (selected_runs(i)%conft /= selection%conft) then
            error stop "Selected run has incorrect conft."
        end if

    end do

    print *
    print *, "PASS: run selection dataset"
    print *

end program test_run_selection_dataset