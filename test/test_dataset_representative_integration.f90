program test_dataset_representative_integration

    use iso_fortran_env, only: real64

    use types, only: aero_dataset_type, dataset_validation_result_type, &
                     run_info_type, run_selection_type, grouped_dataset_type, &
                     representative_dataset_type

    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use data_io, only: read_crm_dataset
    use dataset_validation, only: validate_dataset
    use dataset_grouping, only: group_dataset
    use dataset_representative, only: build_representative_dataset, &
                                      print_representative_report

    implicit none


    type(aero_dataset_type) :: dataset
    type(dataset_validation_result_type) :: validation_result

    type(run_info_type), allocatable :: catalogue(:)
    type(run_info_type), allocatable :: selected_runs(:)

    type(run_selection_type) :: selection
    type(grouped_dataset_type) :: grouped
    type(representative_dataset_type) :: representative


    integer :: failures, stat, i
    integer :: index_reynolds, index_mach, run_index


    real(real64), parameter :: expected_reynolds = 5.0e6_real64

    real(real64), parameter :: expected_mach(8) = [ &
        0.70_real64, 0.75_real64, 0.80_real64, 0.83_real64, &
        0.85_real64, 0.86_real64, 0.87_real64, 0.88_real64]

    integer, parameter :: expected_run(8) = [39, 41, 42, 43, 44, 46, 47, 48]

    failures = 0

    print *
    print *, "=============================================================="
    print *, "TEST: Dataset representative integration"
    print *, "=============================================================="
    print *


    ! ============================================================
    ! 1. Build catalogue from complete CRM dataset
    ! ============================================================

    call build_run_catalogue("data/phase_2", catalogue, stat)

    call check(stat == 0, "Catalogue creation failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset representative integration test"
        print *
        
        error stop 1 
    end if

    call check(size(catalogue) == 97, "Incorrect catalogue size.", failures)

    ! ============================================================
    ! 2. Select aerodynamic configuration
    ! ============================================================

    selection%config = 1
    selection%confts = 1
    selection%conft  = 99

    call select_runs(catalogue, selection, selected_runs)

    call check(size(selected_runs) == 12, "Incorrect number of selected runs.", &
               failures)

    ! ============================================================
    ! 3. Read selected dataset
    ! ============================================================

    call read_crm_dataset(selected_runs, dataset, stat)

    call check(stat == 0, "Dataset reading failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset representative integration test"
        print *
        
        error stop 1 
    end if

    ! ============================================================
    ! 4. Validate dataset
    ! ============================================================

    call validate_dataset(dataset, validation_result)

    call check(validation_result%is_valid, "Dataset validation failed.", &
               failures)

    ! ============================================================
    ! 5. Group dataset
    ! ============================================================

    call group_dataset(dataset, grouped, stat)

    call check(stat == 0, "Dataset grouping failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset representative integration test"
        print *
        
        error stop 1 
    end if

    ! ============================================================
    ! 6. Build representative dataset
    ! ============================================================

    call build_representative_dataset(dataset, grouped, representative, stat)

    call check(stat == 0, "Representative dataset creation failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset representative integration test"
        print *
        
        error stop 1 
    end if

    ! ============================================================
    ! 7. Check representative structure
    ! ============================================================

    call check(size(representative%reynolds_groups) == 1, &
               "Expected one Reynolds group.", failures)

    index_reynolds = findloc(representative%reynolds_groups(:)%nominal_reynolds, &
                             expected_reynolds, dim=1)

    call check(index_reynolds /= 0, "Expected Reynolds group not found.", failures)

    if (index_reynolds /= 0) then

        call check(size(representative%reynolds_groups(index_reynolds)% &
                        mach_groups) == size(expected_mach), &
                   "Incorrect number of representative Mach groups.", failures)

        ! ========================================================
        ! 8. Check selected representative run for every Mach level
        ! ========================================================

        do i = 1, size(expected_mach)

            index_mach = findloc(representative%reynolds_groups(index_reynolds)% &
                                 mach_groups(:)%nominal_mach, expected_mach(i), dim=1)

            call check(index_mach /= 0, &
                       "Expected representative Mach group not found.", failures)

            if (index_mach == 0) cycle

            run_index = representative%reynolds_groups(index_reynolds)% &
                mach_groups(index_mach)%run_index

            call check(run_index >= 1 .and. &
                       run_index <= size(dataset%runs), &
                       "Representative run index is invalid.", failures)

            if (run_index < 1 .or. run_index > size(dataset%runs)) cycle

            call check(dataset%runs(run_index)%info%run == expected_run(i), &
                       "Incorrect representative CRM run.", failures)

        end do

    end if

    ! ============================================================
    ! 9. Print real-data results
    ! ============================================================

    call print_representative_report(dataset, representative)

    ! ============================================================
    ! 10. Final result
    ! ============================================================

    if (failures > 0) then

        print *
        print *, failures, &
            " FAILD: Dataset representative integration test(s)."
        print *

        error stop 1

    end if

    print *
    print *, "PASSED: Dataset representative integration test."
    print *


contains


    subroutine check(condition, message, faliures_to_check)

        logical, intent(in) :: condition

        character(len=*), intent(in) :: message

        integer, intent(inout) :: faliures_to_check

        if (.not. condition) then

            faliures_to_check = faliures_to_check + 1
            print *, "FAILED: ", message

        end if

    end subroutine check


end program test_dataset_representative_integration