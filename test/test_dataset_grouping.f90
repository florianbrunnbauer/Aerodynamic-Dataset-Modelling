program test_dataset_grouping

    use iso_fortran_env, only: real64

    use types, only: aero_dataset_type, grouped_dataset_type, mach_group_type

    use dataset_grouping, only: group_dataset

    implicit none

    type(aero_dataset_type) :: dataset
    type(grouped_dataset_type) :: grouped

    integer :: stat, failures

    integer :: index_reynolds, index_mach


    failures = 0


    print *
    print *, "=============================================================="
    print *, "TEST: dataset grouping"
    print *, "=============================================================="
    print *


    ! ============================================================
    ! 1. Build synthetic dataset
    ! ============================================================

    allocate(dataset%runs(6))

    ! Re = 5.0e6, Mach = 0.70
    call make_run(dataset%runs(1), 101, 0.7005_real64, 4.99e6_real64)

    ! Re = 5.0e6, Mach = 0.70
    call make_run(dataset%runs(2), 102, 0.6995_real64, 5.01e6_real64)

    ! Re = 5.0e6, Mach = 0.75
    call make_run(dataset%runs(3), 103, 0.7508_real64, 5.00e6_real64)

    ! Re = 5.0e6, Mach = 0.70
    call make_run(dataset%runs(4), 104, 0.7015_real64, 4.98e6_real64)

    ! Re = 19.8e6, Mach = 0.70
    call make_run(dataset%runs(5), 201, 0.7007_real64, 19.75e6_real64)

    ! Re = 19.8e6, Mach = 0.75
    call make_run(dataset%runs(6), 202, 0.7492_real64, 19.85e6_real64)

    ! ============================================================
    ! 2. Group dataset
    ! ============================================================

    call group_dataset(dataset, grouped, stat)

    call check(stat == 0, "group_dataset should complete successfully.", &
               failures)

    if (stat /= 0) then
        error stop 1
    end if

    ! ============================================================
    ! 3. Check Reynolds groups
    ! ============================================================

    call check(size(grouped%reynolds_groups) == 2, &
        "Expected two Reynolds groups.", failures)

    ! ------------------------------------------------------------
    ! Re = 5.0e6
    ! ------------------------------------------------------------

    index_reynolds = findloc(grouped%reynolds_groups(:)%nominal_reynolds, &
                             5.0e6_real64, dim=1)

    call check(index_reynolds /= 0, "Re = 5.0e6 group not found.", failures)

    if (index_reynolds /= 0) then

        call check(size(grouped%reynolds_groups(index_reynolds)%mach_groups) == 2, &
            "Re = 5.0e6 should contain two Mach groups.", failures)

        ! --------------------------------------------------------
        ! Re = 5.0e6, Mach = 0.70
        ! --------------------------------------------------------

        index_mach = findloc(grouped%reynolds_groups(index_reynolds)% &
                            mach_groups(:)%nominal_mach, 0.70_real64, dim=1)

        call check(index_mach /= 0, "Mach = 0.70 group at Re = 5.0e6 not found.", &
                   failures)

        if (index_mach /= 0) then

            call check(size(grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach)%run_indices) == 3, &
                       "Re = 5.0e6, Mach = 0.70 should contain 3 runs.", failures)

            call check(group_contains_run(dataset, &
                       grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach), 101), &
                       "Run 101 missing from Mach = 0.70 group.", failures)

            call check(group_contains_run(dataset, &
                       grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach), 102), &
                       "Run 102 missing from Mach = 0.70 group.", failures)

            call check(group_contains_run(dataset, &
                       grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach), 104), &
                       "Run 104 missing from Mach = 0.70 group.", failures)

            call check(.not. group_contains_run(dataset, &
                       grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach), 103), &
                       "Run 103 incorrectly assigned to Mach = 0.70.", failures)

        end if

        ! --------------------------------------------------------
        ! Re = 5.0e6, Mach = 0.75
        ! --------------------------------------------------------

        index_mach = findloc(grouped%reynolds_groups(index_reynolds)% &
                             mach_groups(:)%nominal_mach, 0.75_real64, dim=1)

        call check(index_mach /= 0, "Mach = 0.75 group at Re = 5.0e6 not found.", &
                   failures)

        if (index_mach /= 0) then

            call check(size(grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach)%run_indices) == 1, &
                       "Re = 5.0e6, Mach = 0.75 should contain 1 run.", failures)

            call check(group_contains_run(dataset, &
                       grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach), 103), &
                       "Run 103 missing from Mach = 0.75 group.", failures)

        end if

    end if

    ! ------------------------------------------------------------
    ! Re = 19.8e6
    ! ------------------------------------------------------------

    index_reynolds = findloc(grouped%reynolds_groups(:)%nominal_reynolds, &
                             19.8e6_real64, dim=1)

    call check(index_reynolds /= 0, "Re = 19.8e6 group not found.", failures)

    if (index_reynolds /= 0) then

        call check(size(grouped%reynolds_groups(index_reynolds)% &
                   mach_groups) == 2, &
                   "Re = 19.8e6 should contain two Mach groups.", failures)

        ! --------------------------------------------------------
        ! Re = 19.8e6, Mach = 0.70
        ! --------------------------------------------------------

        index_mach = findloc(grouped%reynolds_groups(index_reynolds)% &
                             mach_groups(:)%nominal_mach, 0.70_real64, dim=1)

        call check(index_mach /= 0, &
                   "Mach = 0.70 group at Re = 19.8e6 not found.", failures)

        if (index_mach /= 0) then

            call check(group_contains_run(dataset, &
                       grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach), 201), &
                       "Run 201 missing from Re = 19.8e6, Mach = 0.70.", &
                       failures)

        end if

        ! --------------------------------------------------------
        ! Re = 19.8e6, Mach = 0.75
        ! --------------------------------------------------------

        index_mach = findloc(grouped%reynolds_groups(index_reynolds)% &
                             mach_groups(:)%nominal_mach, 0.75_real64, dim=1)

        call check(index_mach /= 0, &
                   "Mach = 0.75 group at Re = 19.8e6 not found.", failures)

        if (index_mach /= 0) then

            call check(group_contains_run(dataset, &
                       grouped%reynolds_groups(index_reynolds)% &
                       mach_groups(index_mach), 202 ), &
                       "Run 202 missing from Re = 19.8e6, Mach = 0.75.", &
                       failures)

        end if

    end if

    ! ============================================================
    ! 4. Final result
    ! ============================================================

    if (failures > 0) then

        print *
        print *, failures, " dataset grouping test(s) failed."
        print *

        error stop 1

    end if

    print *
    print *, "All dataset grouping tests passed."
    print *


contains


    subroutine make_run(run, run_number, mach, reynolds)

        use types, only: aero_run_type

        type(aero_run_type), intent(out) :: run

        integer, intent(in) :: run_number

        real(real64), intent(in) :: mach
        real(real64), intent(in) :: reynolds


        run%info%run = run_number

        allocate(run%alpha(3), run%mach(3), run%reynolds(3), run%cl(3), &
                 run%cd(3), run%cm(3))

        run%alpha = [0.0_real64, 1.0_real64, 2.0_real64]

        ! Give the individual points a small variation around
        ! the desired mean value.
        run%mach = [mach - 0.0002_real64, mach, mach + 0.0002_real64]

        run%reynolds = [reynolds * 0.999_real64, reynolds, reynolds * 1.001_real64]

        ! Aerodynamic coefficients are irrelevant for this test,
        ! but allocating them keeps the synthetic run realistic.
        run%cl = 0.0_real64
        run%cd = 0.0_real64
        run%cm = 0.0_real64

    end subroutine make_run


    logical function group_contains_run(dataset_to_check, &
                                        group, run_number) result(found)

        type(aero_dataset_type), intent(in) :: dataset_to_check
        type(mach_group_type), intent(in) :: group

        integer, intent(in) :: run_number

        integer :: i
        integer :: dataset_index

        found = .false.

        if (.not. allocated(group%run_indices)) then
            return
        end if

        do i = 1, size(group%run_indices)

            dataset_index = group%run_indices(i)

            if (dataset_to_check%runs(dataset_index)%info%run == &
                run_number) then

                found = .true.
                return

            end if

        end do

    end function group_contains_run


    subroutine check(condition, message, failures_to_check)

        logical, intent(in) :: condition

        character(len=*), intent(in) :: message

        integer, intent(inout) :: failures_to_check


        if (.not. condition) then

            failures_to_check = failures_to_check + 1

            print *, "FAILED: ", message

        end if


    end subroutine check


end program test_dataset_grouping