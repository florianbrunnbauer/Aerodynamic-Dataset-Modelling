program test_dataset_characterisation_integration

    use types, only: aero_dataset_type, dataset_validation_result_type, &
                     run_info_type, run_selection_type, dataset_characterisation_type 

    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use data_io, only: read_crm_dataset
    use dataset_validation, only: validate_dataset
    use dataset_characterisation, only: characterise_dataset, print_characterisation_report

    implicit none

    type(aero_dataset_type) :: dataset
    type(dataset_validation_result_type) :: result_validation
    type(dataset_characterisation_type) :: result_characterisation
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
        print *, "FAILED: Dataset characterisation integration test"
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
        print *, "FAILED: Dataset characterisation integration test"
        print *
        
        error stop 1 
    end if

    ! ------------------------------------------------------------
    ! 4. Validate complete dataset
    ! ------------------------------------------------------------

    call validate_dataset(dataset, result_validation)

    call check(result_validation%is_valid, "Dataset validation failed.", failures)

    ! ------------------------------------------------------------
    ! 5. Characterise complete dataset
    ! ------------------------------------------------------------

    call characterise_dataset(dataset, result_characterisation)

    call check(result_characterisation%n_runs == 12, &
               "Incorrect number of runs in characterisation result.", failures)

    call print_characterisation_report(result_characterisation)

    ! ------------------------------------------------------------
    ! 6. Final result
    ! ------------------------------------------------------------

    if (failures > 0) then

        print *
        print *, failures, " FAILED: dataset characterisation integration test(s)"
        print *

        error stop 1

    end if

    print *
    print *, "PASSED: Dataset characterisation integration test"
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
    
end program test_dataset_characterisation_integration