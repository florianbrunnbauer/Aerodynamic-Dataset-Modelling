program test_data_io
    use types, only: aerodynamic_dataset_type
    use data_io, only: read_airfoil_data
    use iso_fortran_env, only: real64
    use ieee_arithmetic, only: ieee_is_nan

    implicit none

    character(len=*), parameter :: filename = & 
        "data/naca0012.csv"
    type(aerodynamic_dataset_type) :: dataset

    integer, parameter :: expected_rows = 147
    real(real64), parameter :: tolerance = 1.0e-10_real64
    real(real64), parameter :: expected_reynolds = 1.0e6_real64
    real(real64), parameter :: expected_mach = 0.5_real64

    real(real64) :: expected_alphas(4) = [-18.5_real64,-18.25_real64,&
                                         18.25_real64, 18.5_real64] 

    real(real64) :: expected_cls(4) = [-1.2258_real64, -1.2456_real64, &
                                      1.2485_real64, 1.2284_real64]

    real(real64) :: expected_cds(4) = [0.10236_real64, 0.09505_real64, &
                                      0.09493_real64, 0.10229_real64]

    ! real(real64) :: expected_cdps(4) = [0.09929_real64, 0.09187_real64, &
    !                                    0.09174_real64, 0.09922_real64]

    real(real64) :: expected_cms(4) = [-0.0012_real64, -0.0049_real64, &
                                      0.0046_real64, 0.0008_real64]

    ! real(real64) :: expected_top_xtrs(4) = [1.0000_real64, 1.0000_real64, &
    !                                        0.0136_real64, 0.0135_real64]

    ! real(real64) :: expected_bot_xtrs(4) = [0.0135_real64, 0.0136_real64, &
    !                                        1.0000_real64, 1.0000_real64]

    integer :: rows_to_check(4) = [1, 2, expected_rows-1, expected_rows]


    call read_airfoil_data(filename, dataset)

    ! Check if the Reynolds number and Mach number are as expected
    if (abs(dataset%polars(1)%reynolds - expected_reynolds) > tolerance) then
        print *, "Test failed: Reynolds number does not match expected value."
        print *, "Expected: ", expected_reynolds, " Actual: ", dataset%polars(1)%reynolds
        error stop
    end if

    if (abs(dataset%polars(1)%mach - expected_mach) > tolerance) then
        print *, "Test failed: Mach number does not match expected value."
        print *, "Expected: ", expected_mach, " Actual: ", dataset%polars(1)%mach
        error stop
    end if

    call assert_array_close(dataset%polars(1)%alpha(rows_to_check), expected_alphas, &
                            rows_to_check, tolerance, "Alpha values")
    call assert_array_close(dataset%polars(1)%cl(rows_to_check), expected_cls, &
                            rows_to_check, tolerance, "Cl values")
    call assert_array_close(dataset%polars(1)%cd(rows_to_check), expected_cds, &
                            rows_to_check, tolerance, "Cd values")
    call assert_array_close(dataset%polars(1)%cm(rows_to_check), expected_cms, &
                            rows_to_check, tolerance, "Cm values")

    contains

    subroutine assert_array_close(actual, expected, checkable, tol, test_name)

        real(real64), intent(in) :: actual(:), expected(:), tol
        integer, intent(in) :: checkable(:)
        character(len=*), intent(in) :: test_name
        integer :: i

        if (size(actual) /= size(expected)) then
            print *, "Test ", test_name, " failed: array sizes do not match."
            error stop
        end if

        if (any(abs(actual - expected) > tol) .or. any(ieee_is_nan(actual))) then

            print *, "Test ", test_name, " failed: values do not match within tolerance."

            do i = 1, size(checkable)
                if ((abs(actual(checkable(i)) - expected(i)) > tol) &
                    .or. (ieee_is_nan(actual(checkable(i))))) then
                    print *, "Mismatch at index ", checkable(i), &
                             ": Expected ", expected(i), &
                             ", Actual ", actual(checkable(i))
                end if
            end do

            error stop

        end if

        print *, "Test ", test_name, " passed."

    end subroutine assert_array_close
    
end program test_data_io