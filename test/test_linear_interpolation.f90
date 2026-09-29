program test_linear_interpolation
    use iso_fortran_env, only: real64
    use linear_interpolation, only: linear_interpolate
    implicit none

    ! Test data for linear interpolation
    real(real64), parameter :: alpha_values(5) = [-5.0_real64, 0.0_real64, 5.0_real64, 10.0_real64, 15.0_real64]
    real(real64), parameter :: cl_values(5) = [-0.5_real64, 0.0_real64, 0.5_real64, 1.0_real64, 1.5_real64]
    real(real64) :: desired_alpha, interpolated_cl, expected_cl, tolerance = 1.0e-10_real64

    ! Test cases
    desired_alpha = 2.5_real64
    expected_cl = 0.25_real64
    call linear_interpolate(alpha_values, cl_values, desired_alpha, interpolated_cl)
    if (abs(interpolated_cl - expected_cl) > tolerance) then
        print *, "Test failed: Interpolated Cl does not match expected value."
        print *, "Expected: ", expected_cl, " Actual: ", interpolated_cl
        error stop
    end if
    print *, "Test passed: Interpolated Cl matches expected value for alpha =", desired_alpha

    desired_alpha = -2.5_real64
    expected_cl = -0.25_real64
    call linear_interpolate(alpha_values, cl_values, desired_alpha, interpolated_cl)
    if (abs(interpolated_cl - expected_cl) > tolerance) then
        print *, "Test failed: Interpolated Cl does not match expected value."
        print *, "Expected: ", expected_cl, " Actual: ", interpolated_cl
        error stop
    end if
    print *, "Test passed: Interpolated Cl matches expected value for alpha =", desired_alpha

    desired_alpha = 12.5_real64
    expected_cl = 1.25_real64
    call linear_interpolate(alpha_values, cl_values, desired_alpha, interpolated_cl)
    if (abs(interpolated_cl - expected_cl) > tolerance) then
        print *, "Test failed: Interpolated Cl does not match expected value."
        print *, "Expected: ", expected_cl, " Actual: ", interpolated_cl
        error stop
    end if
    print *, "Test passed: Interpolated Cl matches expected value for alpha =", desired_alpha

end program test_linear_interpolation