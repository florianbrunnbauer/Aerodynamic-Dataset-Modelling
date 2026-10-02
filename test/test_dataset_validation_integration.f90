program test_dataset_validation_integration

    use types, only: aero_dataset_type, dataset_validation_result_type, &
                     run_info_type, run_selection_type

    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use data_io, only: read_crm_dataset
    use dataset_validation, only: validate_dataset

    implicit none

    type(aero_dataset_type) :: dataset
    type(dataset_validation_result_type) :: result
    type(run_info_type), allocatable :: catalogue(:)
    type(run_selection_type) :: selection
    type(run_info_type), allocatable :: selected_runs(:)

    integer :: failures, stat

    failures = 0

    print *
    print *, "========================================"
    print *, "TEST: Dataset validation integration"
    print *, "========================================"
    print *

    ! ------------------------------------------------------------
    ! 1. Build catalogue from complete CRM dataset
    ! ------------------------------------------------------------

    call build_run_catalogue("data/phase_2", catalogue, stat)

    call check(stat == 0, "Catalogue creation failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset validation integration test"
        print *
        
        error stop 1 
    end if

    call check(size(catalogue) == 97, "Incorrect catalogue size.", failures)

    ! ------------------------------------------------------------
    ! 2. Select one aerodynamic configuration
    ! ------------------------------------------------------------

    selection%config = 1
    selection%confts = 1
    selection%conft  = 99

    call select_runs(catalogue, selection, selected_runs)

    call check(size(selected_runs) == 12, "Incorrect number of runs selected.", failures)

    ! ------------------------------------------------------------
    ! 3. Read complete selected dataset
    ! ------------------------------------------------------------

    call read_crm_dataset(selected_runs, dataset, stat)

    call check(stat == 0, "Dataset reading failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset validation integration test"
        print *
        
        error stop 1 
    end if

    ! ------------------------------------------------------------
    ! 4. Validate complete dataset
    ! ------------------------------------------------------------

    call validate_dataset(dataset, result)

    call check(result%is_valid, "Dataset validation failed.", failures)

    call check(result%n_runs == 12, &
               "Incorrect number of runs in validation result.", failures)

    call check(result%n_valid_runs == 12, &
               "Incorrect number of valid runs in validation result.", failures)

    call check(result%n_invalid_runs == 0, &
               "Incorrect number of invalid runs in validation result.", failures)

    if (failures > 0) then
        print *
        print *, failures, " FAILED: Dataset validation integration test(s)"
        print *
        error stop 1
    end if

    print *
    print *, "PASSED: Dataset validation integration test"
    print *

contains

    subroutine check(condition, message, fails)

        logical, intent(in) :: condition
        character(len=*), intent(in) :: message
        integer, intent(inout) :: fails

        if (.not. condition) then

            fails = fails + 1
            print *, "FAILED: ", message

        end if

    end subroutine check

end program test_dataset_validation_integration