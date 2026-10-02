program test_read_crm_run

    use iso_fortran_env, only: real64

    use types, only: run_info_type, aero_run_type
    use data_io, only: inspect_crm_run, read_crm_run

    implicit none

    type(run_info_type) :: info
    type(aero_run_type) :: run

    integer :: stat

    real(real64), parameter :: tolerance = 1.0e-8_real64

    print *
    print *, "========================================"
    print *, "Test: Read CRM runs"
    print *, "========================================"
    print *


    call inspect_crm_run("data/phase_2/t197R39.csv", info, stat)

    if (stat /= 0) then
        error stop "FAILED: CRM inspection"
    end if


    call read_crm_run(info, run, stat)

    if (stat /= 0) then
        error stop "FAILED: CRM run reader"
    end if


    ! Number of measurement points.
    if (size(run%alpha) /= 35) then
        error stop "FAILED: Number of measurement points"
    end if


    ! Check all arrays have the same size.
    if (size(run%mach) /= 35 .or. &
        size(run%reynolds) /= 35 .or. &
        size(run%cl) /= 35 .or. &
        size(run%cd) /= 35 .or. &
        size(run%cm) /= 35) then

        error stop "FAILED: Inconsistent array sizes"
    end if


    ! First measurement point.
    if (abs(run%alpha(1) - (-2.89024_real64)) > tolerance) then
        error stop "FAILED: ALPHA"
    end if

    if (abs(run%mach(1) - 0.700381_real64) > tolerance) then
        error stop "FAILED: MACH"
    end if

    if ( &
        abs(run%reynolds(1) - 4995140.0_real64) > &
        1.0_real64 &
    ) then
        error stop "FAILED: Reynolds"
    end if

    if (abs(run%cl(1) - (-0.144471_real64)) > tolerance) then
        error stop "FAILED: CL"
    end if

    if (abs(run%cd(1) - 0.0159214_real64) > tolerance) then
        error stop "FAILED: CD"
    end if

    if (abs(run%cm(1) - (-0.0278011_real64)) > tolerance) then
        error stop "FAILED: CM"
    end if

    print *
    print *, "PASSED: CRM run reader"
    print *

end program test_read_crm_run