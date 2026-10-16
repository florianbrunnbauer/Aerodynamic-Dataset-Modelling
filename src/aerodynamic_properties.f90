module aerodynamic_properties
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan

    implicit none

    private
    public :: calculate_dynamic_pressure, calculate_aerodynamic_loads, calculate_lift_to_drag
    integer, parameter, public :: properties_ok=0, properties_invalid_input=1
    integer, parameter, public :: properties_zero_drag=2, properties_nonfinite_result=3

contains

    ! rho [kg/m^3], speed [m/s], q [Pa]. Speed is a nonnegative magnitude.
    subroutine calculate_dynamic_pressure(rho, speed, q, stat)

        real(real64), intent(in) :: rho, speed
        real(real64), intent(out) :: q
        integer, intent(out) :: stat
        real(real64) :: candidate

        q = ieee_value(0.0_real64, ieee_quiet_nan)
        stat = properties_invalid_input
        if (.not. ieee_is_finite(rho) .or. .not. ieee_is_finite(speed)) return
        if (rho <= 0.0_real64 .or. speed < 0.0_real64) return

        ! Log check avoids arithmetic overflow even when floating-point traps are enabled.
        if (speed == 0.0_real64) then
            q = 0.0_real64
            stat = properties_ok
            return
        end if

        stat = properties_nonfinite_result
        if (log(rho) + 2.0_real64 * log(speed) - log(2.0_real64) > log(huge(q))) return

        candidate = (0.5_real64 * rho * speed) * speed

        if (.not. ieee_is_finite(candidate)) return

        q = candidate
        stat = properties_ok

    end subroutine calculate_dynamic_pressure

    ! Coefficients must share S_ref; Cm uses c_ref and the original moment reference point.
    ! q [Pa], S_ref [m^2], c_ref [m], forces [N], pitching moment [N m].
    subroutine calculate_aerodynamic_loads(cl, cd, cm, q, reference_area, reference_chord, &
                                          lift, drag, pitching_moment, stat)

        real(real64), intent(in) :: cl, cd, cm, q, reference_area, reference_chord
        real(real64), intent(out) :: lift, drag, pitching_moment
        integer, intent(out) :: stat
        real(real64) :: result(3), factors(4), nan
        integer :: i

        nan = ieee_value(0.0_real64,ieee_quiet_nan)
        lift = nan; drag = nan; pitching_moment = nan
        stat = properties_invalid_input
        if (.not. all(ieee_is_finite([cl,cd,cm,q,reference_area,reference_chord]))) return
        if (q < 0.0_real64 .or. reference_area <= 0.0_real64 .or. reference_chord <= 0.0_real64) return

        ! Signed coefficients are preserved; negative values are not silently clipped.
        do i = 1, 3
            select case(i)
            case(1); factors = [cl,q,reference_area,1.0_real64]
            case(2); factors = [cd,q,reference_area,1.0_real64]
            case(3); factors = [cm,q,reference_area,reference_chord]
            end select

            call checked_product(factors,result(i),stat)
            if (stat /= properties_ok) return
        end do

        lift = result(1); drag = result(2); pitching_moment = result(3)
        stat = properties_ok

    end subroutine calculate_aerodynamic_loads

    ! Signed CL/CD. This also equals L/D when both coefficients use the same area.
    subroutine calculate_lift_to_drag(cl, cd, ratio, stat)

        real(real64), intent(in) :: cl, cd
        real(real64), intent(out) :: ratio
        integer, intent(out) :: stat
        real(real64) :: candidate

        ratio = ieee_value(0.0_real64,ieee_quiet_nan)
        stat = properties_invalid_input

        if (.not. ieee_is_finite(cl) .or. .not. ieee_is_finite(cd)) return
        stat = properties_zero_drag

        if (cd == 0.0_real64) return
        stat = properties_nonfinite_result

        if (abs(cd) < 1.0_real64) then
            if (abs(cl) > huge(ratio)*abs(cd)) return
        end if

        candidate = cl/cd

        if (.not. ieee_is_finite(candidate)) return

        ratio = candidate
        stat = properties_ok
        
    end subroutine calculate_lift_to_drag

    subroutine checked_product(factors,value,stat)

        real(real64), intent(in) :: factors(:)
        real(real64), intent(out) :: value
        integer, intent(out) :: stat
        real(real64) :: accumulator
        integer :: i

        stat = properties_ok

        if (any(factors == 0.0_real64)) then
            value = 0.0_real64
            return
        end if

        accumulator = 1.0_real64
        do i = 1, size(factors)
            if (abs(factors(i)) > 1.0_real64) then
                if (abs(accumulator) > huge(accumulator)/abs(factors(i))) then
                    value = ieee_value(0.0_real64,ieee_quiet_nan)
                    stat = properties_nonfinite_result
                    return
                end if
            end if
            accumulator = accumulator*factors(i)
        end do

        value = accumulator

    end subroutine checked_product

end module aerodynamic_properties
