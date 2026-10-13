module pchip_interpolation
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    implicit none
    private
    public :: pchip_interpolate

contains

    ! Shape-preserving cubic Hermite interpolation (Fritsch--Butland).
    ! Interface and rejection of extrapolation match linear_interpolate.
    ! Reference: SciPy PchipInterpolator documentation, derivative rules.
    subroutine pchip_interpolate(interpolater_array, interpolant_array, &
                                 interpolater_value, interpolated_value)
        real(real64), intent(in) :: interpolater_array(:), interpolant_array(:)
        real(real64), intent(in) :: interpolater_value
        real(real64), intent(out) :: interpolated_value
        real(real64), allocatable :: h(:), slope(:), derivative(:)
        real(real64) :: w1, w2, t
        integer :: n, i, lower

        n = size(interpolater_array)
        if (n < 2) error stop 'PCHIP: at least 2 points required.'
        if (size(interpolant_array) /= n) error stop 'PCHIP: array sizes must match.'
        if (.not. all(ieee_is_finite(interpolater_array))) error stop 'PCHIP: x must be finite.'
        if (.not. all(ieee_is_finite(interpolant_array))) error stop 'PCHIP: y must be finite.'
        if (.not. ieee_is_finite(interpolater_value)) error stop 'PCHIP: query must be finite.'
        if (any(interpolater_array(2:n) <= interpolater_array(1:n-1))) &
            error stop 'PCHIP: x must be strictly increasing.'
        if (interpolater_value < interpolater_array(1) .or. &
            interpolater_value > interpolater_array(n)) error stop 'PCHIP: query outside data range.'

        lower = maxloc(interpolater_array, dim=1, mask=interpolater_array <= interpolater_value)
        ! Exact knots (including endpoints) return the original measurement.
        if (interpolater_value == interpolater_array(lower)) then
            interpolated_value = interpolant_array(lower)
            return
        end if

        allocate(h(n-1), slope(n-1), derivative(n))
        h = interpolater_array(2:n) - interpolater_array(1:n-1)
        slope = (interpolant_array(2:n) - interpolant_array(1:n-1)) / h
        if (n == 2) then
            derivative = slope(1)
        else
            do i = 2, n-1
                if (slope(i-1) == 0.0_real64 .or. slope(i) == 0.0_real64) then
                    derivative(i) = 0.0_real64
                else if (sign(1.0_real64, slope(i-1)) /= sign(1.0_real64, slope(i))) then
                    derivative(i) = 0.0_real64
                else
                    w1 = 2.0_real64*h(i) + h(i-1)
                    w2 = h(i) + 2.0_real64*h(i-1)
                    derivative(i) = (w1+w2) / (w1/slope(i-1) + w2/slope(i))
                end if
            end do
            derivative(1) = endpoint_derivative(h(1), h(2), slope(1), slope(2))
            derivative(n) = endpoint_derivative(h(n-1), h(n-2), slope(n-1), slope(n-2))
        end if

        t = (interpolater_value-interpolater_array(lower)) / h(lower)
        ! Cubic Hermite basis: endpoint values and endpoint derivatives.
        interpolated_value = (2*t**3-3*t**2+1)*interpolant_array(lower) &
                           + (t**3-2*t**2+t)*h(lower)*derivative(lower) &
                           + (-2*t**3+3*t**2)*interpolant_array(lower+1) &
                           + (t**3-t**2)*h(lower)*derivative(lower+1)
    end subroutine pchip_interpolate

    pure function endpoint_derivative(h1, h2, s1, s2) result(d)
        real(real64), intent(in) :: h1, h2, s1, s2
        real(real64) :: d

        ! One-sided three-point estimate, then limit to preserve shape.
        d = ((2.0_real64*h1+h2)*s1-h1*s2) / (h1+h2)
        if (s1 == 0.0_real64 .or. sign(1.0_real64, d) /= sign(1.0_real64, s1)) then
            d = 0.0_real64
        else if (sign(1.0_real64, s1) /= sign(1.0_real64, s2)) then
            if (abs(d) > 3.0_real64*abs(s1)) d = 3.0_real64*s1
        end if
    end function endpoint_derivative

end module pchip_interpolation
