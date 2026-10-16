module standard_atmosphere
    use iso_fortran_env, only: real64
    use types, only: atmosphere_state_type
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan

    implicit none

    private

    public :: atmosphere_state_type, calculate_atmosphere, atmosphere_status_message

    integer, parameter, public :: atmosphere_ok=0, atmosphere_invalid_altitude=1, atmosphere_outside_range=2
    real(real64), parameter, public :: atmosphere_min_altitude=0.0_real64
    real(real64), parameter, public :: atmosphere_max_altitude=32000.0_real64

    ! U.S. Standard Atmosphere 1976, dry air, restricted to 0--32 km GEOMETRIC altitude.
    ! Source: NASA-TM-X-74335, Part 1: constants, layer equations, viscosity law.
    real(real64), parameter :: earth_radius=6356766.0_real64       ! effective radius [m]
    real(real64), parameter :: gravity=9.80665_real64              ! standard gravity [m/s^2]
    real(real64), parameter :: gas_constant=8314.32_real64/28.9644_real64 ! [J/(kg K)]
    real(real64), parameter :: gamma=1.4_real64
    real(real64), parameter :: sea_temperature=288.15_real64       ! [K]
    real(real64), parameter :: sea_pressure=101325.0_real64        ! [Pa]
    real(real64), parameter :: lapse_troposphere=-0.0065_real64     ! [K/m geopotential]
    real(real64), parameter :: lapse_stratosphere=0.001_real64
    real(real64), parameter :: tropopause=11000.0_real64           ! geopotential [m]
    real(real64), parameter :: stratosphere_base=20000.0_real64
    real(real64), parameter :: temperature_11=sea_temperature+lapse_troposphere*tropopause
    real(real64), parameter :: pressure_11=sea_pressure*(temperature_11/sea_temperature)** &
                                                (-gravity/(gas_constant*lapse_troposphere))
    real(real64), parameter :: pressure_20=pressure_11*exp(-gravity*(stratosphere_base-tropopause)/ &
                                                        (gas_constant*temperature_11))
    real(real64), parameter :: sutherland_beta=1.458e-6_real64      ! [kg/(m s sqrt(K))]
    real(real64), parameter :: sutherland_temperature=110.4_real64 ! [K]

    ! Shared type is defined in types.f90 and re-exported here for existing callers.

contains

    pure subroutine calculate_atmosphere(altitude, state, stat)

        real(real64), intent(in) :: altitude

        type(atmosphere_state_type), intent(out) :: state
        integer, intent(out) :: stat

        real(real64) :: h, temperature, pressure, nan

        nan = ieee_value(0.0_real64,ieee_quiet_nan)

        state%geometric_altitude = nan
        state%geopotential_altitude = nan
        state%temperature = nan
        state%pressure = nan
        state%density = nan
        state%speed_of_sound = nan
        state%dynamic_viscosity = nan

        stat = atmosphere_invalid_altitude

        if (.not. ieee_is_finite(altitude)) return

        stat = atmosphere_outside_range

        if (altitude < atmosphere_min_altitude .or. altitude > atmosphere_max_altitude) return

        ! Convert the geometric input z to geopotential height H.
        h = earth_radius*altitude/(earth_radius+altitude)

        if (h < tropopause) then
            temperature = sea_temperature+lapse_troposphere*h
            pressure = sea_pressure*(temperature/sea_temperature)**(-gravity/(gas_constant*lapse_troposphere))
        else if (h < stratosphere_base) then
            temperature = temperature_11
            pressure = pressure_11*exp(-gravity*(h-tropopause)/(gas_constant*temperature))
        else
            temperature = temperature_11+lapse_stratosphere*(h-stratosphere_base)
            pressure = pressure_20*(temperature/temperature_11)**(-gravity/(gas_constant*lapse_stratosphere))
        end if

        state%geometric_altitude = altitude
        state%geopotential_altitude = h
        state%temperature = temperature
        state%pressure = pressure
        state%density = pressure/(gas_constant*temperature)
        state%speed_of_sound = sqrt(gamma*gas_constant*temperature)
        state%dynamic_viscosity = sutherland_beta*temperature**1.5_real64/(temperature+sutherland_temperature)

        stat = atmosphere_ok

    end subroutine calculate_atmosphere

    function atmosphere_status_message(stat) result(message)

        integer, intent(in) :: stat

        character(len=:), allocatable :: message

        select case(stat)
        case(atmosphere_ok); message = 'Success'
        case(atmosphere_invalid_altitude); message = 'Altitude must be finite'
        case(atmosphere_outside_range); message = 'Geometric altitude must be between 0 and 32000 m'
        case default; message = 'Unknown atmosphere status'
        end select

    end function atmosphere_status_message
    
end module standard_atmosphere
