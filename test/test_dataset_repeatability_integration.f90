program test_dataset_repeatability_integration

    use iso_fortran_env, only: real64
    use ieee_arithmetic, only: ieee_is_finite

    use types, only: aero_dataset_type, dataset_validation_result_type, &
                     run_info_type, run_selection_type, grouped_dataset_type, &
                     dataset_repeatability_type

    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use data_io, only: read_crm_dataset
    use dataset_validation, only: validate_dataset
    use dataset_grouping, only: group_dataset
    use dataset_repeatability, only: analyse_repeatability, print_repeatability_report

    implicit none


    type(aero_dataset_type) :: dataset
    type(dataset_validation_result_type) :: validation_result

    type(run_info_type), allocatable :: catalogue(:)
    type(run_info_type), allocatable :: selected_runs(:)

    type(run_selection_type) :: selection
    type(grouped_dataset_type) :: grouped
    type(dataset_repeatability_type) :: repeatability


    integer :: failures, stat

    integer :: index_mach_070, index_mach_085

    real(real64), parameter :: tolerance_alpha = 0.01_real64

    failures = 0


    print *
    print *, "=============================================================="
    print *, "TEST: Dataset repeatability integration"
    print *, "=============================================================="
    print *


    ! ============================================================
    ! 1. Build catalogue from complete CRM dataset
    ! ============================================================

    call build_run_catalogue("data/phase_2", catalogue, stat)

    call check(stat == 0, "Catalogue creation failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset repeatability integration test"
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
        print *, "FAILED: Dataset repeatability integration test"
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
        print *, "FAILED: Dataset repeatability integration test"
        print *
        
        error stop 1 
    end if

    ! ============================================================
    ! 6. Analyse repeatability
    ! ============================================================

    call analyse_repeatability(dataset, grouped, repeatability, stat)

    call check(stat == 0, "Repeatability analysis failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset repeatability integration test"
        print *
        
        error stop 1 
    end if

    ! ============================================================
    ! 7. Check repeated group detection
    ! ============================================================

    ! From the previous grouping analysis we know that this
    ! configuration contains two repeated Mach conditions:
    !
    ! Mach = 0.70 -> runs 39, 50, 52
    ! Mach = 0.85 -> runs 44, 51, 53

    call check(repeatability%n_groups == 2, "Expected two repeated Mach groups.", &
               failures)

    if (repeatability%n_groups /= 2) then

        print *
        print *, "Cannot continue detailed repeatability checks."
        print *, "Expected 2 groups, found ", repeatability%n_groups

        error stop 1

    end if

    index_mach_070 = findloc(repeatability%groups(:)%nominal_mach, 0.70_real64, dim=1)

    index_mach_085 = findloc(repeatability%groups(:)%nominal_mach, 0.85_real64, dim=1)

    call check(index_mach_070 /= 0, "Mach = 0.70 repeatability group not found.", &
               failures)

    call check(index_mach_085 /= 0, "Mach = 0.85 repeatability group not found.", &
               failures)

    ! ============================================================
    ! 8. Check Mach = 0.70 group
    ! ============================================================

    if (index_mach_070 /= 0) then

        call check(repeatability%groups(index_mach_070)%n_runs == 3, &
                   "Mach = 0.70 should contain three repeated runs.", failures)

        call check(abs(repeatability%groups(index_mach_070)%nominal_reynolds - &
                   5.0e6_real64) < 1.0_real64, &
                   "Incorrect Reynolds group for Mach = 0.70.", failures)

        ! From runs 39, 50 and 52:
        !
        ! Run 39: -2.890 ... 12.210
        ! Run 50:  2.235 ...  5.220
        ! Run 52:  2.172 ...  5.220
        !
        ! Common range should therefore be approximately
        ! 2.235 ... 5.220 deg.

        call check(abs(repeatability%groups(index_mach_070)%alpha_min - &
                   2.235_real64) < tolerance_alpha, &
                   "Incorrect common alpha minimum for Mach = 0.70.", failures)

        call check(abs(repeatability%groups(index_mach_070)%alpha_max - &
                   5.220_real64) < tolerance_alpha, &
                   "Incorrect common alpha maximum for Mach = 0.70.", failures)


        call check_group_results(repeatability%groups(index_mach_070), &
                                 "Mach = 0.70", failures)

    end if

    ! ============================================================
    ! 9. Check Mach = 0.85 group
    ! ============================================================

    if (index_mach_085 /= 0) then

        call check(repeatability%groups(index_mach_085)%n_runs == 3, &
                   "Mach = 0.85 should contain three repeated runs.", failures)

        call check(abs(repeatability%groups(index_mach_085)%nominal_reynolds - &
                   5.0e6_real64) < 1.0_real64, &
                   "Incorrect Reynolds group for Mach = 0.85.", failures)

        ! From runs 44, 51 and 53:
        !
        ! Run 44: -2.824 ... 10.234
        ! Run 51:  2.266 ...  5.155
        ! Run 53:  2.225 ...  5.176
        !
        ! Common range should therefore be approximately
        ! 2.266 ... 5.155 deg.

        call check(abs(repeatability%groups(index_mach_085)%alpha_min - &
                   2.266_real64) < tolerance_alpha, &
                   "Incorrect common alpha minimum for Mach = 0.85.", failures)

        call check(abs(repeatability%groups(index_mach_085)%alpha_max - &
                   5.155_real64) < tolerance_alpha, &
                   "Incorrect common alpha maximum for Mach = 0.85.", failures)

        call check_group_results(repeatability%groups(index_mach_085), &
                                 "Mach = 0.85", failures)

    end if

    ! ============================================================
    ! 10. Print real-data results
    ! ============================================================

    call print_repeatability_report(repeatability)

    ! ============================================================
    ! 11. Final result
    ! ============================================================

    if (failures > 0) then

        print *
        print *, failures, " FAILED: Dataset repeatability integration test(s)"
        print *

        error stop 1

    end if

    print *
    print *, "PASSED: Dataset repeatability integration test"
    print *


contains


    subroutine check_group_results(group, group_name, faliures_in_group)

        use types, only: repeatability_group_type

        type(repeatability_group_type), intent(in) :: group

        character(len=*), intent(in) :: group_name

        integer, intent(inout) :: faliures_in_group

        ! --------------------------------------------------------
        ! Common evaluation grid
        ! --------------------------------------------------------

        call check(group%n_points >= 2, group_name // &
                   ": insufficient common evaluation points.", faliures_in_group)

        call check(size(group%alpha) == group%n_points, group_name // &
                   ": alpha array has incorrect size.", faliures_in_group )

        call check(all(ieee_is_finite(group%alpha)), group_name // &
                   ": alpha contains non-finite values.", faliures_in_group)

        if (group%n_points > 1) then

            call check(all(group%alpha(2:) > group%alpha(:group%n_points - 1)), &
                       group_name // &
                       ": alpha evaluation grid is not strictly increasing.", &
                       faliures_in_group)

        end if

        ! --------------------------------------------------------
        ! Array sizes
        ! --------------------------------------------------------

        call check(size(group%cl_mean) == group%n_points .and. &
                   size(group%cl_std) == group%n_points .and. &
                   size(group%cl_spread) == group%n_points, group_name // &
                   ": Cl result arrays have incorrect sizes.", faliures_in_group)

        call check(size(group%cd_mean) == group%n_points .and. &
                   size(group%cd_std) == group%n_points .and. &
                   size(group%cd_spread) == group%n_points, group_name // &
                   ": Cd result arrays have incorrect sizes.", faliures_in_group)

        call check(size(group%cm_mean) == group%n_points .and. &
                   size(group%cm_std) == group%n_points .and. &
                   size(group%cm_spread) == group%n_points, group_name // &
                   ": Cm result arrays have incorrect sizes.", faliures_in_group)

        ! --------------------------------------------------------
        ! Finite results
        ! --------------------------------------------------------

        call check(all(ieee_is_finite(group%cl_mean)) .and. &
                   all(ieee_is_finite(group%cl_std)) .and. &
                   all(ieee_is_finite(group%cl_spread)), group_name // &
                   ": Cl statistics contain non-finite values.", faliures_in_group)

        call check(all(ieee_is_finite(group%cd_mean)) .and. &
                   all(ieee_is_finite(group%cd_std)) .and. &
                   all(ieee_is_finite(group%cd_spread)), group_name // &
                   ": Cd statistics contain non-finite values.", faliures_in_group)

        call check(all(ieee_is_finite(group%cm_mean)) .and. &
                   all(ieee_is_finite(group%cm_std)) .and. &
                   all(ieee_is_finite(group%cm_spread)), group_name // &
                   ": Cm statistics contain non-finite values.", faliures_in_group)

        ! --------------------------------------------------------
        ! Statistical quantities must be non-negative
        ! --------------------------------------------------------

        call check(all(group%cl_std >= 0.0_real64) .and. &
                   all(group%cl_spread >= 0.0_real64), group_name // &
                   ": invalid negative Cl repeatability statistic.", faliures_in_group)

        call check(all(group%cd_std >= 0.0_real64) .and. &
                   all(group%cd_spread >= 0.0_real64), group_name // &
                   ": invalid negative Cd repeatability statistic.", faliures_in_group)

        call check(all(group%cm_std >= 0.0_real64) .and. &
                   all(group%cm_spread >= 0.0_real64), group_name // &
                   ": invalid negative Cm repeatability statistic.", faliures_in_group)

    end subroutine check_group_results


    subroutine check(condition, message, faliures_to_check)

        logical, intent(in) :: condition

        character(len=*), intent(in) :: message

        integer, intent(inout) :: faliures_to_check

        if (.not. condition) then

            faliures_to_check = faliures_to_check + 1
            print *, "FAILED: ", message

        end if


    end subroutine check


end program test_dataset_repeatability_integration