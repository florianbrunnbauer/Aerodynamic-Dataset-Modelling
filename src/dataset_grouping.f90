module dataset_grouping

    use iso_fortran_env, only: real64

    use types, only: aero_dataset_type, grouped_dataset_type, &
                     reynolds_group_type, mach_group_type

    implicit none
    private

    public :: group_dataset, print_grouping_report


    ! Known set values from the CRM test run log.
    real(real64), parameter :: nominal_mach_levels(*) = [ &
                0.70_real64, 0.75_real64, 0.80_real64, 0.83_real64, 0.85_real64, &
                0.86_real64, 0.87_real64, 0.88_real64, 0.92_real64]

    real(real64), parameter :: nominal_reynolds_levels(*) = [5.0e6_real64, &
                                              19.8e6_real64, 30.0e6_real64]


    ! Mach levels are separated by at least 0.01.
    ! 0.004 therefore avoids overlap between neighbouring groups.
    real(real64), parameter :: mach_tolerance = 0.004_real64

    ! Relative tolerance because the absolute Reynolds variation can
    ! increase with Reynolds number.
    real(real64), parameter :: reynolds_relative_tolerance = 0.02_real64


contains


    subroutine group_dataset(dataset, grouped, stat)

        type(aero_dataset_type), intent(in) :: dataset
        type(grouped_dataset_type), intent(out) :: grouped

        integer, intent(out) :: stat

        integer :: i, reynolds_group_index, mach_group_index, classification_stat

        real(real64) :: mach_mean, reynolds_mean

        real(real64) :: nominal_mach, nominal_reynolds


        stat = 0


        if (.not. allocated(dataset%runs)) then
            stat = 1
            return
        end if


        if (size(dataset%runs) == 0) then
            stat = 2
            return
        end if


        do i = 1, size(dataset%runs)

            !--------------------------------
            ! Determine measured mean values
            !--------------------------------
            mach_mean = sum(dataset%runs(i)%mach) / &
                        real(size(dataset%runs(i)%mach), real64)

            reynolds_mean = sum(dataset%runs(i)%reynolds) / &
                            real(size(dataset%runs(i)%reynolds), real64)

            !--------------------------------
            ! Assign nominal Mach value
            !--------------------------------
            call classify_mach(mach_mean, nominal_mach, classification_stat)

            if (classification_stat /= 0) then

                print *, "Could not classify Mach number for run ", &
                         dataset%runs(i)%info%run

                print *, "Measured mean Mach: ", mach_mean

                stat = 3
                return

            end if

            !--------------------------------
            ! Assign nominal Reynolds value
            !--------------------------------
            call classify_reynolds(reynolds_mean, nominal_reynolds, &
                                                        classification_stat)

            if (classification_stat /= 0) then

                print *, "Could not classify Reynolds number for run ", &
                         dataset%runs(i)%info%run

                print *, "Measured mean Reynolds number: ", reynolds_mean

                stat = 4
                return

            end if

            !--------------------------------
            ! Find or create Reynolds group
            !--------------------------------
            reynolds_group_index = find_reynolds_group(grouped%reynolds_groups, &
                                                       nominal_reynolds)


            if (reynolds_group_index == 0) then

                call append_reynolds_group(grouped%reynolds_groups, &
                                                            nominal_reynolds)

                reynolds_group_index = size(grouped%reynolds_groups)

            end if

            !--------------------------------
            ! Find or create Mach group
            !--------------------------------
            mach_group_index = find_mach_group(grouped%reynolds_groups( &
                                               reynolds_group_index)%mach_groups, &
                                               nominal_mach)

            if (mach_group_index == 0) then

                call append_mach_group(grouped%reynolds_groups( &
                                reynolds_group_index)%mach_groups, nominal_mach)

                mach_group_index = size(grouped%reynolds_groups( &
                                reynolds_group_index)%mach_groups)

            end if

            !--------------------------------
            ! Store dataset index
            !--------------------------------
            call append_run_index(grouped%reynolds_groups( &
                                  reynolds_group_index)%mach_groups( &
                                  mach_group_index)%run_indices, i)

        end do

    end subroutine group_dataset


    subroutine classify_mach(value, nominal, stat)

        real(real64), intent(in) :: value
        real(real64), intent(out) :: nominal

        integer, intent(out) :: stat


        nominal = nearest_nominal(value, nominal_mach_levels)


        if (abs(value - nominal) > mach_tolerance) then
            stat = 1
        else
            stat = 0
        end if

    end subroutine classify_mach


    subroutine classify_reynolds(value, nominal, stat)

        real(real64), intent(in) :: value
        real(real64), intent(out) :: nominal

        integer, intent(out) :: stat

        real(real64) :: relative_difference


        nominal = nearest_nominal(value, nominal_reynolds_levels)

        relative_difference = abs(value - nominal) / nominal

        if (relative_difference > reynolds_relative_tolerance) then
            stat = 1
        else
            stat = 0
        end if

    end subroutine classify_reynolds


    pure real(real64) function nearest_nominal(value, levels) result(nominal)

        real(real64), intent(in) :: value
        real(real64), intent(in) :: levels(:)

        integer :: i
        integer :: nearest_index

        nearest_index = 1

        do i = 2, size(levels)

            if (abs(value - levels(i)) < &
                abs(value - levels(nearest_index))) then

                nearest_index = i

            end if

        end do

        nominal = levels(nearest_index)

    end function nearest_nominal


    integer function find_reynolds_group(groups, nominal_reynolds) result(index)

        type(reynolds_group_type), allocatable, intent(in) :: groups(:)

        real(real64), intent(in) :: nominal_reynolds

        integer :: i

        index = 0

        if (.not. allocated(groups)) then
            return
        end if

        do i = 1, size(groups)
            if (groups(i)%nominal_reynolds == nominal_reynolds) then

                index = i
                return

            end if
        end do

    end function find_reynolds_group


    integer function find_mach_group(groups, nominal_mach) result(index)

        type(mach_group_type), allocatable, intent(in) :: groups(:)

        real(real64), intent(in) :: nominal_mach

        integer :: i

        index = 0

        if (.not. allocated(groups)) then
            return
        end if

        do i = 1, size(groups)
            if (groups(i)%nominal_mach == nominal_mach) then

                index = i
                return

            end if
        end do

    end function find_mach_group


    subroutine append_reynolds_group(groups, nominal_reynolds)

        type(reynolds_group_type), allocatable, intent(inout) :: groups(:)

        real(real64), intent(in) :: nominal_reynolds

        type(reynolds_group_type), allocatable :: temp(:)

        integer :: n

        if (.not. allocated(groups)) then

            allocate(groups(1))

            groups(1)%nominal_reynolds = nominal_reynolds

            return

        end if

        n = size(groups)

        allocate(temp(n + 1))

        temp(1:n) = groups

        temp(n + 1)%nominal_reynolds = nominal_reynolds

        call move_alloc(temp, groups)

    end subroutine append_reynolds_group


    subroutine append_mach_group(groups, nominal_mach)

        type(mach_group_type), allocatable, intent(inout) :: groups(:)

        real(real64), intent(in) :: nominal_mach

        type(mach_group_type), allocatable :: temp(:)

        integer :: n

        if (.not. allocated(groups)) then

            allocate(groups(1))

            groups(1)%nominal_mach = nominal_mach

            return

        end if

        n = size(groups)

        allocate(temp(n + 1))

        temp(1:n) = groups

        temp(n + 1)%nominal_mach = nominal_mach

        call move_alloc(temp, groups)

    end subroutine append_mach_group


    subroutine append_run_index(indices, index)

        integer, allocatable, intent(inout) :: indices(:)

        integer, intent(in) :: index

        integer, allocatable :: temp(:)

        integer :: n


        if (.not. allocated(indices)) then

            allocate(indices(1))

            indices(1) = index

            return

        end if

        n = size(indices)

        allocate(temp(n + 1))

        temp(1:n) = indices
        temp(n + 1) = index

        call move_alloc(temp, indices)

    end subroutine append_run_index


    subroutine print_grouping_report(dataset, grouped)

        type(aero_dataset_type), intent(in) :: dataset
        type(grouped_dataset_type), intent(in) :: grouped

        integer :: i, j, k, run_index

        print *
        print *, "=============================================================="
        print *, "REPORT: CRM dataset grouping"
        print *, "=============================================================="
        print *


        if (.not. allocated(grouped%reynolds_groups)) then

            print *, "No Reynolds groups available."
            return

        end if


        do i = 1, size(grouped%reynolds_groups)

            print '(A,ES12.4)', "Reynolds = ", &
                grouped%reynolds_groups(i)%nominal_reynolds

            if (.not. allocated(grouped%reynolds_groups(i)%mach_groups)) then

                print *, "  No Mach groups."
                cycle

            end if

            do j = 1, size(grouped%reynolds_groups(i)%mach_groups)

                print '(A,F5.2,A,I0)', "  Mach = ", &
                    grouped%reynolds_groups(i)% mach_groups(j)%nominal_mach, &
                    "   Number of runs = ", size(grouped%reynolds_groups(i)% &
                        mach_groups(j)%run_indices)

                write(*, '(A)', advance='no') &
                    "    CRM runs: "

                do k = 1, size(grouped%reynolds_groups(i)% &
                        mach_groups(j)%run_indices)

                    run_index = grouped%reynolds_groups(i)% &
                            mach_groups(j)%run_indices(k)

                    write(*, '(I0,1X)', advance='no') &
                        dataset%runs(run_index)%info%run

                end do

                print *

            end do

            print *

        end do

    end subroutine print_grouping_report


end module dataset_grouping