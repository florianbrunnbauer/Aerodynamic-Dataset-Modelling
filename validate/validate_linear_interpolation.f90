program validate_linear_interpolation
    use iso_fortran_env, only: real64
    use linear_interpolation, only: linear_interpolate
    use types, only: aerodynamic_dataset_type
    use data_io, only: read_airfoil_data
    implicit none

    character(len=*), parameter :: filename = "../data/naca0012.csv"
    type(aerodynamic_dataset_type) :: dataset
    real(real64) :: absolute_error_cl(6), absolute_error_cd(6), absolute_error_cm(6), delta_cl(6), &
                        delta_cd(6), delta_cm(6)
    real(real64) :: interpolated_cl(6), interpolated_cd(6), interpolated_cm(6), &
                     expected_cl(6),  expected_cd(6), expected_cm(6)
    integer :: skip_rows(6) = [21, 42, 63, 84, 105, 126]

    ! Read the airfoil data from the CSV file
    call read_airfoil_data(filename, dataset)

    ! Interpolate for all 6 values in cl
    call evaluate(dataset%polars(1)%alpha, dataset%polars(1)%cl, skip_rows, "cl", &
                    expected_cl, interpolated_cl, delta_cl, absolute_error_cl) 
    
    ! Interpolate for all 6 values in cd
    call evaluate(dataset%polars(1)%alpha, dataset%polars(1)%cd, skip_rows, "cd", &
                    expected_cd, interpolated_cd, delta_cd, absolute_error_cd)
    
    ! Interpolate for all 6 values in cm
    call evaluate(dataset%polars(1)%alpha, dataset%polars(1)%cm, skip_rows, "cm", &
                    expected_cm, interpolated_cm, delta_cm, absolute_error_cm)

    contains

    subroutine evaluate(desired_raw, expected_raw, skip, current_coefficient,&
                                                 expected, interpolated, delta, absolute_error)
        real(real64), intent(in) :: desired_raw(:), expected_raw(:) 
        integer, intent(in) :: skip(:)
        character(len=2), intent(in) :: current_coefficient

        real(real64), intent(out) :: expected(:), interpolated(:), delta(:), absolute_error(:)

        real(real64) :: desired(size(skip)), desired_cleared(size(desired_raw)-size(skip)),&
                         expected_cleared(size(desired_raw)-size(skip))
        real(real64) :: rmse
        integer :: skipped, i, n

        skipped = 0
        
        ! Extract the Expected alpha, cl, cd, and cm values from the dataset
        do i = 1, 6
            desired(i) = desired_raw(skip(i))
            expected(i) = expected_raw(skip(i))
        end do

        ! Create the new Arrays without the skipped rows
        do n = 1, size(desired_raw)
            if (any(skip == n)) then 
                skipped = skipped + 1
                cycle
            else
                desired_cleared(n-skipped) = desired_raw(n)
                expected_cleared(n-skipped) = expected_raw(n)
            end if
        end do

        do i = 1, 6
            call linear_interpolate(desired_cleared, expected_cleared,&
                                            desired(i), interpolated(i))
        end do

        delta = interpolated(:) - expected(:)

        absolute_error = sqrt((interpolated(:) - expected(:))**2)

        rmse = sqrt(sum(delta**2))/real(size(delta),real64)

        print *, "Evaluated ", current_coefficient, " for", expected, "at", skip_rows
        print *, "Interpolation result", interpolated(:)
        print *, "Error:", delta, "Absolut Error:", absolute_error
        print *, "Root mean square Error:", rmse

    end subroutine evaluate

end program validate_linear_interpolation