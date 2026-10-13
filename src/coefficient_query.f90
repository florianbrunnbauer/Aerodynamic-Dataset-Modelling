module coefficient_query
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
    use types, only: aero_run_type
    use linear_interpolation, only: linear_interpolate
    use pchip_interpolation, only: pchip_interpolate
    use akima_interpolation, only: akima_interpolate

    implicit none
    private
    public :: query_coefficients, query_status_message

    integer, parameter, public :: query_ok=0, query_empty_dataset=1, query_invalid_data=2
    integer, parameter, public :: query_invalid_input=3, query_invalid_method=4
    integer, parameter, public :: query_alpha_outside=5, query_mach_outside=6
    integer, parameter, public :: query_insufficient_points=7, query_invalid_mach_grid=8
    integer, parameter, public :: query_incompatible_runs=9

contains

    ! Runs must already be selected for one configuration and nominal Reynolds group.
    ! Corrected alpha is in degrees. Mach is dimensionless. No extrapolation.
    ! On failure: stat /= query_ok; all three coefficients are quiet NaNs.
    subroutine query_coefficients(runs, alpha_query, mach_query, cl, cd, cm, stat, alpha_method, use_mean_mach)

        type(aero_run_type), intent(in) :: runs(:)
        real(real64), intent(in) :: alpha_query, mach_query
        real(real64), intent(out) :: cl, cd, cm
        integer, intent(out) :: stat
        character(len=*), intent(in), optional :: alpha_method
        logical, intent(in), optional :: use_mean_mach
        real(real64), allocatable :: means(:), local_mach(:)
        integer, allocatable :: order(:)
        logical, allocatable :: supported(:)
        real(real64) :: nan, tolerance, reynolds_reference, re_mean, low_values(3), high_values(3), result(3)
        integer :: i, j, k, n, method, left, right, swap, exact, pair_count
        logical :: mean_mode

        nan = ieee_value(0.0_real64, ieee_quiet_nan)

        cl = nan; cd = nan; cm = nan
        stat = query_invalid_input

        if (.not. ieee_is_finite(alpha_query) .or. .not. ieee_is_finite(mach_query)) return

        if (mach_query <= 0.0_real64) return

        method = 3 ! Akima default; alternatives remain available for comparison.

        if (present(alpha_method)) then
            select case(trim(adjustl(alpha_method)))
            case('linear'); method = 1
            case('pchip'); method = 2
            case('akima'); method = 3
            case default
                stat = query_invalid_method
                return
            end select
        end if

        mean_mode = .false.

        if (present(use_mean_mach)) mean_mode = use_mean_mach

        n = size(runs)
        stat = query_empty_dataset
        
        if (n == 0) return
        
        allocate(means(n), local_mach(n), order(n), supported(n))
        supported = .false.
        local_mach = nan
        reynolds_reference = 0.0_real64
        
        do i = 1, n
            stat = query_invalid_data

            if (.not. valid_run(runs(i))) return

            means(i) = sum(runs(i)%mach)/real(size(runs(i)%mach),real64)
            re_mean = sum(runs(i)%reynolds)/real(size(runs(i)%reynolds),real64)

            if (.not. ieee_is_finite(means(i)) .or. .not. ieee_is_finite(re_mean)) return

            if (i == 1) reynolds_reference = re_mean

            stat = query_incompatible_runs

            ! 5% mean-Re tolerance groups small experimental variations, not interpolation in Re.
            if (abs(re_mean-reynolds_reference) > 0.05_real64*reynolds_reference) return

            if (runs(i)%info%test /= runs(1)%info%test .or. &
                runs(i)%info%config /= runs(1)%info%config .or. &
                runs(i)%info%confts /= runs(1)%info%confts .or. &
                runs(i)%info%conft /= runs(1)%info%conft) return

            order(i) = i

            if (alpha_query < runs(i)%alpha(1) .or. &
                alpha_query > runs(i)%alpha(size(runs(i)%alpha))) cycle

            supported(i) = .true.

            if (mean_mode) then
                local_mach(i) = means(i)
            else
                ! The Mach-coordinate interpolation is always linear, irrespective of alpha_method.
                call linear_interpolate(runs(i)%alpha, runs(i)%mach, alpha_query, local_mach(i))
            end if

        end do

        ! Sort indices only; the caller's data and original samples remain unchanged.
        do i = 2, n
            j = i
            do while (j > 1)
                if (means(order(j)) >= means(order(j-1))) exit
                swap = order(j-1); order(j-1) = order(j); order(j) = swap
                j = j-1
            end do
        end do

        tolerance = 64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(mach_query),maxval(abs(means)))
        stat = query_invalid_mach_grid

        do i = 2, n
            if (means(order(i))-means(order(i-1)) <= tolerance) return
        end do

        ! Reject crossing/duplicate local Mach coordinates wherever neighboring sweeps are supported.
        do i = 1, n-1
            left = order(i); right = order(i+1)
            if (.not. supported(left) .or. .not. supported(right)) cycle
            if (local_mach(right)-local_mach(left) <= tolerance) return
        end do

        stat = query_alpha_outside
        if (.not. any(supported)) return

        exact = 0
        do i = 1, n
            if (.not. supported(i)) cycle
            if (abs(mach_query-local_mach(i)) <= tolerance) then
                if (exact /= 0) then
                    stat = query_invalid_mach_grid
                    return
                end if
                exact = i
            end if
        end do

        if (exact /= 0) then
            ! An exact sweep needs only its own alpha domain, including both endpoints.
            call evaluate_run(runs(exact), alpha_query, method, result, stat)
            if (stat /= query_ok) return
        else
            pair_count = 0
            left = 0; right = 0

            do i = 1, n-1
                j = order(i); k = order(i+1)
                if (.not. supported(j) .or. .not. supported(k)) cycle
                if (mach_query > local_mach(j) .and. mach_query < local_mach(k)) then
                    left = j; right = k; pair_count = pair_count+1
                end if
            end do

            if (pair_count > 1) then
                stat = query_invalid_mach_grid
                return
            end if

            if (pair_count == 0) then
                ! Missing alpha support inside the overall Mach extent is a domain error.
                ! Do not bridge a missing intermediate sweep with more distant runs.
                stat = query_mach_outside
                if (.not. all(supported) .and. mach_query >= means(order(1))-tolerance .and. &
                    mach_query <= means(order(n))+tolerance) stat = query_alpha_outside
                return
            end if

            call evaluate_run(runs(left), alpha_query, method, low_values, stat)

            if (stat /= query_ok) return
            call evaluate_run(runs(right), alpha_query, method, high_values, stat)

            if (stat /= query_ok) return

            do i = 1, 3
                call linear_interpolate([local_mach(left),local_mach(right)], &
                                        [low_values(i),high_values(i)],mach_query,result(i))
            end do

        end if

        stat = query_invalid_data
        if (.not. all(ieee_is_finite(result))) return
        cl = result(1); cd = result(2); cm = result(3)
        stat = query_ok

    end subroutine query_coefficients

    logical function valid_run(run) result(valid)

        type(aero_run_type), intent(in) :: run
        integer :: n

        valid = .false.

        if (.not. allocated(run%alpha) .or. .not. allocated(run%mach) .or. &
            .not. allocated(run%reynolds) .or. .not. allocated(run%cl) .or. &
            .not. allocated(run%cd) .or. .not. allocated(run%cm)) return

        n = size(run%alpha)
        if (n < 2) return

        if (size(run%mach) /= n .or. size(run%reynolds) /= n .or. &
            size(run%cl) /= n .or. size(run%cd) /= n .or. size(run%cm) /= n) return

        if (.not. all(ieee_is_finite(run%alpha)) .or. .not. all(ieee_is_finite(run%mach)) .or. &
            .not. all(ieee_is_finite(run%reynolds)) .or. .not. all(ieee_is_finite(run%cl)) .or. &
            .not. all(ieee_is_finite(run%cd)) .or. .not. all(ieee_is_finite(run%cm))) return

        if (any(run%alpha(2:) <= run%alpha(:n-1))) return
        if (any(run%mach <= 0.0_real64) .or. any(run%reynolds <= 0.0_real64)) return
        valid = .true.

    end function valid_run

    subroutine evaluate_run(run, alpha, method, values, stat)

        type(aero_run_type), intent(in) :: run
        real(real64), intent(in) :: alpha
        integer, intent(in) :: method
        real(real64), intent(out) :: values(3)
        integer, intent(out) :: stat

        stat = query_insufficient_points
        if (method == 3 .and. size(run%alpha) < 5) return

        select case(method)
        case(1)
            call linear_interpolate(run%alpha, run%cl, alpha, values(1))
            call linear_interpolate(run%alpha, run%cd, alpha, values(2))
            call linear_interpolate(run%alpha, run%cm, alpha, values(3))
        case(2)
            call pchip_interpolate(run%alpha, run%cl, alpha, values(1))
            call pchip_interpolate(run%alpha, run%cd, alpha, values(2))
            call pchip_interpolate(run%alpha, run%cm, alpha, values(3))
        case(3)
            call akima_interpolate(run%alpha, run%cl, alpha, values(1))
            call akima_interpolate(run%alpha, run%cd, alpha, values(2))
            call akima_interpolate(run%alpha, run%cm, alpha, values(3))
        end select

        stat = query_ok

    end subroutine evaluate_run

    function query_status_message(stat) result(message)

        integer, intent(in) :: stat
        character(len=:), allocatable :: message

        select case(stat)
        case(query_ok); message = 'Success'
        case(query_empty_dataset); message = 'No sweeps supplied'
        case(query_invalid_data); message = 'Invalid run arrays or nonfinite results'
        case(query_invalid_input); message = 'Query must be finite and Mach positive'
        case(query_invalid_method); message = 'Alpha method must be linear, pchip, or akima'
        case(query_alpha_outside); message = 'Alpha is outside the required sweep domain'
        case(query_mach_outside); message = 'Mach is outside the supported measured range'
        case(query_insufficient_points); message = 'Akima requires at least five points in each required sweep'
        case(query_invalid_mach_grid); message = 'Duplicate, crossing, or ambiguous Mach sweeps'
        case(query_incompatible_runs); message = 'Sweeps mix configurations or Reynolds groups'
        case default; message = 'Unknown query status'
        end select

    end function query_status_message

end module coefficient_query
