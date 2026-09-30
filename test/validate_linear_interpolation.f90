program validate_linear_interpolation
    use iso_fortran_env, only: real64
    use linear_interpolation, only: linear_interpolate
    use types, only: aerodynamic_dataset_type
    use data_io, only: read_airfoil_data
    implicit none

    character(len=*), parameter :: filename = "data/naca0012.csv"
    type(aerodynamic_dataset_type) :: dataset
    real(real64) :: absolute_error_cl(6), absolute_error_cd(6), absolute_error_cm(6),&
                        delta_cl(6), delta_cd(6), delta_cm(6), max_error_cl, &
                        max_error_cd, max_error_cm, rmse_cl, rmse_cd, rmse_cm
    integer :: skip_rows(6) = [21, 42, 63, 84, 105, 126]

    real(real64), parameter :: max_error_limit_cl = 6.0e-3_real64
    real(real64), parameter :: max_error_limit_cd = 4.0e-4_real64
    real(real64), parameter :: max_error_limit_cm = 8.0e-4_real64
    
    real(real64), parameter :: rmse_limit_cl = 3.0e-3_real64
    real(real64), parameter :: rmse_limit_cd = 2.0e-4_real64
    real(real64), parameter :: rmse_limit_cm = 4.0e-4_real64
    
    ! Read the airfoil data from the CSV file
    call read_airfoil_data(filename, dataset)

    ! Interpolate for all 6 values in cl
    call evaluate(dataset%polars(1)%alpha, dataset%polars(1)%cl, skip_rows, "cl", &
                    delta_cl, absolute_error_cl, max_error_cl, rmse_cl) 
    
    ! Interpolate for all 6 values in cd
    call evaluate(dataset%polars(1)%alpha, dataset%polars(1)%cd, skip_rows, "cd", &
                    delta_cd, absolute_error_cd, max_error_cd, rmse_cd)
    
    ! Interpolate for all 6 values in cm
    call evaluate(dataset%polars(1)%alpha, dataset%polars(1)%cm, skip_rows, "cm", &
                    delta_cm, absolute_error_cm, max_error_cm, rmse_cm)

    call assert_validation("cl", rmse_cl, max_error_cl, &
                                rmse_limit_cl, max_error_limit_cl)

    call assert_validation("cd", rmse_cd, max_error_cd, &
                                rmse_limit_cd, max_error_limit_cd)

    call assert_validation("cm", rmse_cm, max_error_cm,&
                                rmse_limit_cm, max_error_limit_cm)

    print *, "All interpolation validation tests passed."

    contains

    subroutine evaluate(desired_raw, expected_raw, skip, current_coefficient,&
                                        delta, absolute_error, max_error, rmse)
        real(real64), intent(in) :: desired_raw(:), expected_raw(:) 
        integer, intent(in) :: skip(:)
        character(len=2), intent(in) :: current_coefficient

        real(real64), intent(out) :: delta(:), absolute_error(:), max_error, rmse

        real(real64) :: desired(size(skip)), desired_cleared(size(desired_raw)-size(skip)),&
                         expected_cleared(size(desired_raw)-size(skip)), expected(size(skip)), &
                          interpolated(size(skip))
        integer :: skipped, i, n

        skipped = 0
        
        ! Extract the Expected alpha, cl, cd, and cm values from the dataset
        do i = 1, size(skip)
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

        do i = 1, size(skip)
            call linear_interpolate(desired_cleared, expected_cleared,&
                                            desired(i), interpolated(i))
        end do

        delta = interpolated - expected

        absolute_error = abs(delta)

        rmse = sqrt(sum(delta**2)/real(size(delta),real64))
        max_error = maxval(absolute_error)

        print *, "------- Evaluated ", current_coefficient, " -------"
        print *, "Expected:", expected
        print *, "Positions:", skip
        print *, "Interpolated:", interpolated
        print *, "Error:", delta
        print *, "Absolute Error:", absolute_error
        print *, "Maximum Absolute Error:", max_error
        print *, "RMSE:", rmse

    end subroutine evaluate

    subroutine assert_validation(coefficient, rmse, max_error, &
                                        rmse_limit, max_error_limit)

        character(len=*), intent(in) :: coefficient
        real(real64), intent(in) :: rmse, max_error
        real(real64), intent(in) :: rmse_limit, max_error_limit

        if (rmse > rmse_limit) then
            print *, "Validation failed for ", coefficient
            print *, "RMSE:          ", rmse
            print *, "Allowed RMSE:  ", rmse_limit
            error stop
        end if

        if (max_error > max_error_limit) then
            print *, "Validation failed for ", coefficient
            print *, "Maximum error:         ", max_error
            print *, "Allowed maximum error: ", max_error_limit
            error stop
        end if

        print *, "Validation passed for ", coefficient

    end subroutine assert_validation

end program validate_linear_interpolation