program test_dataset_characterisation

    use iso_fortran_env, only: real64

    use types, only: aero_run_type, run_characterisation_type

    use dataset_characterisation, only: characterise_run

    implicit none

    type(aero_run_type) :: run
    type(run_characterisation_type) :: result

    real(real64), parameter :: tolerance = 1.0e-10_real64

    integer :: failures

    failures = 0

    print *
    print *, "========================================"
    print *, "TEST: Dataset characterisation"
    print *, "========================================"
    print *

    allocate( &
        run%alpha(4), &
        run%mach(4), &
        run%reynolds(4), &
        run%cl(4), &
        run%cd(4), &
        run%cm(4) &
    )


    run%alpha = [ &
        -2.0_real64, &
         0.0_real64, &
         2.0_real64, &
         4.0_real64 &
    ]

    run%mach = [ &
        0.849_real64, &
        0.850_real64, &
        0.851_real64, &
        0.850_real64 &
    ]

    run%reynolds = [ &
        4.98e6_real64, &
        5.00e6_real64, &
        5.02e6_real64, &
        5.00e6_real64 &
    ]


    call characterise_run(run, result)


    call check(result%n_points == 4, &
               "Incorrect point count.", failures)

    call check(abs(result%alpha_min - (-2.0_real64)) < tolerance, &
               "Incorrect minimum alpha.", failures)

    call check(abs(result%alpha_max - 4.0_real64) < tolerance, &
               "Incorrect maximum alpha.", failures)

    call check(abs(result%mach_mean - 0.850_real64) < tolerance, &
               "Incorrect mean Mach number.", failures)

    call check(abs(result%mach_min - 0.849_real64) < tolerance, &
               "Incorrect minimum Mach number.", failures)

    call check(abs(result%mach_max - 0.851_real64) < tolerance, &
               "Incorrect maximum Mach number.", failures)

    call check(abs(result%reynolds_mean - 5.0e6_real64) < tolerance, &
               "Incorrect mean Reynolds number.", failures)


    if (failures > 0) then

        print *
        print *, "FAILED: Dataset characterisation"
        print *
        
        error stop 1
    end if

    print *
    print *, "PASSED: Dataset characterisation"
    print *


contains

    subroutine check(condition, message, fails)

        logical, intent(in) :: condition
        character(len=*), intent(in) :: message
        integer, intent(inout) :: fails

        if (.not. condition) then

            fails = fails + 1

            print *, "FAILED: ", message

        end if

    end subroutine check

end program test_dataset_characterisation