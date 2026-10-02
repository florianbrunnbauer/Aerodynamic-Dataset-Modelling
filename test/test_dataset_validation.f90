program test_dataset_validation

    use iso_fortran_env, only: real64

    use types, only: aero_run_type, &
                     aero_dataset_type, &
                     dataset_validation_result_type

    use dataset_validation, only: validate_dataset

    implicit none

    type(aero_dataset_type) :: dataset
    type(dataset_validation_result_type) :: result

    integer :: failures

    failures = 0

    print *
    print *, "========================================"
    print *, "TEST: Dataset validation"
    print *, "========================================"
    print *

    allocate(dataset%runs(3))


    ! ------------------------------------------------------------
    ! Run 1: valid
    ! ------------------------------------------------------------

    call make_valid_run(dataset%runs(1))


    ! ------------------------------------------------------------
    ! Run 2: duplicate alpha
    ! ------------------------------------------------------------

    call make_valid_run(dataset%runs(2))

    dataset%runs(2)%alpha(3) = dataset%runs(2)%alpha(2)


    ! ------------------------------------------------------------
    ! Run 3: unsorted alpha
    ! ------------------------------------------------------------

    call make_valid_run(dataset%runs(3))

    dataset%runs(3)%alpha = [ &
        -2.0_real64, &
         1.0_real64, &
         0.0_real64, &
         2.0_real64 &
    ]


    ! ------------------------------------------------------------
    ! Validate complete dataset
    ! ------------------------------------------------------------

    call validate_dataset(dataset, result)


    call check(.not. result%is_valid, &
               "Dataset should be invalid.", failures)

    call check(result%n_runs == 3, &
               "Dataset should contain 3 runs.", failures)

    call check(result%n_valid_runs == 1, &
               "Dataset should contain 1 valid run.", failures)

    call check(result%n_invalid_runs == 2, &
               "Dataset should contain 2 invalid runs.", failures)

    call check(result%run_results(1)%is_valid, &
               "Run 1 should be valid.", failures)

    call check(result%run_results(2)%n_duplicate_alpha == 1, &
               "Run 2 should contain one duplicate alpha.", failures)

    call check(.not. result%run_results(3)%alpha_sorted, &
               "Run 3 should have unsorted alpha.", failures)


    if (failures > 0) then

        print *
        print *, failures, " FAILED: Dataset validation test(s)"
        print *

        error stop 1

    end if


    print *
    print *, "PASSED: Dataset validation tests"
    print *


contains


    subroutine make_valid_run(run)

        type(aero_run_type), intent(out) :: run

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
             1.0_real64, &
             2.0_real64 &
        ]

        run%mach = 0.85_real64
        run%reynolds = 5.0e6_real64

        run%cl = [ &
            -0.2_real64, &
             0.0_real64, &
             0.1_real64, &
             0.2_real64 &
        ]

        run%cd = [ &
            0.030_real64, &
            0.020_real64, &
            0.021_real64, &
            0.025_real64 &
        ]

        run%cm = -0.05_real64

    end subroutine make_valid_run


    subroutine check(condition, message, fails)

        logical, intent(in) :: condition
        character(len=*), intent(in) :: message
        integer, intent(inout) :: fails

        if (.not. condition) then

            fails = fails + 1
            print *, "FAILED: ", message

        end if

    end subroutine check


end program test_dataset_validation