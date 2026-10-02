module dataset_representative

    use iso_fortran_env, only: real64

    use types, only: aero_dataset_type, grouped_dataset_type, &
                     mach_group_type, representative_dataset_type

    implicit none
    private

    public :: build_representative_dataset, print_representative_report

contains


    subroutine build_representative_dataset(dataset, grouped, representative, stat)

        type(aero_dataset_type), intent(in) :: dataset
        type(grouped_dataset_type), intent(in) :: grouped

        type(representative_dataset_type), intent(out) :: representative

        integer, intent(out) :: stat

        integer :: i, j, representative_index


        stat = 0

        ! --------------------------------------------------------
        ! Check input
        ! --------------------------------------------------------

        if (.not. allocated(grouped%reynolds_groups)) then
            stat = 1
            return
        end if

        if (size(grouped%reynolds_groups) == 0) then
            stat = 2
            return
        end if

        ! --------------------------------------------------------
        ! Allocate Reynolds groups
        ! --------------------------------------------------------

        allocate(representative%reynolds_groups(size(grouped%reynolds_groups)))

        ! --------------------------------------------------------
        ! Process every Reynolds group
        ! --------------------------------------------------------

        do i = 1, size(grouped%reynolds_groups)

            representative%reynolds_groups(i)%nominal_reynolds = &
                grouped%reynolds_groups(i)%nominal_reynolds

            if (.not. allocated(grouped%reynolds_groups(i)%mach_groups)) then
                stat = 3
                return
            end if

            allocate(representative%reynolds_groups(i)%mach_groups( &
                    size(grouped%reynolds_groups(i)%mach_groups)))

            ! ----------------------------------------------------
            ! Process every Mach group
            ! ----------------------------------------------------

            do j = 1, size(grouped%reynolds_groups(i)%mach_groups)

                representative%reynolds_groups(i)%mach_groups(j)%nominal_mach = &
                    grouped%reynolds_groups(i)%mach_groups(j)%nominal_mach

                call select_representative_run(dataset, &
                                    grouped%reynolds_groups(i)%mach_groups(j), &
                                    representative_index, stat)

                if (stat /= 0) return

                representative%reynolds_groups(i)%mach_groups(j)%run_index = &
                    representative_index


            end do

        end do

    end subroutine build_representative_dataset


    subroutine select_representative_run(&
                    dataset, mach_group, representative_index, stat)

        type(aero_dataset_type), intent(in) :: dataset
        type(mach_group_type), intent(in) :: mach_group

        integer, intent(out) :: representative_index
        integer, intent(out) :: stat

        integer :: i, run_index

        integer :: n_points, best_n_points
        real(real64) :: alpha_range, best_alpha_range

        real(real64), parameter :: range_tolerance = 1.0e-12_real64


        stat = 0

        representative_index = 0

        best_alpha_range = -1.0_real64
        best_n_points = 0

        ! --------------------------------------------------------
        ! Check Mach group
        ! --------------------------------------------------------

        if (.not. allocated(mach_group%run_indices)) then
            stat = 1
            return
        end if

        if (size(mach_group%run_indices) == 0) then
            stat = 2
            return
        end if

        ! --------------------------------------------------------
        ! Find run with largest AoA coverage
        ! --------------------------------------------------------

        do i = 1, size(mach_group%run_indices)

            run_index = mach_group%run_indices(i)

            if (run_index < 1 .or. run_index > size(dataset%runs)) then
                stat = 3
                return
            end if

            alpha_range = maxval(dataset%runs(run_index)%alpha) - &
                          minval(dataset%runs(run_index)%alpha)

            n_points = size(dataset%runs(run_index)%alpha)

            ! ----------------------------------------------------
            ! Primary criterion:
            ! largest AoA range
            !
            ! Secondary criterion:
            ! largest number of measurement points
            ! ----------------------------------------------------

            if (alpha_range > best_alpha_range + range_tolerance) then

                best_alpha_range = alpha_range
                best_n_points = n_points

                representative_index = run_index

            else if (abs(alpha_range - best_alpha_range) <= range_tolerance) then

                if (n_points > best_n_points) then
                    best_n_points = n_points
                    representative_index = run_index
                end if

            end if

        end do

        if (representative_index == 0) then
            stat = 4
            return
        end if

    end subroutine select_representative_run


    subroutine print_representative_report( &
        dataset, representative)

        type(aero_dataset_type), intent(in) :: dataset

        type(representative_dataset_type), intent(in) :: representative


        integer :: i, j, run_index

        real(real64) :: alpha_min, alpha_max


        print *
        print *, "=============================================================="
        print *, "REPORT: Representative aerodynamic dataset"
        print *, "=============================================================="
        print *

        if (.not. allocated(representative%reynolds_groups)) then
            print *, "No representative Reynolds groups."
            return
        end if

        do i = 1, size(representative%reynolds_groups)

            print '(A,ES12.4)', "Reynolds = ", &
                  representative%reynolds_groups(i)%nominal_reynolds

            do j = 1, size(representative%reynolds_groups(i)%mach_groups)

                run_index = representative%reynolds_groups(i)% &
                            mach_groups(j)%run_index

                alpha_min = minval(dataset%runs(run_index)%alpha)

                alpha_max = maxval(dataset%runs(run_index)%alpha)

                print '(A,F5.2,A,I0,A,F8.3,A,F8.3)', &
                      "  Mach = ", representative%reynolds_groups(i)% &
                      mach_groups(j)%nominal_mach, &
                      "   CRM run = ", dataset%runs(run_index)%info%run, &
                      "   AoA = ", alpha_min, " to ", alpha_max

            end do

            print *

        end do

    end subroutine print_representative_report


end module dataset_representative