module coefficient_query
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
    use types, only: aero_dataset_type, aero_run_type, representative_dataset_type
    use linear_interpolation, only: linear_interpolate
    use pchip_interpolation, only: pchip_interpolate
    use akima_interpolation, only: akima_interpolate
    implicit none
    private
    public :: query_coefficients, query_status_message

    integer, parameter, public :: query_ok=0, query_empty_dataset=1, query_invalid_structure=2
    integer, parameter, public :: query_invalid_input=3, query_invalid_method=4
    integer, parameter, public :: query_alpha_outside=5, query_mach_outside=6
    integer, parameter, public :: query_insufficient_points=7, query_invalid_mach_grid=8
    integer, parameter, public :: query_invalid_reynolds_group=9, query_nonfinite_result=10

contains

    ! Pipeline contract:
    !   data has passed configuration selection and validate_dataset;
    !   structure was built by group_dataset/build_representative_dataset
    !   from THIS data, whose run ordering has not subsequently changed.
    ! Array allocation/sizes/finiteness, alpha order, configuration and Reynolds
    ! classification are upstream responsibilities and are not rescanned here.
    !
    ! reynolds_group_index is a 1-based position in structure%reynolds_groups.
    ! There is no interpolation between Reynolds groups and no flight-Re policy here.
    ! Alpha [degrees]; Mach dimensionless; never extrapolate in either coordinate.
    ! Measured Mach(alpha) is the default, matching the original validator. Nominal
    ! Mach labels establish sweep order only; they are NOT interpolation coordinates.
    ! use_mean_mach=.true. retains the optional measured sweep-mean coordinate mode.
    ! Only representative runs in the selected Reynolds group are accessed.
    ! Sweeps lacking the requested alpha are skipped: interpolation uses the
    ! nearest supported Mach coordinate on each side, including across gaps.
    ! On every failure, all three returned coefficients remain quiet NaNs.
    subroutine query_coefficients(data, structure, reynolds_group_index, alpha_query, mach_query, &
                                  cl, cd, cm, stat, alpha_method, use_mean_mach)

        type(aero_dataset_type), intent(in) :: data
        type(representative_dataset_type), intent(in) :: structure
        integer, intent(in) :: reynolds_group_index
        real(real64), intent(in) :: alpha_query, mach_query

        real(real64), intent(out) :: cl, cd, cm
        integer, intent(out) :: stat

        character(len=*), intent(in), optional :: alpha_method
        logical, intent(in), optional :: use_mean_mach

        real(real64), allocatable :: nominal(:), coordinates(:)
        integer, allocatable :: run_indices(:), order(:)
        logical, allocatable :: supported(:)
        real(real64) :: nan, tolerance, low_values(3), high_values(3), result(3), lower_bound, upper_bound
        integer :: i, j, k, n, group, method, left, right, swap, exact, run_index
        logical :: mean_mode

        nan = ieee_value(0.0_real64, ieee_quiet_nan)
        cl = nan; cd = nan; cm = nan
        stat = query_invalid_input

        if (.not. ieee_is_finite(alpha_query) .or. .not. ieee_is_finite(mach_query)) return

        if (mach_query <= 0.0_real64) return

        method = 3

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

        ! Small interface guards protect references; no full run-data validation.
        stat = query_empty_dataset

        if (.not. allocated(data%runs)) return

        if (size(data%runs) == 0) return

        if (.not. allocated(structure%reynolds_groups)) return

        if (size(structure%reynolds_groups) == 0) return

        stat = query_invalid_reynolds_group

        group = reynolds_group_index

        if (group < 1 .or. group > size(structure%reynolds_groups)) return

        stat = query_empty_dataset

        if (.not. allocated(structure%reynolds_groups(group)%mach_groups)) return

        n = size(structure%reynolds_groups(group)%mach_groups)

        if (n == 0) return

        allocate(nominal(n), coordinates(n), run_indices(n), order(n), supported(n))

        supported = .false.
        coordinates = nan

        do i = 1, n
            run_index = structure%reynolds_groups(group)%mach_groups(i)%run_index
            stat = query_invalid_structure

            if (run_index < 1 .or. run_index > size(data%runs)) return

            run_indices(i) = run_index
            nominal(i) = structure%reynolds_groups(group)%mach_groups(i)%nominal_mach
            order(i) = i
        end do

        ! Group builders preserve insertion order. Sort local indices by the
        ! prepared nominal labels without reordering data or changing its indices.
        do i = 2, n
            j = i
            do while (j > 1)
                if (nominal(order(j)) >= nominal(order(j-1))) exit
                swap = order(j-1); order(j-1) = order(j); order(j) = swap
                j = j-1
            end do
        end do

        do i = 1, n
            run_index = run_indices(i)

            associate(run => data%runs(run_index))

                if (alpha_query < run%alpha(1) .or. alpha_query > run%alpha(size(run%alpha))) cycle

                supported(i) = .true.

                if (mean_mode) then
                    coordinates(i) = sum(run%mach/real(size(run%mach), real64))
                else
                    ! Mach-coordinate interpolation always stays linear in alpha.
                    call linear_interpolate(run%alpha, run%mach, alpha_query, coordinates(i))
                end if

            end associate

            stat = query_invalid_mach_grid

            if (.not. ieee_is_finite(coordinates(i))) return

            if (coordinates(i) <= 0.0_real64) return

        end do

        stat = query_alpha_outside

        if (.not. any(supported)) return

        tolerance = 64.0_real64*epsilon(1.0_real64)*max(1.0_real64, abs(mach_query), &
            maxval(abs(coordinates), mask=supported))

        ! Mean-Mach grouping does not guarantee measured Mach(alpha) order.
        ! Compare successive SUPPORTED sweeps, including across unsupported gaps.
        stat = query_invalid_mach_grid
        k = 0

        do i = 1, n
            j = order(i)

            if (.not. supported(j)) cycle

            if (k /= 0) then
                if (coordinates(j)-coordinates(k) <= tolerance) return
            end if

            k = j
        end do

        exact = 0
        do i = 1, n

            if (.not. supported(i)) cycle

            if (abs(mach_query-coordinates(i)) <= tolerance) then
                if (exact /= 0) return
                exact = i
            end if

        end do

        if (exact /= 0) then
            ! An exact sweep needs only its own alpha coverage and method support.
            call evaluate_run(data%runs(run_indices(exact)), alpha_query, method, result, stat)

            if (stat /= query_ok) return

        else
            left = 0; right = 0
            ! Supported coordinates are strictly increasing after the check above.
            ! The last lower and first upper coordinate form the nearest bracket.
            do i = 1, n

                j = order(i)

                if (.not. supported(j)) cycle

                if (coordinates(j) < mach_query) then
                    left = j
                else if (coordinates(j) > mach_query) then
                    right = j
                    exit
                end if

            end do

            if (left == 0 .or. right == 0) then
                stat = query_mach_outside
                ! Coordinates are undefined where alpha is unsupported. Nominal
                ! outer labels serve only as a fallback for rejection diagnostics.
                lower_bound = nominal(order(1))
                upper_bound = nominal(order(n))
                if (supported(order(1))) lower_bound = coordinates(order(1))
                if (supported(order(n))) upper_bound = coordinates(order(n))
                if (.not. all(supported) .and. mach_query >= lower_bound-tolerance .and. &
                    mach_query <= upper_bound+tolerance) stat = query_alpha_outside
                ! A supported sweep is required on BOTH sides; never extrapolate.
                return
            end if

            call evaluate_run(data%runs(run_indices(left)), alpha_query, method, low_values, stat)

            if (stat /= query_ok) return

            call evaluate_run(data%runs(run_indices(right)), alpha_query, method, high_values, stat)

            if (stat /= query_ok) return

            do i = 1, 3
                call linear_interpolate([coordinates(left), coordinates(right)], &
                    [low_values(i), high_values(i)], mach_query, result(i))
            end do

        end if

        stat = query_nonfinite_result

        if (.not. all(ieee_is_finite(result))) return

        cl = result(1); cd = result(2); cm = result(3)

        stat = query_ok

    end subroutine query_coefficients

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
        case(query_empty_dataset); message = 'No prepared data or representative Mach sweeps supplied'
        case(query_invalid_structure); message = 'Representative run index is outside data%runs'
        case(query_invalid_input); message = 'Query must be finite and Mach positive'
        case(query_invalid_method); message = 'Alpha method must be linear, pchip, or akima'
        case(query_alpha_outside); message = 'Alpha is outside the required representative sweep domain'
        case(query_mach_outside); message = 'Mach is outside the supported measured range'
        case(query_insufficient_points); message = 'Akima requires at least five points in each required sweep'
        case(query_invalid_mach_grid); message = 'Invalid, duplicate, crossing, or ambiguous local Mach coordinates'
        case(query_invalid_reynolds_group); message = 'Reynolds group index is outside structure%reynolds_groups'
        case(query_nonfinite_result); message = 'Interpolation produced nonfinite coefficients'
        case default; message = 'Unknown query status'
        end select
        
    end function query_status_message

end module coefficient_query
