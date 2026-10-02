program test_linear_interpolation
    use iso_fortran_env, only: real64
    use linear_interpolation, only: linear_interpolate
    implicit none

    ! Deliberately non-linear overall dataset.
    ! Each individual interval is still interpolated linearly.
    real(real64), parameter :: x_values(5) = &
        [-5.0_real64, 0.0_real64, 5.0_real64, 10.0_real64, 15.0_real64]

    real(real64), parameter :: y_values(5) = &
        [-0.5_real64, 0.0_real64, 1.0_real64, 0.5_real64, 1.5_real64]

    real(real64), parameter :: x_nonuniform(5) = &
        [-5.0_real64, -1.0_real64, 2.0_real64, 8.0_real64, 15.0_real64]

    real(real64), parameter :: y_nonuniform(5) = &
        [-0.5_real64, 0.0_real64, 0.6_real64, 1.2_real64, 0.5_real64]

    print *
    print *, "========================================"
    print *, "Test: Linear interpolation"
    print *, "========================================"
    print *

    call assert_interpolation(x_values, y_values, -5.0_real64, -0.5_real64, &
                              "lower endpoint")

    call assert_interpolation(x_values, y_values, 15.0_real64, 1.5_real64, &
                              "upper endpoint")

    call assert_interpolation(x_values, y_values, 5.0_real64, 1.0_real64, &
                              "exact internal data point")

    call assert_interpolation(x_values, y_values, -2.5_real64, -0.25_real64, &
                              "first interval")

    call assert_interpolation(x_values, y_values, 2.5_real64, 0.5_real64, &
                              "second interval")

    call assert_interpolation(x_values, y_values, 7.5_real64, 0.75_real64, &
                              "third interval")

    call assert_interpolation(x_values, y_values, 12.5_real64, 1.0_real64, &
                              "last interval")
                            
    call assert_interpolation(x_nonuniform, y_nonuniform, -4.0_real64, -0.375_real64, &
                              "first non-uniform interval")

    call assert_interpolation(x_nonuniform, y_nonuniform, 6.0_real64, 1.0_real64, &
                              "second non-uniform interval")

    call assert_interpolation(x_nonuniform, y_nonuniform, 2.0_real64, 0.6_real64, &
                              "exact point in non-uniform dataset")

    print *
    print *, "PASSED: Linear Interpolation Tests"
    print *

    contains

        subroutine assert_interpolation(x_vals, y_vals, x, expected, test_name)
            real(real64), intent(in) :: x_vals(:), y_vals(:)
            real(real64), intent(in) :: x, expected
            character(len=*), intent(in) :: test_name

            real(real64), parameter :: tolerance = 1.0e-10_real64
            real(real64) :: actual

            call linear_interpolate(x_vals, y_vals, x, actual)

            if (abs(actual - expected) > tolerance) then
                print *, "Test failed: ", test_name
                print *, "Input:    ", x
                print *, "Expected: ", expected
                print *, "Actual:   ", actual
                print *, "Error:    ", abs(actual - expected)

                print * 
                print *, "FAILED: Linear interpolation test"
                print * 
                error stop 1
            end if

            print *, "Test passed: ", test_name

        end subroutine assert_interpolation


end program test_linear_interpolation