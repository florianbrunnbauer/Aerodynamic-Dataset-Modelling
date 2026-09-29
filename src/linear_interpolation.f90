module linear_interpolation
    use iso_fortran_env, only: real64
    implicit none

    public :: linear_interpolate

    contains

    subroutine linear_interpolate(interpolater_array, interpolant_array,&
                                     interpolater_value, interpolated_value)
                        
        real(real64), intent(in) :: interpolater_array(:), interpolant_array(:)
        real(real64), intent(in) :: interpolater_value
        real(real64), intent(out) :: interpolated_value
        integer :: lower_index, upper_index

        if (size(interpolater_array) < 2) then
            error stop "Error: The size of interpolater_array must be at least 2."
        end if

        if (size(interpolater_array) /= size(interpolant_array)) then
            error stop "Error: The size of interpolater_array and interpolant_array must be the same."
        end if

        if (any(interpolater_array(2:size(interpolater_array)) <= &
                    interpolater_array(1:size(interpolater_array)-1))) then
            error stop "Error: The interpolater_array must be sorted in ascending order."
        end if

        if ((interpolater_value < interpolater_array(1)) .or. &
        (interpolater_value > interpolater_array(size(interpolater_array)))) then
            error stop "Error: The interpolater_value is out of the bounds of the interpolater_array."
        end if

        ! Find the indices of the two points that bracket the interpolater_value
        lower_index = maxloc(interpolater_array, dim=1, mask=interpolater_array &
                                                            <= interpolater_value)
        upper_index = minloc(interpolater_array, dim=1, mask=interpolater_array&
                                                            >= interpolater_value)
        
        ! Check if the interpolater_value is exactly equal to one of the points
        if (lower_index == upper_index) then
            interpolated_value = interpolant_array(lower_index)
            return
        end if

        ! Perform linear interpolation
        interpolated_value = interpolant_array(lower_index) +&
                (interpolant_array(upper_index) - interpolant_array(lower_index))/ &
                (interpolater_array(upper_index) - interpolater_array(lower_index))*&
                (interpolater_value - interpolater_array(lower_index))
                             
    end subroutine linear_interpolate

end module linear_interpolation