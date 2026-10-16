program test_aerodynamic_properties
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_value, ieee_quiet_nan, ieee_positive_inf
    use aerodynamic_properties

    implicit none
    real(real64) :: q, lift, drag, moment, ratio, nan, inf
    integer :: stat, checks

    checks = 0
    nan = ieee_value(0.0_real64,ieee_quiet_nan)
    inf = ieee_value(0.0_real64,ieee_positive_inf)

    print '(a)', ''
    print '(a)', '=== test_aerodynamic_properties ==='

    ! Synthetic reference values, not assumed CRM geometry or conditions.
    call calculate_dynamic_pressure(1.2_real64,100.0_real64,q,stat)
    call check(stat == properties_ok,'dynamic pressure status')
    call close_to(q,6000.0_real64)

    call calculate_aerodynamic_loads(0.5_real64,0.025_real64,-0.04_real64,q,10.0_real64,2.0_real64, &
                                    lift,drag,moment,stat)
    call check(stat == properties_ok,'load status')
    call close_to(lift,30000.0_real64)
    call close_to(drag,1500.0_real64)
    call close_to(moment,-4800.0_real64)

    call calculate_lift_to_drag(0.5_real64,0.025_real64,ratio,stat)
    call check(stat == properties_ok,'L/D status')
    call close_to(ratio,20.0_real64)
    call close_to(lift/drag,ratio)

    call calculate_aerodynamic_loads(-0.5_real64,0.025_real64,0.04_real64,q,20.0_real64,4.0_real64, &
                                    lift,drag,moment,stat)
    call close_to(lift,-60000.0_real64)
    call close_to(drag,3000.0_real64)
    call close_to(moment,19200.0_real64)

    call calculate_dynamic_pressure(1.2_real64,200.0_real64,q,stat)
    call close_to(q,24000.0_real64)

    call calculate_dynamic_pressure(1.2_real64,0.0_real64,q,stat)
    call check(stat == properties_ok,'zero speed')
    call close_to(q,0.0_real64)

    call calculate_aerodynamic_loads(0.5_real64,0.025_real64,-0.04_real64,q,10.0_real64,2.0_real64, &
                                    lift,drag,moment,stat)
    call close_to(lift,0.0_real64)
    call close_to(drag,0.0_real64)
    call close_to(moment,0.0_real64)

    call calculate_dynamic_pressure(0.0_real64,100.0_real64,q,stat)
    call check(stat == properties_invalid_input.and.ieee_is_nan(q),'invalid density')

    call calculate_dynamic_pressure(1.2_real64,-100.0_real64,q,stat)
    call check(stat == properties_invalid_input.and.ieee_is_nan(q),'invalid speed')

    call calculate_dynamic_pressure(nan,100.0_real64,q,stat)
    call check(stat == properties_invalid_input.and.ieee_is_nan(q),'NaN density')

    call calculate_dynamic_pressure(1.2_real64,inf,q,stat)
    call check(stat == properties_invalid_input.and.ieee_is_nan(q),'infinite speed')

    call calculate_dynamic_pressure(1.2_real64,huge(q),q,stat)
    call check(stat == properties_nonfinite_result.and.ieee_is_nan(q),'pressure overflow')

    call calculate_lift_to_drag(0.5_real64,0.0_real64,ratio,stat)
    call check(stat == properties_zero_drag.and.ieee_is_nan(ratio),'zero drag coefficient')

    call calculate_lift_to_drag(nan,0.025_real64,ratio,stat)
    call check(stat == properties_invalid_input.and.ieee_is_nan(ratio),'invalid ratio input')

    call calculate_lift_to_drag(huge(ratio),tiny(ratio),ratio,stat)
    call check(stat == properties_nonfinite_result.and.ieee_is_nan(ratio),'ratio overflow')

    call calculate_lift_to_drag(-0.5_real64,0.025_real64,ratio,stat)
    call close_to(ratio,-20.0_real64)

    call calculate_aerodynamic_loads(0.5_real64,0.025_real64,-0.04_real64,-1.0_real64, &
                                    10.0_real64,2.0_real64,lift,drag,moment,stat)
    call invalid_loads()

    call calculate_aerodynamic_loads(0.5_real64,0.025_real64,-0.04_real64,6000.0_real64, &
                                    0.0_real64,2.0_real64,lift,drag,moment,stat)
    call invalid_loads()

    call calculate_aerodynamic_loads(0.5_real64,0.025_real64,-0.04_real64,6000.0_real64, &
                                    10.0_real64,0.0_real64,lift,drag,moment,stat)
    call invalid_loads()

    call calculate_aerodynamic_loads(nan,0.025_real64,-0.04_real64,6000.0_real64, &
                                    10.0_real64,2.0_real64,lift,drag,moment,stat)
    call invalid_loads()

    call calculate_aerodynamic_loads(1.0_real64,1.0_real64,huge(moment),2.0_real64, &
                                    1.0_real64,1.0_real64,lift,drag,moment,stat)
    call check(stat == properties_nonfinite_result,'moment overflow status')
    call check(ieee_is_nan(lift).and.ieee_is_nan(drag).and.ieee_is_nan(moment),'atomic output failure')

    print '(a,i0,a)', 'PASS: ',checks,' assertions'

contains

    subroutine check(condition,label)

        logical,intent(in) :: condition
        character(len=*),intent(in) :: label

        checks = checks + 1

        if (.not. condition) then
            print '(a)', 'FAIL: '//label
            error stop 1
        end if

    end subroutine

    subroutine close_to(actual,expected)

        real(real64),intent(in) :: actual,expected

        call check(abs(actual-expected)<=1.0e-12_real64*max(1.0_real64,abs(expected)),'numeric result')

    end subroutine

    subroutine invalid_loads()

        call check(stat == properties_invalid_input,'invalid load inputs')

        call check(ieee_is_nan(lift).and.ieee_is_nan(drag).and.ieee_is_nan(moment),'invalid load NaNs')

    end subroutine
    
end program test_aerodynamic_properties
