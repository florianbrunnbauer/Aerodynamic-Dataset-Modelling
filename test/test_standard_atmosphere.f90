program test_standard_atmosphere
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_is_finite, ieee_value, &
                                           ieee_quiet_nan, ieee_positive_inf, ieee_negative_inf
    use standard_atmosphere

    implicit none

    type(atmosphere_state_type) :: state, below, above
    real(real64) :: z, boundary, previous_pressure, previous_density, h, pressure_gradient
    real(real64), parameter :: radius=6356766.0_real64
    real(real64), parameter :: gradient_altitudes(3) = [5000.0_real64,15000.0_real64,25000.0_real64]
    integer :: stat, checks, i

    checks = 0
    print '(a)', ''
    print '(a)', '=== test_standard_atmosphere ==='

    ! Published USSA1976 reference values, rounded to the printed precision.
    ! Source: NASA-TM-X-74335, Table 10 (sea level), Table I pp. 55, 56, 57, 62.
    call calculate_atmosphere(0.0_real64,state,stat)
    call check(stat == atmosphere_ok,'sea-level status')
    call close_to(state%temperature,288.15_real64,1.0e-12_real64,'sea-level temperature')
    call close_to(state%pressure,101325.0_real64,1.0e-12_real64,'sea-level pressure')
    call close_to(state%density,1.2250_real64,1.0e-5_real64,'sea-level density')
    call close_to(state%speed_of_sound,340.294_real64,1.0e-5_real64,'sea-level sound speed')
    call close_to(state%dynamic_viscosity,1.7894e-5_real64,2.0e-5_real64,'sea-level viscosity')
    call check(state%geometric_altitude == 0.0_real64.and.state%geopotential_altitude == 0.0_real64,'zero heights')

    call calculate_atmosphere(5000.0_real64,state,stat)
    call check(stat == atmosphere_ok,'5 km status')
    call close_to(state%temperature,255.676_real64,5.0e-6_real64,'5 km geometric temperature')
    call close_to(state%pressure,54048.0_real64,5.0e-5_real64,'5 km geometric pressure')
    call close_to(state%density,0.73643_real64,5.0e-5_real64,'5 km geometric density')

    call calculate_atmosphere(10000.0_real64,state,stat)
    call check(stat == atmosphere_ok,'10 km status')
    call close_to(state%temperature,223.252_real64,5.0e-6_real64,'10 km geometric temperature')
    call close_to(state%pressure,26499.0_real64,5.0e-5_real64,'10 km geometric pressure')
    call close_to(state%density,0.41351_real64,5.0e-5_real64,'10 km geometric density')
    call check(state%geopotential_altitude < state%geometric_altitude,'geopotential lower than geometric')

    ! At 10 km GEOPOTENTIAL the temperature is 223.150 K, not 223.252 K.
    call calculate_atmosphere(geometric_height(10000.0_real64),state,stat)
    call close_to(state%temperature,223.15_real64,1.0e-12_real64,'10 km geopotential temperature')
    call close_to(state%pressure,26436.0_real64,5.0e-5_real64,'10 km geopotential pressure')
    call close_to(state%density,0.41271_real64,5.0e-5_real64,'10 km geopotential density')
    call close_to(state%geopotential_altitude,10000.0_real64,1.0e-12_real64,'geopotential conversion')

    call calculate_atmosphere(geometric_height(11000.0_real64),state,stat)
    call close_to(state%temperature,216.65_real64,1.0e-12_real64,'tropopause temperature')
    call close_to(state%pressure,22632.0_real64,5.0e-5_real64,'tropopause pressure')

    call calculate_atmosphere(geometric_height(15000.0_real64),state,stat)
    call close_to(state%temperature,216.65_real64,1.0e-12_real64,'isothermal layer temperature')

    call calculate_atmosphere(geometric_height(20000.0_real64),state,stat)
    call close_to(state%temperature,216.65_real64,1.0e-12_real64,'20 km geopotential temperature')
    call close_to(state%pressure,5474.9_real64,5.0e-5_real64,'20 km geopotential pressure')

    call calculate_atmosphere(geometric_height(30000.0_real64),state,stat)
    call check(stat == atmosphere_ok,'30 km geopotential is within geometric range')
    call close_to(state%temperature,226.65_real64,1.0e-12_real64,'warming layer temperature')
    call close_to(state%pressure,1171.9_real64,5.0e-5_real64,'30 km geopotential pressure')
    call close_to(state%density,0.018012_real64,5.0e-5_real64,'30 km geopotential density')

    ! Continuity at the actual GEOMETRIC locations of both layer boundaries.
    do i = 1, 2
        h = 11000.0_real64
        if (i == 2) h = 20000.0_real64
        boundary = geometric_height(h)
        call calculate_atmosphere(boundary-0.001_real64,below,stat)
        call check(stat == atmosphere_ok,'below layer boundary')
        call calculate_atmosphere(boundary+0.001_real64,above,stat)
        call check(stat == atmosphere_ok,'above layer boundary')
        call close_to(below%temperature,above%temperature,1.0e-6_real64,'continuous temperature')
        call close_to(below%pressure,above%pressure,1.0e-6_real64,'continuous pressure')
        call close_to(below%density,above%density,1.0e-6_real64,'continuous density')
        call close_to(below%speed_of_sound,above%speed_of_sound,1.0e-6_real64,'continuous sound speed')
        call close_to(below%dynamic_viscosity,above%dynamic_viscosity,1.0e-6_real64,'continuous viscosity')
    end do

    ! Physically sensible properties throughout the implemented domain.
    previous_pressure = huge(1.0_real64)
    previous_density = huge(1.0_real64)

    do i = 0, 32
        z = 1000.0_real64*real(i,real64)
        call calculate_atmosphere(z,state,stat)
        call check(stat == atmosphere_ok,'grid status')
        call check(all(ieee_is_finite(properties(state))).and.all(properties(state)>0.0_real64),'positive finite properties')
        call check(state%pressure < previous_pressure,'pressure decreases with altitude')
        call check(state%density < previous_density,'density decreases with altitude')
        previous_pressure = state%pressure
        previous_density = state%density
    end do

    call check(state%geometric_altitude == atmosphere_max_altitude,'upper endpoint accepted')

    ! Hydrostatic pressure gradient in geometric coordinates:
    ! dp/dz = -rho * g0 * (r/(r+z))^2, independently checks the height conversion.
    do i = 1, 3
        z = gradient_altitudes(i)
        call calculate_atmosphere(z,state,stat)
        call calculate_atmosphere(z-1.0_real64,below,stat)
        call calculate_atmosphere(z+1.0_real64,above,stat)
        pressure_gradient = (above%pressure-below%pressure)/2.0_real64
        call close_to(pressure_gradient,-state%density*9.80665_real64*(radius/(radius+z))**2, &
                      1.0e-7_real64,'hydrostatic pressure gradient')
    end do

    call calculate_atmosphere(-0.001_real64,state,stat)
    call rejected(atmosphere_outside_range)

    call calculate_atmosphere(atmosphere_max_altitude+0.001_real64,state,stat)
    call rejected(atmosphere_outside_range)

    call calculate_atmosphere(huge(1.0_real64),state,stat)
    call rejected(atmosphere_outside_range)

    call calculate_atmosphere(ieee_value(0.0_real64,ieee_quiet_nan),state,stat)
    call rejected(atmosphere_invalid_altitude)

    call calculate_atmosphere(ieee_value(0.0_real64,ieee_positive_inf),state,stat)
    call rejected(atmosphere_invalid_altitude)

    call calculate_atmosphere(ieee_value(0.0_real64,ieee_negative_inf),state,stat)
    call rejected(atmosphere_invalid_altitude)

    call calculate_atmosphere(0.0_real64,state,stat)
    call check(stat == atmosphere_ok,'valid call after rejected input')

    print '(a,i0,a)', 'PASS: ',checks,' assertions'

contains

    pure function geometric_height(geopotential_height) result(geometric)

        real(real64),intent(in) :: geopotential_height
        real(real64) :: geometric

        geometric = radius*geopotential_height/(radius-geopotential_height)

    end function

    pure function properties(s) result(values)

        type(atmosphere_state_type),intent(in) :: s
        real(real64) :: values(5)

        values = [s%temperature,s%pressure,s%density,s%speed_of_sound,s%dynamic_viscosity]

    end function

    subroutine check(condition,label)

        logical,intent(in) :: condition
        character(len=*),intent(in) :: label

        checks = checks+1
        if (.not. condition) then
            print '(a)', 'FAIL: '//label
            error stop 1
        end if

    end subroutine

    subroutine close_to(actual,target,relative_tolerance,label)

        real(real64),intent(in) :: actual,target,relative_tolerance
        character(len=*),intent(in) :: label

        if (.not. (abs(actual-target)<=relative_tolerance*abs(target))) then
            print '(a,2(1x,es24.16))', 'FAIL: '//label//' actual/expected:',actual,target
            error stop 1
        end if

        checks = checks+1

    end subroutine

    subroutine rejected(expected_status)

        integer,intent(in) :: expected_status

        call check(stat == expected_status,'rejection status')
        call check(all(ieee_is_nan(properties(state))).and.ieee_is_nan(state%geometric_altitude).and. &
                   ieee_is_nan(state%geopotential_altitude),'all rejected outputs are NaNs')

    end subroutine
    
end program test_standard_atmosphere
