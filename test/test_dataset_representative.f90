program test_dataset_representative

    use iso_fortran_env, only: real64

    use types, only: aero_dataset_type, grouped_dataset_type, &
                     representative_dataset_type

    use dataset_representative, only: &
        build_representative_dataset

    implicit none


    type(aero_dataset_type) :: dataset
    type(grouped_dataset_type) :: grouped
    type(representative_dataset_type) :: representative

    integer :: failures
    integer :: stat


    failures = 0

    print *
    print *, "=============================================================="
    print *, "TEST: Representative dataset"
    print *, "=============================================================="
    print *

    ! ============================================================
    ! 1. Synthetic runs
    ! ============================================================

    allocate(dataset%runs(4))

    ! Run 101
    ! Large AoA range.
    call make_run(dataset%runs(1), 101, [-2.0_real64, 0.0_real64, 2.0_real64, &
                                         4.0_real64])

    ! Run 102
    ! Same AoA range as run 101, but more points.
    ! Should therefore win the tie.
    call make_run(dataset%runs(2), 102, [-2.0_real64, -1.0_real64, 0.0_real64, &
                                         1.0_real64, 2.0_real64, 3.0_real64, &
                                         4.0_real64])

    ! Run 103
    ! More points than run 101 but smaller AoA range.
    ! Should NOT be selected.
    call make_run(dataset%runs(3), 103, [0.0_real64, 0.5_real64, 1.0_real64, &
                                         1.5_real64, 2.0_real64, 2.5_real64, &
                                         3.0_real64, 3.5_real64, 4.0_real64])

    ! Single-run Mach group.
    call make_run(dataset%runs(4), 104, [-1.0_real64, 0.0_real64, 1.0_real64])

    ! ============================================================
    ! 2. Synthetic grouping
    ! ============================================================

    allocate(grouped%reynolds_groups(1))

    grouped%reynolds_groups(1)%nominal_reynolds = 5.0e6_real64

    allocate(grouped%reynolds_groups(1)%mach_groups(2))

    ! Mach 0.70 contains three repeated runs.
    grouped%reynolds_groups(1)%mach_groups(1)%nominal_mach = 0.70_real64

    grouped%reynolds_groups(1)%mach_groups(1)%run_indices = [1, 2, 3]


    ! Mach 0.75 only contains run 104.
    grouped%reynolds_groups(1)%mach_groups(2)%nominal_mach = 0.75_real64

    grouped%reynolds_groups(1)%mach_groups(2)%run_indices = [4]

    ! ============================================================
    ! 3. Build representative dataset
    ! ============================================================

    call build_representative_dataset(dataset, grouped, representative, stat)

    call check(stat == 0, "Representative dataset creation failed.", failures)

    if (stat /= 0) then

        print *
        print *, "FAILED: Dataset representative test"
        print *
        
        error stop 1 
    end if

    ! ============================================================
    ! 4. Check structure
    ! ============================================================

    call check(size(representative%reynolds_groups) == 1, &
               "Expected one Reynolds group.", failures)

    call check(size(representative%reynolds_groups(1)%mach_groups) == 2, &
               "Expected two Mach groups.", failures)

    ! ============================================================
    ! 5. Check representative of Mach 0.70
    ! ============================================================

    call check(representative%reynolds_groups(1)%mach_groups(1)%run_index == 2, &
        "Run 102 should represent Mach 0.70.", failures)

    call check(dataset%runs(representative%reynolds_groups(1)% &
            mach_groups(1)%run_index)%info%run == 102, &
        "Incorrect CRM run selected for Mach 0.70.", failures)

    ! ============================================================
    ! 6. Check representative of Mach 0.75
    ! ============================================================

    call check(representative%reynolds_groups(1)%mach_groups(2)%run_index == 4, &
               "Single run should represent Mach 0.75.", failures)

    call check(dataset%runs(representative%reynolds_groups(1)% &
               mach_groups(2)%run_index)%info%run == 104, &
               "Incorrect CRM run selected for Mach 0.75.", failures)

    ! ============================================================
    ! 7. Final result
    ! ============================================================

    if (failures > 0) then

        print *
        print *, failures, " FAILED: Representative dataset test(s)"
        print*

        error stop 1
    end if

    print *
    print *, "PASSED: Representative dataset tests"
    print *


contains


    subroutine make_run(run, run_number, alpha)

        use types, only: aero_run_type

        type(aero_run_type), intent(out) :: run

        integer, intent(in) :: run_number

        real(real64), intent(in) :: alpha(:)

        integer :: n

        n = size(alpha)

        run%info%run = run_number

        allocate(run%alpha(n), run%mach(n), run%reynolds(n), &
                 run%cl(n), run%cd(n), run%cm(n))


        run%alpha = alpha

        run%mach = 0.70_real64
        run%reynolds = 5.0e6_real64

        run%cl = 0.0_real64
        run%cd = 0.0_real64
        run%cm = 0.0_real64

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


end program test_dataset_representative