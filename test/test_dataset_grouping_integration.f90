program test_dataset_grouping_integration
    
    use iso_fortran_env, only: real64
    use types, only: aero_dataset_type, dataset_validation_result_type, &
                     run_info_type, run_selection_type, grouped_dataset_type 

    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use data_io, only: read_crm_dataset
    use dataset_validation, only: validate_dataset
    use dataset_grouping, only: group_dataset, print_grouping_report

    implicit none

    type(aero_dataset_type) :: dataset
    type(dataset_validation_result_type) :: result_validation
    type(run_info_type), allocatable :: catalogue(:)
    type(run_selection_type) :: selection
    type(run_info_type), allocatable :: selected_runs(:)
    type(grouped_dataset_type) :: grouped

    integer :: failures, stat, i, j, index_reynolds, index_mach

    real(real64), parameter :: nominal_reynolds_expected(1) = [5.0e6_real64]

    real(real64), parameter ::nominal_mach_expected(8) = [0.70_real64, 0.75_real64, &
                                                          0.80_real64, 0.83_real64, &
                                                          0.85_real64, 0.86_real64, &
                                                          0.87_real64, 0.88_real64]

    integer, parameter :: nr_runs_in_mach_group_expected(8) = [3, 1, 1, 1, 3, 1, 1, 1]

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
        print *, "FAILED: Dataset grouping integration test"
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
        print *, "FAILED: Dataset grouping integration test"
        print *
        
        error stop 1 
    end if

    ! ------------------------------------------------------------
    ! 4. Validate complete dataset
    ! ------------------------------------------------------------

    call validate_dataset(dataset, result_validation)

    call check(result_validation%is_valid, "Dataset validation failed.", failures)

    ! ------------------------------------------------------------
    ! 5. Group complete dataset
    ! ------------------------------------------------------------

    call group_dataset(dataset, grouped, stat)

    if (stat /= 0) then
    print *, "Dataset grouping failed. Status: ", stat
    error stop 1
    end if

    call check(size(grouped%reynolds_groups) == size(nominal_reynolds_expected), &
               "Incorrect number of Reynolds groups.", failures)
    
    do i = 1, size(nominal_reynolds_expected)

        index_reynolds = findloc(grouped%reynolds_groups(:)%nominal_reynolds, &
                         nominal_reynolds_expected(i), dim=1)

        call check(index_reynolds /= 0, &
               "Expected Reynolds group not found.", failures)

        if (index_reynolds == 0) cycle

        call check(size(grouped%reynolds_groups(index_reynolds)%mach_groups) == &
                   size(nominal_mach_expected), &
                   "Incorrect number of Mach groups.", failures)
        
        do j = 1, size(nominal_mach_expected)

            index_mach = findloc(grouped%reynolds_groups(index_reynolds)% &
                                 mach_groups(:)%nominal_mach, &
                                 nominal_mach_expected(j), dim=1)
            
            call check(index_mach /= 0, &
                   "Expected Mach group not found.", failures)

            if (index_mach == 0) cycle


            call check(size(grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach)%run_indices) == &
                       nr_runs_in_mach_group_expected(j), &
                       "Incorrect number of runs in Mach group.", failures)
        
        end do

    end do
    
    if (failures > 0) then

        print *
        print *, failures, " FAILED: Dataset grouping integration test(s)"
        print *

        error stop 1

    end if


    print *
    print *, "PASSED: Dataset grouping integration tests"
    print *

    call print_grouping_report(dataset, grouped)

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
    
end program test_dataset_grouping_integration