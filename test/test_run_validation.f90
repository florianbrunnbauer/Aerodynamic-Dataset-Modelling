program test_run_validation

    use iso_fortran_env, only: real64
    use ieee_arithmetic, only: ieee_value, ieee_quiet_nan

    use types, only: aero_run_type, validation_result_type
    use dataset_validation, only: validate_run

    implicit none

    type(aero_run_type) :: run
    type(validation_result_type) :: result

    integer :: failures

    failures = 0

    print *
    print *, "========================================"
    print *, "TEST: Run validation"
    print *, "========================================"
    print *


    ! ------------------------------------------------------------
    ! Test 1: valid run
    ! ------------------------------------------------------------

    call make_valid_run(run)

    call validate_run(run, result)

    call check(result%is_valid, &
               "Valid run should be accepted.", result, failures)

    call check(result%n_points == 4, &
               "Valid run should contain 4 points.", result, failures)

    call check(result%n_duplicate_alpha == 0, &
               "Valid run should contain no duplicate alpha.", result, failures)

    call check(result%n_invalid_values == 0, &
               "Valid run should contain no invalid values.", result, failures)

    call check(result%alpha_sorted, &
               "Valid run should have sorted alpha.", result, failures)


    ! ------------------------------------------------------------
    ! Test 2: duplicate alpha
    ! ------------------------------------------------------------

    call make_valid_run(run)

    run%alpha(3) = run%alpha(2)

    call validate_run(run, result)

    call check(.not. result%is_valid, &
               "Duplicate alpha should invalidate run.", result, failures)

    call check(result%n_duplicate_alpha == 1, &
               "Duplicate alpha should be counted.", result, failures)


    ! ------------------------------------------------------------
    ! Test 3: unsorted alpha
    ! ------------------------------------------------------------

    call make_valid_run(run)

    run%alpha = [ &
        -2.0_real64, &
         1.0_real64, &
         0.0_real64, &
         2.0_real64 &
    ]

    call validate_run(run, result)

    call check(.not. result%is_valid, &
               "Unsorted alpha should invalidate run.", result, failures)

    call check(.not. result%alpha_sorted, &
               "Unsorted alpha should be reported.", result, failures)


    ! ------------------------------------------------------------
    ! Test 4: NaN value
    ! ------------------------------------------------------------

    call make_valid_run(run)

    run%cl(2) = ieee_value(0.0_real64, ieee_quiet_nan)

    call validate_run(run, result)

    call check(.not. result%is_valid, &
               "NaN should invalidate run.", result, failures)

    call check(result%n_invalid_values == 1, &
               "NaN should be counted.", result, failures)


    ! ------------------------------------------------------------
    ! Test 5: inconsistent array sizes
    ! ------------------------------------------------------------

    call make_valid_run(run)

    deallocate(run%cm)
    allocate(run%cm(3))

    run%cm = 0.0_real64

    call validate_run(run, result)

    call check(.not. result%is_valid, &
               "Mismatched array sizes should invalidate run.", result, failures)


    ! ------------------------------------------------------------
    ! Final result
    ! ------------------------------------------------------------

    if (failures > 0) then

        print *
        print *, failures, " FAILED: dataset validation test(s)"
        print *

        error stop 1

    end if

    print *
    print *, "PASSED: Dataset validation tests"
    print *


contains


    subroutine make_valid_run(created_run)

        type(aero_run_type), intent(out) :: created_run

        allocate( &
            created_run%alpha(4), &
            created_run%mach(4), &
            created_run%reynolds(4), &
            created_run%cl(4), &
            created_run%cd(4), &
            created_run%cm(4) &
        )

        created_run%alpha = [ &
            -2.0_real64, &
             0.0_real64, &
             1.0_real64, &
             2.0_real64 &
        ]

        created_run%mach = 0.85_real64
        created_run%reynolds = 5.0e6_real64

        created_run%cl = [ &
            -0.2_real64, &
             0.0_real64, &
             0.1_real64, &
             0.2_real64 &
        ]

        created_run%cd = [ &
            0.030_real64, &
            0.020_real64, &
            0.021_real64, &
            0.025_real64 &
        ]

        created_run%cm = -0.05_real64

    end subroutine make_valid_run


    subroutine check(condition, message, result_current_run, current_failures)

        logical, intent(in) :: condition
        character(len=*), intent(in) :: message
        type(validation_result_type), intent(in) :: result_current_run
        integer, intent(inout) :: current_failures

        if (.not. condition) then

            current_failures = current_failures + 1
            print *, "FAILED: ", message, " ", &
                     " Points: ", result_current_run%n_points, &
                     " Duplicates: ", result_current_run%n_duplicate_alpha, &
                     " Invalid values: ", result_current_run%n_invalid_values, &
                     " Alpha sorted: ", result_current_run%alpha_sorted, &
                     " Mach/Reynolds valid: ", result_current_run%mach_reynolds_valid

        end if

    end subroutine check


end program test_run_validation