program test_dataset_repeatability

    use iso_fortran_env, only: real64

    use types, only: aero_run_type, aero_dataset_type, &
                     grouped_dataset_type, dataset_repeatability_type

    use dataset_repeatability, only: analyse_repeatability

    implicit none


    type(aero_dataset_type) :: dataset
    type(grouped_dataset_type) :: grouped
    type(dataset_repeatability_type) :: result

    integer :: failures
    integer :: stat

    real(real64), parameter :: tolerance = 1.0e-10_real64

    real(real64), parameter :: expected_alpha(5) = [0.5_real64, 1.5_real64, &
                                                    2.5_real64, 3.5_real64, &
                                                    4.5_real64]

    real(real64) :: expected_cl_mean(5)
    real(real64) :: expected_cd_mean(5)
    real(real64) :: expected_cm_mean(5)

    failures = 0


    print *
    print *, "=============================================================="
    print *, "TEST: dataset repeatability"
    print *, "=============================================================="
    print *


    ! ============================================================
    ! 1. Build synthetic dataset
    ! ============================================================

    allocate(dataset%runs(4))

    ! ------------------------------------------------------------
    ! Run 101
    !
    ! Re = 5.0e6
    ! Mach = 0.70
    !
    ! Long AoA range, but only four points inside the final
    ! common interval.
    ! ------------------------------------------------------------

    call make_run(dataset%runs(1), 101, [-1.0_real64, 0.0_real64, 1.0_real64, &
                  2.0_real64, 3.0_real64, 4.0_real64, 5.0_real64], &
                  0.0_real64, 0.0_real64, 0.0_real64, 0.70_real64, 5.0e6_real64)

    ! ------------------------------------------------------------
    ! Run 102
    !
    ! Same nominal condition, but different AoA grid.
    ! ------------------------------------------------------------

    call make_run(dataset%runs(2), 102, [0.0_real64, 1.5_real64, 3.0_real64, &
                  4.5_real64], 0.1_real64, 0.002_real64, 0.01_real64, &
                  0.70_real64, 5.0e6_real64)

    ! ------------------------------------------------------------
    ! Run 103
    !
    ! Same nominal condition.
    !
    ! This run has the greatest number of points inside the common
    ! AoA range and should therefore become the reference grid.
    ! ------------------------------------------------------------

    call make_run(dataset%runs(3), 103, [0.5_real64, 1.5_real64, 2.5_real64, &
                  3.5_real64, 4.5_real64], -0.1_real64, -0.002_real64, &
                  -0.01_real64, 0.70_real64, 5.0e6_real64)

    ! ------------------------------------------------------------
    ! Run 104
    !
    ! Different Mach group containing only one run.
    ! Repeatability analysis should ignore this group.
    ! ------------------------------------------------------------

    call make_run(dataset%runs(4), 104, [0.0_real64, 1.0_real64, 2.0_real64], &
                  0.0_real64, 0.0_real64, 0.0_real64, 0.75_real64, 5.0e6_real64)

    ! ============================================================
    ! 2. Build synthetic grouping
    ! ============================================================

    allocate(grouped%reynolds_groups(1))

    grouped%reynolds_groups(1)%nominal_reynolds = 5.0e6_real64

    allocate(grouped%reynolds_groups(1)%mach_groups(2))

    ! Re = 5e6, Mach = 0.70
    grouped%reynolds_groups(1)%mach_groups(1)%nominal_mach = 0.70_real64

    grouped%reynolds_groups(1)%mach_groups(1)%run_indices = [1, 2, 3]

    ! Re = 5e6, Mach = 0.75
    grouped%reynolds_groups(1)%mach_groups(2)%nominal_mach = 0.75_real64

    grouped%reynolds_groups(1)%mach_groups(2)%run_indices = [4]

    ! ============================================================
    ! 3. Run repeatability analysis
    ! ============================================================

    call analyse_repeatability(dataset, grouped, result, stat)

    call check(stat == 0, "Repeatability analysis should succeed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset repeatability test"
        print *
        
        error stop 1 
    end if

    ! ============================================================
    ! 4. Check group detection
    ! ============================================================

    call check(result%n_groups == 1, &
               "Only the repeated Mach group should be analysed.", failures)

    call check(result%groups(1)%n_runs == 3, &
               "Repeated group should contain three runs.", failures)

    call check(abs(result%groups(1)%nominal_reynolds - 5.0e6_real64) < tolerance, &
               "Incorrect nominal Reynolds number.", failures)

    call check(abs(result%groups(1)%nominal_mach - 0.70_real64) < tolerance, &
               "Incorrect nominal Mach number.", failures)

    ! ============================================================
    ! 5. Check common AoA interval
    ! ============================================================

    call check(abs(result%groups(1)%alpha_min - 0.5_real64) < tolerance, &
               "Incorrect common alpha minimum.", failures)


    call check(abs(result%groups(1)%alpha_max - 4.5_real64) < tolerance, &
        "Incorrect common alpha maximum.", failures)


    call check(result%groups(1)%n_points == 5, &
        "Expected five common evaluation points.", failures)

    ! Run 103 should provide the reference grid because it contains
    ! the most points inside the common AoA interval.

    call check(all(abs(result%groups(1)%alpha - expected_alpha) < tolerance), &
               "Incorrect reference alpha grid.", failures)

    ! ============================================================
    ! 6. Expected coefficient means
    ! ============================================================

    expected_cl_mean = 2.0_real64 * expected_alpha + 1.0_real64

    expected_cd_mean = 0.02_real64 + 0.005_real64 * expected_alpha

    expected_cm_mean = -0.05_real64 - 0.01_real64 * expected_alpha

    ! ============================================================
    ! 7. Check Cl statistics
    ! ============================================================

    call check(all(abs(result%groups(1)%cl_mean - expected_cl_mean) < tolerance), &
               "Incorrect Cl mean.", failures)

    call check(all(abs(result%groups(1)%cl_std - 0.1_real64) < tolerance), &
               "Incorrect Cl standard deviation.", failures)

    call check(all(abs(result%groups(1)%cl_spread - 0.2_real64) < tolerance), &
               "Incorrect Cl spread.", failures)

    ! ============================================================
    ! 8. Check Cd statistics
    ! ============================================================

    call check(all(abs(result%groups(1)%cd_mean - expected_cd_mean) < tolerance), &
               "Incorrect Cd mean.", failures)

    call check(all(abs(result%groups(1)%cd_std - 0.002_real64) < tolerance), &
               "Incorrect Cd standard deviation.", failures)

    call check(all(abs(result%groups(1)%cd_spread - 0.004_real64) < tolerance), &
               "Incorrect Cd spread.", failures)

    ! ============================================================
    ! 9. Check Cm statistics
    ! ============================================================

    call check(all(abs(result%groups(1)%cm_mean - expected_cm_mean) < tolerance), &
               "Incorrect Cm mean.", failures)

    call check(all(abs(result%groups(1)%cm_std - 0.01_real64) < tolerance), &
               "Incorrect Cm standard deviation.", failures)

    call check(all(abs(result%groups(1)%cm_spread - 0.02_real64) < tolerance), &
               "Incorrect Cm spread.", failures)

    ! ============================================================
    ! 10. Final result
    ! ============================================================

    if (failures > 0) then

        print *
        print *, failures, &
            " FAILED: Dataset repeatability test(s)"

        error stop 1

    end if

    print *
    print *, "PASSED: Dataset repeatability test"


contains


    subroutine make_run(run, run_number, alpha, cl_offset, cd_offset, &
                        cm_offset, mach, reynolds)

        type(aero_run_type), intent(out) :: run

        integer, intent(in) :: run_number

        real(real64), intent(in) :: alpha(:)

        real(real64), intent(in) :: cl_offset
        real(real64), intent(in) :: cd_offset
        real(real64), intent(in) :: cm_offset

        real(real64), intent(in) :: mach
        real(real64), intent(in) :: reynolds

        integer :: n

        n = size(alpha)

        run%info%run = run_number

        allocate(run%alpha(n), run%mach(n), run%reynolds(n), run%cl(n), &
                 run%cd(n), run%cm(n))

        run%alpha = alpha

        run%mach = mach
        run%reynolds = reynolds

        ! All three underlying coefficient relationships are linear.
        !
        ! Therefore interpolation between different AoA grids should
        ! reproduce the analytical values exactly apart from normal
        ! floating-point roundoff.

        run%cl = 2.0_real64 * alpha + 1.0_real64 + cl_offset

        run%cd = 0.02_real64 + 0.005_real64 * alpha + cd_offset

        run%cm = -0.05_real64 - 0.01_real64 * alpha + cm_offset

    end subroutine make_run


    subroutine check(condition, message, failures_to_check)

        logical, intent(in) :: condition

        character(len=*), intent(in) :: message

        integer, intent(inout) :: failures_to_check

        if (.not. condition) then

            failures_to_check = failures_to_check + 1

            print *, "FAILED: ", message

        end if

    end subroutine check


end program test_dataset_repeatability