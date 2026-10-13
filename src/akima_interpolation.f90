module akima_interpolation
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    implicit none
    private
    public :: akima_interpolate

contains

    ! Classical Akima interpolation, not modified Akima (MAKIMA).
    ! Reference: H. Akima, J. ACM 17(4), 589--602 (1970).
    ! At least five points are required by this module's explicit contract.
    subroutine akima_interpolate(interpolater_array, interpolant_array, &
                                 interpolater_value, interpolated_value)
        real(real64), intent(in) :: interpolater_array(:), interpolant_array(:)
        real(real64), intent(in) :: interpolater_value
        real(real64), intent(out) :: interpolated_value
        real(real64), allocatable :: slope(:), derivative(:)
        real(real64) :: w1, w2, weight_sum, scale, t, h
        integer :: n, i, lower

        n = size(interpolater_array)
        if (n < 5) error stop 'AKIMA: at least 5 points required.'
        if (size(interpolant_array) /= n) error stop 'AKIMA: array sizes must match.'
        if (.not. all(ieee_is_finite(interpolater_array))) error stop 'AKIMA: x must be finite.'
        if (.not. all(ieee_is_finite(interpolant_array))) error stop 'AKIMA: y must be finite.'
        if (.not. ieee_is_finite(interpolater_value)) error stop 'AKIMA: query must be finite.'
        if (any(interpolater_array(2:n) <= interpolater_array(1:n-1))) &
            error stop 'AKIMA: x must be strictly increasing.'
        if (interpolater_value < interpolater_array(1) .or. &
            interpolater_value > interpolater_array(n)) error stop 'AKIMA: query outside data range.'

        lower = maxloc(interpolater_array, dim=1, mask=interpolater_array <= interpolater_value)
        if (interpolater_value == interpolater_array(lower)) then
            interpolated_value = interpolant_array(lower)
            return
        end if

        ! Real interval slopes occupy 1:n-1; extend by two at each end.
        allocate(slope(-1:n+1), derivative(n))
        slope(1:n-1) = (interpolant_array(2:n)-interpolant_array(1:n-1)) &
                    / (interpolater_array(2:n)-interpolater_array(1:n-1))
        slope(0) = 2.0_real64*slope(1)-slope(2)
        slope(-1) = 2.0_real64*slope(0)-slope(1)
        slope(n) = 2.0_real64*slope(n-1)-slope(n-2)
        slope(n+1) = 2.0_real64*slope(n)-slope(n-1)

        do i = 1, n
            w1 = abs(slope(i+1)-slope(i))
            w2 = abs(slope(i-1)-slope(i-2))
            weight_sum = w1+w2
            scale = maxval(abs(slope(i-2:i+1)))
            ! Zero weights: mean adjacent slopes. A local relative tolerance
            ! also handles roundoff on straight lines without a fixed scale.
            if (weight_sum <= 32.0_real64*epsilon(1.0_real64)*scale) then
                derivative(i) = 0.5_real64*slope(i-1)+0.5_real64*slope(i)
            else
                derivative(i) = (w1/weight_sum)*slope(i-1)+(w2/weight_sum)*slope(i)
            end if
        end do

        h = interpolater_array(lower+1)-interpolater_array(lower)
        t = (interpolater_value-interpolater_array(lower)) / h
        interpolated_value = (2*t**3-3*t**2+1)*interpolant_array(lower) &
                           + (t**3-2*t**2+t)*h*derivative(lower) &
                           + (-2*t**3+3*t**2)*interpolant_array(lower+1) &
                           + (t**3-t**2)*h*derivative(lower+1)
    end subroutine akima_interpolate

end module akima_interpolation
