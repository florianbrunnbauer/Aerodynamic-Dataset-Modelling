program validate_interpolation_methods
    use iso_fortran_env, only: real64, error_unit
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use types, only: run_info_type, aero_run_type
    use data_io, only: inspect_crm_run, read_crm_run
    use linear_interpolation, only: linear_interpolate
    use pchip_interpolation, only: pchip_interpolate
    use akima_interpolation, only: akima_interpolate
    implicit none

    integer, parameter :: retained_ids(8) = [39, 41, 42, 43, 44, 46, 47, 48]
    character(len=6), parameter :: method_names(3) = [character(len=6) :: 'linear', 'pchip', 'akima']
    character(len=2), parameter :: coefficient_names(3) = ['Cl', 'Cd', 'Cm']
    ! Use measured Mach(alpha), interpolated LINEARLY in each training sweep.
    ! Set false for the simpler run-mean-Mach coordinate model instead.
    logical, parameter :: use_pointwise_mach = .true.
    real(real64), parameter :: nominal_reynolds = 5.0e6_real64
    real(real64), parameter :: reynolds_group_tolerance = 0.05_real64

    type :: error_statistics
        integer :: n = 0
        real(real64) :: sum_absolute = 0.0_real64
        real(real64) :: sum_squared = 0.0_real64
        real(real64) :: maximum_absolute = 0.0_real64
    end type error_statistics

    type(aero_run_type) :: runs(8), swap_run
    type(run_info_type) :: info
    type(error_statistics) :: fold(3,3), pooled_alpha(3,3), pooled_mach(3,3)
    real(real64) :: mean_mach(8), swap_mach, alpha_low, alpha_high, query_alpha, query_mach
    real(real64) :: mach_low, mach_high, actual, predicted, lower_value, upper_value
    real(real64), allocatable :: training_alpha(:), training_values(:), values(:)
    character(len=:), allocatable :: data_directory, output_prefix
    character(len=30) :: basename
    integer :: i, j, k, method, coefficient, n, stat, details_unit, summary_unit
    integer :: outside_alpha, outside_mach, eligible

    data_directory = argument_or_default(1, 'data')
    output_prefix = argument_or_default(2, 'interpolation_validation')
    if (command_argument_count() > 2) error stop 'Usage: validator [data_directory] [output_prefix]'

    print '(a)', ''
    print '(a)', '=== validate_interpolation_methods ==='
    print '(a)', 'Loading corrected CRM sweeps; linear/PCHIP/Akima in alpha, always linear in Mach.'
    
    do i = 1, size(runs)
        write(basename, '(a,i0,a)') 't197R', retained_ids(i), '.csv'
        call inspect_crm_run(data_directory//'/'//trim(basename), info, stat)
        if (stat /= 0) call fatal('Cannot inspect '//data_directory//'/'//trim(basename))
        call read_crm_run(info, runs(i), stat)
        if (stat /= 0) call fatal('Cannot read '//data_directory//'/'//trim(basename))
        call check_run(runs(i))
        if (runs(i)%info%run /= retained_ids(i)) call fatal('File has an unexpected run ID.')
        if (i > 1) then
            if (runs(i)%info%test /= runs(1)%info%test .or. &
                runs(i)%info%config /= runs(1)%info%config .or. &
                runs(i)%info%confts /= runs(1)%info%confts .or. &
                runs(i)%info%conft /= runs(1)%info%conft) call fatal('Runs have incompatible configurations.')
        end if
        mean_mach(i) = sum(runs(i)%mach)/real(size(runs(i)%mach), real64)
    end do

    ! Sort whole sweeps by measured mean Mach; retain original alpha samples.
    do i = 2, size(runs)
        j = i
        do while (j > 1)
            if (mean_mach(j) >= mean_mach(j-1)) exit
            swap_run = runs(j-1)
            runs(j-1) = runs(j)
            runs(j) = swap_run
            swap_mach = mean_mach(j-1)
            mean_mach(j-1) = mean_mach(j)
            mean_mach(j) = swap_mach
            j = j-1
        end do
    end do
    if (any(mean_mach(2:) <= mean_mach(:size(runs)-1))) call fatal('Duplicate mean Mach levels.')

    print '(a)', 'Run    Points    Mean Mach     Alpha minimum/maximum'
    do i = 1, size(runs)
        print '(i3,5x,i3,5x,f9.5,4x,2f10.3)', runs(i)%info%run, size(runs(i)%alpha), &
                mean_mach(i), runs(i)%alpha(1), runs(i)%alpha(size(runs(i)%alpha))
    end do
    if (use_pointwise_mach) then
        print '(a)', 'Mach coordinates: measured WCMACH(alpha); linear alpha interpolation for Mach coordinates.'
    else
        print '(a)', 'Mach coordinates: mean measured Mach of each sweep.'
    end if

    open(newunit=details_unit, file=output_prefix//'_points.csv', status='replace', action='write', iostat=stat)
    if (stat /= 0) call fatal('Cannot create points CSV: '//output_prefix//'_points.csv')
    open(newunit=summary_unit, file=output_prefix//'_summary.csv', status='replace', action='write', iostat=stat)
    if (stat /= 0) call fatal('Cannot create summary CSV: '//output_prefix//'_summary.csv')
    write(details_unit, '(a)') 'validation,held_out_run,lower_run,upper_run,alpha,mach,mach_low,mach_high,'// &
                              'alpha_method,coefficient,measured,predicted,error'
    write(summary_unit, '(a)') 'validation,held_out_run,lower_run,upper_run,mach_mean,mach_low_mean,mach_high_mean,'// &
        'alpha_method,coefficient,n_evaluated,n_candidates,skipped_alpha,skipped_mach,mae,rmse,max_abs_error'

    ! Alpha-only leave-one-point-out: remove one interior knot at a time.
    ! Endpoints are excluded because predicting them would be extrapolation.
    print '(a)', ''
    print '(a)', '=== Alpha-only leave-one-point-out ==='
    do i = 1, size(runs)
        n = size(runs(i)%alpha)
        if (n < 6) call fatal('Alpha validation needs at least 6 points to retain 5 for Akima.')
        fold = error_statistics()
        allocate(training_alpha(n-1), training_values(n-1), values(n))
        do k = 2, n-1
            training_alpha(:k-1) = runs(i)%alpha(:k-1)
            training_alpha(k:) = runs(i)%alpha(k+1:)
            do coefficient = 1, 3
                call coefficient_array(runs(i), coefficient, values)
                actual = values(k)
                training_values(:k-1) = values(:k-1)
                training_values(k:) = values(k+1:)
                do method = 1, 3
                    call interpolate_alpha(training_alpha, training_values, runs(i)%alpha(k), method, predicted)
                    call add_error(fold(method,coefficient), predicted-actual)
                    call add_error(pooled_alpha(method,coefficient), predicted-actual)
                    call write_point('alpha', i, i, i, runs(i)%alpha(k), runs(i)%mach(k), &
                                     runs(i)%mach(k), runs(i)%mach(k), method, coefficient, actual, predicted)
                end do
            end do
        end do
        deallocate(training_alpha, training_values, values)
        print '(a,i0)', 'Held-out points from run ', runs(i)%info%run
        call report_fold('alpha', i, i, i, n-2, 0, 0)
    end do
    print '(a)', 'Pooled alpha-only errors (point-weighted):'
    call print_statistics(pooled_alpha)

    ! Leave-one-Mach-sweep-out: the entire target sweep is excluded from
    ! prediction. Only its two immediate surviving neighbors are training data.
    ! No averaging duplicate runs, extrapolation, or Reynolds interpolation.
    print '(a)', ''
    print '(a)', '=== Leave-one-Mach-sweep-out ==='
    print '(a)', 'Boundary Mach sweeps are excluded; no Mach extrapolation is performed.'
    do i = 2, size(runs)-1
        fold = error_statistics()
        outside_alpha = 0
        outside_mach = 0
        alpha_low = max(runs(i-1)%alpha(1), runs(i+1)%alpha(1))
        alpha_high = min(runs(i-1)%alpha(size(runs(i-1)%alpha)), &
                         runs(i+1)%alpha(size(runs(i+1)%alpha)))
        do k = 1, size(runs(i)%alpha)
            query_alpha = runs(i)%alpha(k)
            if (query_alpha < alpha_low .or. query_alpha > alpha_high) then
                outside_alpha = outside_alpha+1
                cycle
            end if
            if (use_pointwise_mach) then
                query_mach = runs(i)%mach(k)
                call linear_interpolate(runs(i-1)%alpha, runs(i-1)%mach, query_alpha, mach_low)
                call linear_interpolate(runs(i+1)%alpha, runs(i+1)%mach, query_alpha, mach_high)
            else
                query_mach = mean_mach(i)
                mach_low = mean_mach(i-1)
                mach_high = mean_mach(i+1)
            end if
            ! Support filtering is independent of the coefficient method.
            if (mach_high <= mach_low .or. query_mach < mach_low .or. query_mach > mach_high) then
                outside_mach = outside_mach+1
                cycle
            end if
            do coefficient = 1, 3
                actual = coefficient_value(runs(i), coefficient, k)
                do method = 1, 3
                    call evaluate_sweep(runs(i-1), coefficient, method, query_alpha, lower_value)
                    call evaluate_sweep(runs(i+1), coefficient, method, query_alpha, upper_value)
                    call linear_interpolate([mach_low, mach_high], [lower_value, upper_value], query_mach, predicted)
                    call add_error(fold(method,coefficient), predicted-actual)
                    call add_error(pooled_mach(method,coefficient), predicted-actual)
                    call write_point('mach', i, i-1, i+1, query_alpha, query_mach, mach_low, mach_high, &
                                     method, coefficient, actual, predicted)
                end do
            end do
        end do
        eligible = size(runs(i)%alpha)-outside_alpha-outside_mach
        print '(a,i0,a,i0,a,i0)', 'Held-out run ', runs(i)%info%run, ' between runs ', &
                                 runs(i-1)%info%run, ' and ', runs(i+1)%info%run
        print '(a,2f10.3)', 'Training sweeps shared alpha range: ', alpha_low, alpha_high
        print '(a,f9.5,a,3(i0,1x))', 'Mean-Mach bracket width: ', mean_mach(i+1)-mean_mach(i-1), &
                        '; evaluated / outside alpha / outside Mach: ', eligible, outside_alpha, outside_mach
        if (eligible == 0) call fatal('No supported points in this Mach fold.')
        call report_fold('mach', i, i-1, i+1, size(runs(i)%alpha), outside_alpha, outside_mach)
    end do
    print '(a)', 'Pooled alpha+Mach errors (point-weighted):'
    call print_statistics(pooled_mach)
    close(details_unit)
    close(summary_unit)
    print '(a)', ''
    print '(a)', 'Wrote '//output_prefix//'_points.csv and '//output_prefix//'_summary.csv'
    print '(a)', 'Errors = predicted - measured. No accuracy pass/fail threshold is imposed.'

contains

    function argument_or_default(position, default) result(value)
        integer, intent(in) :: position
        character(len=*), intent(in) :: default
        character(len=:), allocatable :: value
        integer :: length
        call get_command_argument(position, length=length)
        if (length == 0) then
            value = default
        else
            allocate(character(len=length) :: value)
            call get_command_argument(position, value)
        end if
    end function argument_or_default

    subroutine fatal(message)
        character(len=*), intent(in) :: message
        write(error_unit, '(a)') 'Validation error: '//message
        error stop 1
    end subroutine fatal

    subroutine check_run(run)
        type(aero_run_type), intent(in) :: run
        integer :: count
        real(real64) :: re_mean
        if (.not. allocated(run%alpha) .or. .not. allocated(run%mach) .or. &
            .not. allocated(run%reynolds) .or. .not. allocated(run%cl) .or. &
            .not. allocated(run%cd) .or. .not. allocated(run%cm)) call fatal('Unallocated run arrays.')
        count = size(run%alpha)
        if (count < 6) call fatal('Each selected run must have at least 6 points.')
        if (size(run%mach) /= count .or. size(run%reynolds) /= count .or. &
            size(run%cl) /= count .or. size(run%cd) /= count .or. size(run%cm) /= count) &
            call fatal('Run arrays have unequal sizes.')
        if (.not. all(ieee_is_finite(run%alpha)) .or. .not. all(ieee_is_finite(run%mach)) .or. &
            .not. all(ieee_is_finite(run%reynolds)) .or. .not. all(ieee_is_finite(run%cl)) .or. &
            .not. all(ieee_is_finite(run%cd)) .or. .not. all(ieee_is_finite(run%cm))) call fatal('Nonfinite run data.')
        if (any(run%alpha(2:) <= run%alpha(:count-1))) call fatal('Alpha must be strictly increasing.')
        if (any(run%mach <= 0.0_real64) .or. any(run%reynolds <= 0.0_real64)) &
            call fatal('Nonpositive Mach or Reynolds number.')
        re_mean = sum(run%reynolds)/real(count, real64)
        if (abs(re_mean-nominal_reynolds) > reynolds_group_tolerance*nominal_reynolds) &
            call fatal('Run outside the selected Reynolds group (5e6 +/- 5%).')
    end subroutine check_run

    subroutine coefficient_array(run, coefficient_to_query, output)
        type(aero_run_type), intent(in) :: run
        integer, intent(in) :: coefficient_to_query
        real(real64), intent(out) :: output(:)
        select case(coefficient_to_query)
        case(1)
            output = run%cl
        case(2)
            output = run%cd
        case(3)
            output = run%cm
        end select
    end subroutine coefficient_array

    function coefficient_value(run, coefficient_to_query, point) result(value)
        type(aero_run_type), intent(in) :: run
        integer, intent(in) :: coefficient_to_query, point
        real(real64) :: value
        select case(coefficient_to_query)
        case(1)
            value = run%cl(point)
        case(2)
            value = run%cd(point)
        case(3)
            value = run%cm(point)
        case default
            call fatal('Unknown coefficient.')
            value = 0.0_real64
        end select
    end function coefficient_value

    subroutine interpolate_alpha(x, y, query, selected_method, output)
        real(real64), intent(in) :: x(:), y(:), query
        integer, intent(in) :: selected_method
        real(real64), intent(out) :: output
        select case(selected_method)
        case(1)
            call linear_interpolate(x, y, query, output)
        case(2)
            call pchip_interpolate(x, y, query, output)
        case(3)
            call akima_interpolate(x, y, query, output)
        case default
            call fatal('Unknown interpolation method.')
        end select
        if (.not. ieee_is_finite(output)) call fatal('Nonfinite interpolation result.')
    end subroutine interpolate_alpha

    subroutine evaluate_sweep(run, coefficient_to_evaluate, selected_method, query, output)
        type(aero_run_type), intent(in) :: run
        integer, intent(in) :: coefficient_to_evaluate, selected_method
        real(real64), intent(in) :: query
        real(real64), intent(out) :: output
        select case(coefficient_to_evaluate)
        case(1)
            call interpolate_alpha(run%alpha, run%cl, query, selected_method, output)
        case(2)
            call interpolate_alpha(run%alpha, run%cd, query, selected_method, output)
        case(3)
            call interpolate_alpha(run%alpha, run%cm, query, selected_method, output)
        end select
    end subroutine evaluate_sweep

    subroutine add_error(stats, error)
        type(error_statistics), intent(inout) :: stats
        real(real64), intent(in) :: error
        if (.not. ieee_is_finite(error)) call fatal('Nonfinite prediction error.')
        stats%n = stats%n+1
        stats%sum_absolute = stats%sum_absolute+abs(error)
        stats%sum_squared = stats%sum_squared+error**2
        stats%maximum_absolute = max(stats%maximum_absolute, abs(error))
    end subroutine add_error

    subroutine metrics(stats, mae, rmse)
        type(error_statistics), intent(in) :: stats
        real(real64), intent(out) :: mae, rmse
        if (stats%n <= 0) call fatal('Cannot report an empty error sample.')
        mae = stats%sum_absolute/real(stats%n, real64)
        rmse = sqrt(stats%sum_squared/real(stats%n, real64))
    end subroutine metrics

    subroutine print_statistics(stats)
        type(error_statistics), intent(in) :: stats(3,3)
        real(real64) :: mae, rmse
        integer :: m, c
        print '(a)', 'Method  Coef   N          MAE           RMSE          Max abs error'
        do c = 1, 3
            do m = 1, 3
                call metrics(stats(m,c), mae, rmse)
                print '(a6,2x,a2,2x,i4,3(2x,es12.5))', method_names(m), coefficient_names(c), &
                      stats(m,c)%n, mae, rmse, stats(m,c)%maximum_absolute
            end do
        end do
    end subroutine print_statistics

    subroutine report_fold(kind, target, left, right, candidates, skipped_alpha, skipped_mach)
        character(len=*), intent(in) :: kind
        integer, intent(in) :: target, left, right, candidates, skipped_alpha, skipped_mach
        real(real64) :: mae, rmse
        integer :: m, c
        call print_statistics(fold)
        do c = 1, 3
            do m = 1, 3
                call metrics(fold(m,c), mae, rmse)
                write(summary_unit, '(*(g0,:,","))') kind, runs(target)%info%run, runs(left)%info%run, &
                    runs(right)%info%run, mean_mach(target), mean_mach(left), mean_mach(right), &
                    trim(method_names(m)), coefficient_names(c), fold(m,c)%n, candidates, skipped_alpha, &
                    skipped_mach, mae, rmse, fold(m,c)%maximum_absolute
            end do
        end do
    end subroutine report_fold

    subroutine write_point(kind, target, left, right, alpha, mach, low_mach, high_mach, m, c, measured, estimate)
        character(len=*), intent(in) :: kind
        integer, intent(in) :: target, left, right, m, c
        real(real64), intent(in) :: alpha, mach, low_mach, high_mach, measured, estimate
        write(details_unit, '(*(g0,:,","))') kind, runs(target)%info%run, runs(left)%info%run, &
            runs(right)%info%run, alpha, mach, low_mach, high_mach, trim(method_names(m)), &
            coefficient_names(c), measured, estimate, estimate-measured
    end subroutine write_point

end program validate_interpolation_methods
