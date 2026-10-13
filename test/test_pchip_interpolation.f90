program test_pchip_interpolation
    use iso_fortran_env, only: real64, error_unit
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
    use pchip_interpolation, only: pchip_interpolate
    implicit none
    real(real64), parameter :: tolerance = 1.0e-12_real64
    real(real64), parameter :: x(6) = [0.0_real64, 0.6_real64, 1.5_real64, &
                                      2.0_real64, 3.8_real64, 5.0_real64]
    real(real64), parameter :: y(6) = [0.0_real64, 1.0_real64, 1.5_real64, &
                                      1.4_real64, 2.0_real64, 1.8_real64]
    real(real64), parameter :: queries(5) = [0.2_real64, 0.9_real64, 1.8_real64, &
                                            2.7_real64, 4.6_real64]
    ! Fixed reference values from SciPy 1.17.0 PchipInterpolator.
    ! SciPy/Python are NOT dependencies for running these Fortran tests.
    real(real64), parameter :: expected(5) = [ &
        0.40859940400170286_real64, &
        1.244572158365262_real64, &
        1.4352_real64, &
        1.6016460905349796_real64, &
        1.9170370370370373_real64 ]
    real(real64) :: result, q
    character(len=40) :: mode
    integer :: i, j, checks

    ! A child invocation exercises one expected ERROR STOP in isolation.
    if (command_argument_count() > 0) then
        call get_command_argument(1, mode)
        call invalid_case(trim(mode))
        stop 0  ! Reaching here means the module accepted invalid input.
    end if

    checks = 0
    print '(a)', ''
    print '(a)', '=== test_pchip_interpolation ==='

    do i = 1, size(x)
        call pchip_interpolate(x, y, x(i), result)
        call assert_close(result, y(i), 'exact knot including endpoints')
    end do

    do i = 0, 40
        q = x(1)+(x(size(x))-x(1))*real(i, real64)/40.0_real64
        call pchip_interpolate(x, 2.0_real64*x-3.0_real64, q, result)
        call assert_close(result, 2.0_real64*q-3.0_real64, 'straight line on uneven grid')
        call pchip_interpolate(x, -2.5_real64+0.0_real64*x, q, result)
        call assert_close(result, -2.5_real64, 'constant data / zero slope weights')
    end do

    do i = 1, size(queries)
        call pchip_interpolate(x, y, queries(i), result)
        call assert_close(result, expected(i), 'nonlinear reference on uneven grid')
    end do

    ! Minimum accepted input: two points reduce to a straight line.
    call pchip_interpolate([0.0_real64, 2.0_real64], [1.0_real64, 5.0_real64], 0.5_real64, result)
    call assert_close(result, 2.0_real64, 'two-point fallback')

    ! Three-point endpoint rules: suppress wrong sign and cap steep slope.
    call pchip_interpolate([0.0_real64, 1.0_real64, 2.0_real64], &
                          [0.0_real64, 1.0_real64, 10.0_real64], 0.25_real64, result)
    call assert_close(result, 0.071875_real64, 'left endpoint sign limiter')
    call pchip_interpolate([0.0_real64, 1.0_real64, 2.0_real64], &
                          [0.0_real64, 1.0_real64, 10.0_real64], 1.75_real64, result)
    call assert_close(result, 6.85_real64, 'right endpoint estimate')
    call pchip_interpolate([0.0_real64, 1.0_real64, 2.0_real64], &
                          [0.0_real64, 1.0_real64, -10.0_real64], 0.25_real64, result)
    call assert_close(result, 0.578125_real64, 'endpoint three-slope cap')
    call pchip_interpolate([0.0_real64, 1.0_real64, 2.0_real64], &
                          [0.0_real64, 1.0_real64, -10.0_real64], 1.75_real64, result)
    call assert_close(result, -5.890625_real64, 'right endpoint with sign change')

    ! On each segment of the nonlinear curve, PCHIP must stay inside
    ! its endpoint values, including the intervals around local extrema.
    do i = 1, size(x)-1
        do j = 0, 20
            q = x(i)+(x(i+1)-x(i))*real(j, real64)/20.0_real64
            call pchip_interpolate(x, y, q, result)
            call assert_true(result >= min(y(i),y(i+1))-tolerance .and. &
                             result <= max(y(i),y(i+1))+tolerance, 'no segment overshoot')
        end do
    end do
    call check_monotonicity()

    call expect_rejection('empty', 'at least 2 points required.')
    call expect_rejection('too_few', 'at least 2 points required.')
    call expect_rejection('mismatch', 'array sizes must match.')
    call expect_rejection('descending', 'x must be strictly increasing.')
    call expect_rejection('duplicate', 'x must be strictly increasing.')
    call expect_rejection('below', 'query outside data range.')
    call expect_rejection('above', 'query outside data range.')
    call expect_rejection('nan_x', 'x must be finite.')
    call expect_rejection('nan_y', 'y must be finite.')
    call expect_rejection('nan_query', 'query must be finite.')
    call expect_rejection('inf_x', 'x must be finite.')
    call expect_rejection('inf_y', 'y must be finite.')
    call expect_rejection('inf_query', 'query must be finite.')

    print '(a,i0,a)', 'PASS: ', checks, ' assertions'

contains

    subroutine assert_true(condition, label)
        logical, intent(in) :: condition
        character(len=*), intent(in) :: label
        checks = checks+1
        if (.not. condition) then
            write(error_unit, '(a)') 'FAIL: '//label
            error stop 1
        end if
    end subroutine assert_true

    subroutine assert_close(actual, target, label)
        real(real64), intent(in) :: actual, target
        character(len=*), intent(in) :: label
        ! NaNs also fail because the comparison is false.
        if (.not. (abs(actual-target) <= tolerance*max(1.0_real64, abs(target)))) then
            write(error_unit, '(a,2(1x,es24.16))') 'FAIL: '//label//' actual/expected:', actual, target
            error stop 1
        end if
        checks = checks+1
    end subroutine assert_close

    subroutine expect_rejection(case_name, expected_message)
        character(len=*), intent(in) :: case_name, expected_message
        character(len=:), allocatable :: executable
        character(len=512) :: command_message, line
        character(len=*), parameter :: log_name = 'test_pchip_rejection.log'
        integer :: length, unit, ios, command_status, exit_status
        logical :: found_message

        call get_command_argument(0, length=length)
        allocate(character(len=length) :: executable)
        call get_command_argument(0, executable)
        ! Quote the executable so absolute paths containing spaces work.
        call assert_true(index(executable, '"') == 0, 'executable path contains no double quote')
        command_status = -1
        exit_status = -1
        call execute_command_line('"'//executable//'" '//case_name//' > '//log_name//' 2>&1', &
                                  wait=.true., exitstat=exit_status, cmdstat=command_status, &
                                  cmdmsg=command_message)
        if (command_status /= 0) write(error_unit, '(a)') trim(command_message)
        call assert_true(command_status == 0, 'launch rejection case '//case_name)
        call assert_true(exit_status /= 0, 'nonzero exit for '//case_name)
        found_message = .false.
        open(newunit=unit, file=log_name, status='old', action='read', iostat=ios)
        call assert_true(ios == 0, 'open rejection log')
        do
            read(unit, '(a)', iostat=ios) line
            if (ios /= 0) exit
            if (index(line, 'PCHIP: '//expected_message) > 0) found_message = .true.
        end do
        close(unit, status='delete')
        call assert_true(found_message, 'expected diagnostic for '//case_name)
    end subroutine expect_rejection

    subroutine invalid_case(case_name)
        character(len=*), intent(in) :: case_name
        real(real64) :: bad_x(6), bad_y(6), query, value
        bad_x = x
        bad_y = y
        query = 1.0_real64
        select case(case_name)
        case('empty')
            call pchip_interpolate(x(:0), y(:0), query, value)
            return
        case('too_few')
            call pchip_interpolate(x(:1), y(:1), query, value)
            return
        case('mismatch')
            call pchip_interpolate(x, y(:5), query, value)
            return
        case('descending')
            bad_x = x(6:1:-1)
        case('duplicate')
            bad_x(3) = bad_x(2)
        case('below')
            query = -0.1_real64
        case('above')
            query = 5.1_real64
        case('nan_x')
            bad_x(3) = ieee_value(0.0_real64, ieee_quiet_nan)
        case('nan_y')
            bad_y(3) = ieee_value(0.0_real64, ieee_quiet_nan)
        case('nan_query')
            query = ieee_value(0.0_real64, ieee_quiet_nan)
        case('inf_x')
            bad_x(6) = ieee_value(0.0_real64, ieee_positive_inf)
        case('inf_y')
            bad_y(3) = ieee_value(0.0_real64, ieee_positive_inf)
        case('inf_query')
            query = ieee_value(0.0_real64, ieee_positive_inf)
        case default
            write(error_unit, '(a)') 'Unknown rejection case: '//case_name
            error stop 1
        end select
        call pchip_interpolate(bad_x, bad_y, query, value)
    end subroutine invalid_case

    subroutine check_monotonicity()
        real(real64), parameter :: values(6) = [0.0_real64, 0.1_real64, 0.1_real64, &
                                                2.0_real64, 2.1_real64, 5.0_real64]
        real(real64) :: previous, current, point
        integer :: k, direction
        do direction = -1, 1, 2
            previous = real(direction, real64)*values(1)
            do k = 1, 200
                point = x(1)+(x(6)-x(1))*real(k, real64)/200.0_real64
                call pchip_interpolate(x, real(direction, real64)*values, point, current)
                call assert_true(real(direction, real64)*(current-previous) >= -tolerance, &
                                 'monotonicity with plateau, both directions')
                previous = current
            end do
        end do
    end subroutine check_monotonicity

end program test_pchip_interpolation
