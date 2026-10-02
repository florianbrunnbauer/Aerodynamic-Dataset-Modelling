module dataset_repeatability

    use iso_fortran_env, only: real64

    use types, only: aero_dataset_type, grouped_dataset_type, mach_group_type, &
                     repeatability_group_type, dataset_repeatability_type

    use linear_interpolation, only: linear_interpolate

    implicit none
    private

    public :: analyse_repeatability, print_repeatability_report


contains


    subroutine analyse_repeatability(dataset, grouped, result, stat)

        type(aero_dataset_type), intent(in) :: dataset
        type(grouped_dataset_type), intent(in) :: grouped

        type(dataset_repeatability_type), intent(out) :: result

        integer, intent(out) :: stat

        integer :: i, j, group_index, n_repeated_groups

        stat = 0
        n_repeated_groups = 0


        if (.not. allocated(grouped%reynolds_groups)) then
            stat = 1
            return
        end if

        ! --------------------------------------------------------
        ! Count repeated Mach groups
        ! --------------------------------------------------------

        do i = 1, size(grouped%reynolds_groups)

            if (.not. allocated(grouped%reynolds_groups(i)%mach_groups)) cycle

            do j = 1, size(grouped%reynolds_groups(i)%mach_groups)

                if (size(grouped%reynolds_groups(i)% &
                    mach_groups(j)%run_indices) > 1) then

                    n_repeated_groups = n_repeated_groups + 1

                end if

            end do

        end do

        result%n_groups = n_repeated_groups

        allocate(result%groups(n_repeated_groups))

        ! --------------------------------------------------------
        ! Analyse repeated groups
        ! --------------------------------------------------------

        group_index = 0

        do i = 1, size(grouped%reynolds_groups)

            do j = 1, size(grouped%reynolds_groups(i)%mach_groups)

                if (size(grouped%reynolds_groups(i)% &
                    mach_groups(j)%run_indices) <= 1) cycle

                group_index = group_index + 1

                call analyse_mach_group(dataset, &
                                grouped%reynolds_groups(i)%mach_groups(j), &
                                grouped%reynolds_groups(i)%nominal_reynolds, &
                                result%groups(group_index), &
                                stat)

                if (stat /= 0) return

            end do

        end do


    end subroutine analyse_repeatability



    subroutine analyse_mach_group(dataset, mach_group, nominal_reynolds, result, stat)

        type(aero_dataset_type), intent(in) :: dataset
        type(mach_group_type), intent(in) :: mach_group

        real(real64), intent(in) :: nominal_reynolds

        type(repeatability_group_type), intent(out) :: result

        integer, intent(out) :: stat


        integer :: i, j, n_runs, run_index, reference_run_index

        integer :: n_points, max_points

        real(real64) :: alpha_min, alpha_max

        real(real64), allocatable :: cl_values(:), cd_values(:), cm_values(:)

        logical, allocatable :: alpha_mask(:)

        stat = 0

        n_runs = size(mach_group%run_indices)

        ! --------------------------------------------------------
        ! Determine common AoA interval
        ! --------------------------------------------------------

        run_index = mach_group%run_indices(1)

        alpha_min = minval(dataset%runs(run_index)%alpha)
        alpha_max = maxval(dataset%runs(run_index)%alpha)

        do i = 2, n_runs

            run_index = mach_group%run_indices(i)

            alpha_min = max(alpha_min, minval(dataset%runs(run_index)%alpha))

            alpha_max = min(alpha_max, maxval(dataset%runs(run_index)%alpha))

        end do

        if (alpha_min > alpha_max) then
            stat = 2
            return
        end if

        ! --------------------------------------------------------
        ! Find run with most points in common interval
        ! --------------------------------------------------------

        reference_run_index = 0
        max_points = 0

        do i = 1, n_runs

            run_index = mach_group%run_indices(i)

            n_points = count(dataset%runs(run_index)%alpha >= alpha_min .and. &
                             dataset%runs(run_index)%alpha <= alpha_max)

            if (n_points > max_points) then

                max_points = n_points
                reference_run_index = run_index

            end if

        end do

        if (reference_run_index == 0 .or. max_points < 2) then
            stat = 3
            return
        end if

        ! --------------------------------------------------------
        ! Build common AoA evaluation grid
        ! --------------------------------------------------------

        allocate(alpha_mask(size(dataset%runs(reference_run_index)%alpha)))

        alpha_mask = dataset%runs(reference_run_index)%alpha >= alpha_min .and. &
                     dataset%runs(reference_run_index)%alpha <= alpha_max

        result%alpha = pack(dataset%runs(reference_run_index)%alpha, alpha_mask)

        result%n_points = size(result%alpha)
        result%n_runs = n_runs

        result%alpha_min = alpha_min
        result%alpha_max = alpha_max

        result%nominal_mach = mach_group%nominal_mach
        result%nominal_reynolds = nominal_reynolds

        ! --------------------------------------------------------
        ! Allocate result arrays
        ! --------------------------------------------------------

        allocate(result%cl_mean(result%n_points), &
                 result%cl_std(result%n_points), &
                 result%cl_spread(result%n_points), &
                 result%cd_mean(result%n_points), &
                 result%cd_std(result%n_points), &
                 result%cd_spread(result%n_points), &
                 result%cm_mean(result%n_points), &
                 result%cm_std(result%n_points), &
                 result%cm_spread(result%n_points))

        allocate(cl_values(n_runs), cd_values(n_runs), cm_values(n_runs))

        ! --------------------------------------------------------
        ! Interpolate all runs onto common AoA grid
        ! --------------------------------------------------------

        do i = 1, result%n_points

            do j = 1, n_runs

                run_index = mach_group%run_indices(j)

                call linear_interpolate(dataset%runs(run_index)%alpha, &
                     dataset%runs(run_index)%cl, result%alpha(i), cl_values(j))

                call linear_interpolate(dataset%runs(run_index)%alpha, &
                     dataset%runs(run_index)%cd, result%alpha(i), cd_values(j))

                call linear_interpolate(dataset%runs(run_index)%alpha, &
                     dataset%runs(run_index)%cm, result%alpha(i), cm_values(j))

            end do

            call calculate_statistics(cl_values, result%cl_mean(i), &
                                      result%cl_std(i), result%cl_spread(i))


            call calculate_statistics(cd_values, result%cd_mean(i), &
                                      result%cd_std(i), result%cd_spread(i))


            call calculate_statistics(cm_values, result%cm_mean(i), &
                                      result%cm_std(i), result%cm_spread(i))

        end do

    end subroutine analyse_mach_group


    subroutine calculate_statistics(values, mean_value, std_value, spread)

        real(real64), intent(in) :: values(:)

        real(real64), intent(out) :: mean_value
        real(real64), intent(out) :: std_value
        real(real64), intent(out) :: spread

        integer :: n


        n = size(values)

        mean_value = sum(values) / real(n, real64)

        if (n > 1) then

            std_value = sqrt(sum((values - mean_value)**2) /real(n - 1, real64))

        else

            std_value = 0.0_real64

        end if

        spread = maxval(values) - minval(values)

    end subroutine calculate_statistics


    subroutine print_repeatability_report(result)

        type(dataset_repeatability_type), intent(in) :: result

        integer :: i

        print *
        print *, "=============================================================="
        print *, "REPORT: CRM repeatability analysis"
        print *, "=============================================================="
        print *

        if (result%n_groups == 0) then

            print *
            print *, "No repeated Mach groups found."
            print *
            return

        end if

        do i = 1, result%n_groups

            print '(A,ES12.4)', "Reynolds = ", result%groups(i)%nominal_reynolds

            print '(A,F5.2)', "Mach     = ", result%groups(i)%nominal_mach

            print '(A,I0)', "Runs     = ", result%groups(i)%n_runs

            print '(A,F8.3,A,F8.3)', "AoA      = ", result%groups(i)%alpha_min, &
                  " to ", result%groups(i)%alpha_max

            print '(A,I0)', "Points   = ", result%groups(i)%n_points

            print *
            print *, "Coefficient repeatability:"
            print *

            print '(A,ES12.4,A,ES12.4)', "Cl: mean std = ", &
                sum(result%groups(i)%cl_std) / &
                    real(result%groups(i)%n_points, real64), &
                "   max spread = ", &
                maxval(result%groups(i)%cl_spread)

            print '(A,ES12.4,A,ES12.4)', &
                "Cd: mean std = ", &
                sum(result%groups(i)%cd_std) / &
                    real(result%groups(i)%n_points, real64), &
                "   max spread = ", &
                maxval(result%groups(i)%cd_spread)

            print '(A,ES12.4,A,ES12.4)', &
                "Cm: mean std = ", &
                sum(result%groups(i)%cm_std) / &
                    real(result%groups(i)%n_points, real64), &
                "   max spread = ", &
                maxval(result%groups(i)%cm_spread)

            print *

        end do

    end subroutine print_repeatability_report


end module dataset_repeatability