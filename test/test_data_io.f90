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

    print *
    print *, "========================================"
    print *, "Test: Data I/O 1-D aerodynamic dataset"
    print *, "========================================"
    print *

    call read_airfoil_data(filename, dataset)

    ! Check if the Reynolds number and Mach number are as expected
    if (abs(dataset%polars(1)%reynolds - expected_reynolds) > tolerance) then
        print *, "FAILED: Reynolds number does not match expected value."
        print *, "Expected: ", expected_reynolds, " Actual: ", dataset%polars(1)%reynolds
        error stop
    end if

    if (abs(dataset%polars(1)%mach - expected_mach) > tolerance) then
        print *, "FAILED: Mach number does not match expected value."
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

    print *
    print *, "PASSED: Data I/O 1-D aerodynamic dataset"
    print *

    contains

    subroutine assert_array_close(actual, expected, checkable, tol, test_name)

        real(real64), intent(in) :: actual(:), expected(:), tol
        integer, intent(in) :: checkable(:)
        character(len=*), intent(in) :: test_name
        integer :: i

        if (size(actual) /= size(expected)) then
            print *, "Test failed: ", test_name
            print *, "Array sizes do not match."
            print *, "Actual size:   ", size(actual)
            print *, "Expected size: ", size(expected)
            error stop
        end if

        if (size(checkable) /= size(actual)) then
            print *, "Test setup error: ", test_name
            print *, "Row index array has a different size."
            error stop
        end if

        if (any(abs(actual - expected) > tol) .or. any(ieee_is_nan(actual))) then

            print *, "Test failed:", test_name
            print *, "Values do not match within tolerance."

            do i = 1, size(checkable)
                if ((abs(actual(i) - expected(i)) > tol) &
                    .or. (ieee_is_nan(actual(i)))) then
                    print *, "Dataset row: ", checkable(i)
                    print *, "Expected ", expected(i)
                    print *, "Actual ", actual(i)
                    print *, "Difference: ", abs(actual(i) - expected(i))
                    error stop
                end if
            end do

        end if

        print *, "Test passed: ", test_name

    end subroutine assert_array_close
    
end program test_data_io