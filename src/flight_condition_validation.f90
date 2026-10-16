module flight_condition_validation
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_is_finite
    use types, only: aero_dataset_type, representative_dataset_type, flight_condition_type, atmosphere_state_type
    use standard_atmosphere, only: calculate_atmosphere, atmosphere_ok, &
                                   atmosphere_min_altitude, atmosphere_max_altitude
    use aerodynamic_properties, only: calculate_dynamic_pressure, properties_ok
    use coefficient_query, only: query_coefficients, query_ok

    implicit none

    private
    public :: flight_condition_type, validate_flight_condition, find_reynolds_matched_altitude
    public :: flight_status_message

    integer, parameter, public :: flight_ok=0, flight_invalid_input=1, flight_atmosphere_failure=2
    integer, parameter, public :: flight_numeric_failure=3, flight_invalid_dataset=4
    integer, parameter, public :: flight_reynolds_mismatch=6
    integer, parameter, public :: flight_coefficient_failure=7, flight_no_matching_altitude=8
    integer, parameter, public :: flight_solver_failure=9, flight_not_evaluated=-1
    integer, parameter, public :: flight_invalid_reynolds_group=10, flight_invalid_structure=11

contains

    ! Preconditions: data passed selection/validation, and structure was built
    ! from that data by grouping/representative selection. Keep data%runs order.
    ! Do not revalidate arrays, configuration, or Reynolds classification here.
    ! The selected group's nominal Reynolds number is the acceptance target;
    ! callers no longer supply a separate, potentially inconsistent nominal Re.
    ! observed_reynolds_min/max describe the selected REPRESENTATIVE sweeps only.
    ! reynolds_tolerance is a relative fraction in [0,1), explicitly chosen by
    ! the caller. Acceptance is a policy result, not a validated accuracy claim.
    ! Gap interpolation and measured Mach(alpha) behavior come from query v2.
    subroutine validate_flight_condition(data, structure, reynolds_group_index, altitude, mach, alpha, reference_length, &
                                         reynolds_tolerance, condition, stat, alpha_method, use_mean_mach)

        type(aero_dataset_type), intent(in) :: data
        type(representative_dataset_type), intent(in) :: structure
        integer, intent(in) :: reynolds_group_index
        real(real64), intent(in) :: altitude, mach, alpha, reference_length, reynolds_tolerance

        type(flight_condition_type), intent(out) :: condition
        integer, intent(out) :: stat

        character(len=*), intent(in), optional :: alpha_method
        logical, intent(in), optional :: use_mean_mach

        real(real64) :: nan, nominal_reynolds, allowance, denominator
        integer :: i, group, run_index, physics_stat

        nan = ieee_value(0.0_real64,ieee_quiet_nan)

        call initialize_condition(condition,nan)

        stat = flight_invalid_input

        if (.not. all(ieee_is_finite([altitude,mach,alpha,reference_length,reynolds_tolerance]))) return
        if (mach <= 0.0_real64 .or. reference_length <= 0.0_real64) return
        if (reynolds_tolerance < 0.0_real64 .or. reynolds_tolerance >= 1.0_real64) return

        condition%alpha = alpha
        condition%mach = mach
        condition%reference_length = reference_length
        condition%reynolds_tolerance = reynolds_tolerance

        ! Small reference guards; no scans to revalidate prepared measurements.
        stat = flight_invalid_dataset

        if (.not. allocated(data%runs)) return
        if (size(data%runs) == 0) return
        if (.not. allocated(structure%reynolds_groups)) return
        if (size(structure%reynolds_groups) == 0) return

        stat = flight_invalid_reynolds_group

        group = reynolds_group_index

        if (group < 1 .or. group > size(structure%reynolds_groups)) return

        stat = flight_invalid_dataset

        if (.not. allocated(structure%reynolds_groups(group)%mach_groups)) return
        if (size(structure%reynolds_groups(group)%mach_groups) == 0) return

        nominal_reynolds = structure%reynolds_groups(group)%nominal_reynolds

        stat = flight_invalid_structure

        if (.not. ieee_is_finite(nominal_reynolds)) return
        if (nominal_reynolds <= 0.0_real64) return

        condition%nominal_reynolds = nominal_reynolds

        do i = 1, size(structure%reynolds_groups(group)%mach_groups)

            run_index = structure%reynolds_groups(group)%mach_groups(i)%run_index

            if (run_index < 1 .or. run_index > size(data%runs)) return

            ! Extrema are diagnostic calculations, not data-validation checks.
            if (i == 1) then
                condition%observed_reynolds_min = minval(data%runs(run_index)%reynolds)
                condition%observed_reynolds_max = maxval(data%runs(run_index)%reynolds)
            else
                condition%observed_reynolds_min = min(condition%observed_reynolds_min, &
                                                       minval(data%runs(run_index)%reynolds))
                condition%observed_reynolds_max = max(condition%observed_reynolds_max, &
                                                       maxval(data%runs(run_index)%reynolds))
            end if
        end do

        call physics_at_altitude(altitude,mach,reference_length,condition%air,condition%speed, &
                                 condition%dynamic_pressure,condition%reynolds,physics_stat,condition%atmosphere_stat)

        stat = physics_stat

        if (stat /= flight_ok) return

        ! Avoid overflow when expressing a relative mismatch for extreme finite inputs.
        stat = flight_numeric_failure

        if (nominal_reynolds < 1.0_real64) then
            if (abs(condition%reynolds-nominal_reynolds) > huge(1.0_real64)*nominal_reynolds) return
        end if

        condition%relative_reynolds_mismatch = abs(condition%reynolds-nominal_reynolds)/nominal_reynolds

        stat = flight_reynolds_mismatch

        ! Machine-roundoff allowance is not an aerodynamic Reynolds tolerance.
        denominator = max(condition%reynolds,nominal_reynolds)

        allowance = 64.0_real64*epsilon(1.0_real64)*denominator

        if (abs(condition%reynolds-nominal_reynolds) > reynolds_tolerance*nominal_reynolds+allowance) return

        call query_coefficients(data,structure,group,alpha,mach,condition%cl,condition%cd,condition%cm, &
                                condition%coefficient_stat,alpha_method,use_mean_mach)

        stat = flight_coefficient_failure

        if (condition%coefficient_stat /= query_ok) return

        condition%accepted = .true.

        stat = flight_ok

    end subroutine

    ! Bisection on Re(z); Re decreases over the implemented standard-atmosphere
    ! domain at fixed Mach and reference length. This does not check dataset support.
    subroutine find_reynolds_matched_altitude(mach, reference_length, target_reynolds, altitude, stat, &
                                              altitude_tolerance)
        real(real64), intent(in) :: mach, reference_length, target_reynolds

        real(real64), intent(out) :: altitude
        integer, intent(out) :: stat

        real(real64), intent(in), optional :: altitude_tolerance ! m; bracket-width criterion

        type(atmosphere_state_type) :: air
        real(real64) :: low, high, middle, low_re, high_re, middle_re, speed, q, tolerance
        integer :: iteration, atmos_stat, physics_stat

        altitude = ieee_value(0.0_real64,ieee_quiet_nan)

        stat = flight_invalid_input

        if (.not. all(ieee_is_finite([mach,reference_length,target_reynolds]))) return
        if (mach <= 0.0_real64 .or. reference_length <= 0.0_real64 .or. target_reynolds <= 0.0_real64) return

        tolerance = 0.01_real64

        if (present(altitude_tolerance)) tolerance = altitude_tolerance
        if (.not. ieee_is_finite(tolerance)) return
        if (tolerance <= 0.0_real64 .or. tolerance > atmosphere_max_altitude-atmosphere_min_altitude) return

        low = atmosphere_min_altitude
        high = atmosphere_max_altitude

        call physics_at_altitude(low,mach,reference_length,air,speed,q,low_re,physics_stat,atmos_stat)

        stat = physics_stat

        if (stat /= flight_ok) return

        call physics_at_altitude(high,mach,reference_length,air,speed,q,high_re,physics_stat,atmos_stat)

        stat = physics_stat

        if (stat /= flight_ok) return

        stat = flight_no_matching_altitude

        if (target_reynolds > low_re .or. target_reynolds < high_re) return

        if (target_reynolds == low_re) then
            altitude = low
            stat = flight_ok
            return
        else if (target_reynolds == high_re) then
            altitude = high
            stat = flight_ok
            return
        end if

        do iteration = 1, 100

            middle = low+(high-low)/2.0_real64

            if (high-low <= tolerance) then
                altitude = middle
                stat = flight_ok
                return
            end if

            ! Detect requested precision finer than representable altitude spacing.
            if (middle == low .or. middle == high) exit

            call physics_at_altitude(middle,mach,reference_length,air,speed,q,middle_re,physics_stat,atmos_stat)

            stat = physics_stat

            if (stat /= flight_ok) return

            if (middle_re == target_reynolds) then
                altitude = middle
                stat = flight_ok
                return
            else if (middle_re > target_reynolds) then
                low = middle
            else
                high = middle
            end if

        end do

        stat = flight_solver_failure

    end subroutine

    subroutine physics_at_altitude(altitude,mach,length,air,speed,q,reynolds,stat,atmos_stat)

        real(real64), intent(in) :: altitude,mach,length

        type(atmosphere_state_type), intent(out) :: air
        real(real64), intent(out) :: speed,q,reynolds
        integer, intent(out) :: stat,atmos_stat

        real(real64) :: nan, log_re
        integer :: pressure_stat

        nan = ieee_value(0.0_real64,ieee_quiet_nan)
        speed = nan; q = nan; reynolds = nan

        call calculate_atmosphere(altitude,air,atmos_stat)

        stat = flight_atmosphere_failure

        if (atmos_stat /= atmosphere_ok) return

        stat = flight_numeric_failure

        if (mach > huge(speed)/air%speed_of_sound) return

        speed = mach*air%speed_of_sound

        if (speed <= 0.0_real64 .or. .not. ieee_is_finite(speed)) return

        call calculate_dynamic_pressure(air%density,speed,q,pressure_stat)

        if (pressure_stat /= properties_ok) return

        log_re = log(air%density)+log(speed)+log(length)-log(air%dynamic_viscosity)

        if (log_re >= log(huge(reynolds)) .or. log_re <= log(tiny(reynolds))) return

        ! Log-domain evaluation avoids unsafe intermediate products/divisions.
        reynolds = exp(log_re)

        if (.not. ieee_is_finite(reynolds) .or. reynolds <= 0.0_real64) return

        stat = flight_ok

    end subroutine

    subroutine initialize_condition(c,nan)

        type(flight_condition_type), intent(out) :: c

        real(real64), intent(in) :: nan

        c%accepted = .false.
        c%atmosphere_stat = flight_not_evaluated
        c%coefficient_stat = flight_not_evaluated
        c%alpha = nan; c%mach = nan; c%reference_length = nan
        c%nominal_reynolds = nan; c%reynolds_tolerance = nan
        c%speed = nan; c%dynamic_pressure = nan; c%reynolds = nan; c%relative_reynolds_mismatch = nan
        c%observed_reynolds_min = nan; c%observed_reynolds_max = nan
        c%cl = nan; c%cd = nan; c%cm = nan
        c%air%geometric_altitude = nan; c%air%geopotential_altitude = nan
        c%air%temperature = nan; c%air%pressure = nan; c%air%density = nan
        c%air%speed_of_sound = nan; c%air%dynamic_viscosity = nan

    end subroutine

    function flight_status_message(stat) result(message)

        integer, intent(in) :: stat

        character(len=:), allocatable :: message

        select case(stat)
        case(flight_ok); message='Accepted under the specified policy'
        case(flight_invalid_input); message='Invalid flight condition, reference length, target Re, or tolerance'
        case(flight_atmosphere_failure); message='Altitude unsupported by the atmospheric model'
        case(flight_numeric_failure); message='Flight quantities cannot be represented safely'
        case(flight_invalid_dataset); message='No prepared data or representative Mach sweeps supplied'
        case(flight_invalid_reynolds_group); message='Reynolds group index is outside structure%reynolds_groups'
        case(flight_invalid_structure); message='Invalid nominal Reynolds number or representative run index'
        case(flight_reynolds_mismatch); message='Flight Reynolds number exceeds the specified relative tolerance'
        case(flight_coefficient_failure); message='Coefficient query rejected; inspect coefficient_stat'
        case(flight_no_matching_altitude); message='No Reynolds-matched altitude within the atmospheric range'
        case(flight_solver_failure); message='Altitude search did not reach the requested precision'
        case default; message='Unknown flight status'
        end select

    end function
    
end module flight_condition_validation
