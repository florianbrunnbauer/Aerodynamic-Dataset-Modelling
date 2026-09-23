program import_test
    use data_io, only: read_airfoil_data
    use iso_fortran_env, only: real64
    use ieee_arithmetic, only: ieee_is_nan

    implicit none

    character(len=*), parameter :: filename = & 
        "/home/flo/projects/aerodynamic-dataset-modelling/data/naca0012.csv"
    real(real64), allocatable :: alpha(:), cl(:), cd(:), &
                    cdp(:), cm(:), top_xtr(:), bot_xtr(:)

    integer, parameter :: expected_rows = 147
    integer, parameter :: nr_tests = 8
    integer :: passed_tests, i
    real(real64), parameter :: tolerance = 1.0e-10_real64
    real(real64) :: expected_alphas(4) = [-18.5_real64,-18.25_real64,&
                                         18.25_real64, 18.5_real64] 

    real(real64) :: expected_cls(4) = [-1.2258_real64, -1.2456_real64, &
                                      1.2485_real64, 1.2284_real64]

    real(real64) :: expected_cds(4) = [0.10236_real64, 0.09505_real64, &
                                      0.09493_real64, 0.10229_real64]

    real(real64) :: expected_cdps(4) = [0.09929_real64, 0.09187_real64, &
                                       0.09174_real64, 0.09922_real64]

    real(real64) :: expected_cms(4) = [-0.0012_real64, -0.0049_real64, &
                                      0.0046_real64, 0.0008_real64]

    real(real64) :: expected_top_xtrs(4) = [1.0000_real64, 1.0000_real64, &
                                           0.0136_real64, 0.0135_real64]

    real(real64) :: expected_bot_xtrs(4) = [0.0135_real64, 0.0136_real64, &
                                           1.0000_real64, 1.0000_real64]

    integer :: rows_to_check(4) = [1, 2, expected_rows-1, expected_rows]

    passed_tests = 0

    call read_airfoil_data(filename, alpha, cl, cd, cdp, cm, top_xtr, bot_xtr)

    if (size(alpha) /= expected_rows) then
        print *, "Unexpected number of rows: " , size(alpha),&
                 " Expected: ", expected_rows
    else
        print *, "Nr_rows matched expected count: ", expected_rows
        passed_tests = passed_tests + 1
    end if

    ! Check the first two and last two rows of alpha
    if (all(abs(alpha(rows_to_check) - expected_alphas) <= tolerance)) then
        print *, "Alpha values matched expected values."
        passed_tests = passed_tests + 1
    else
        do i = 1, size(rows_to_check)
            if ((abs(alpha(rows_to_check(i)) - expected_alphas(i)) > tolerance) &
                            .or. (ieee_is_nan(alpha(rows_to_check(i))))) then
                print *, "Alpha mismatch, ", &
                         "Row: ", rows_to_check(i), &
                         " Expected: ", expected_alphas(i), &
                         " Actual: ", alpha(rows_to_check(i))
            end if
        end do
    end if

    ! Check the first two and last two rows of cl
    if (all(abs(cl(rows_to_check) - expected_cls) <= tolerance)) then
        print *, "Cl values matched expected values."
        passed_tests = passed_tests + 1
    else
        do i = 1, size(rows_to_check)
            if ((abs(cl(rows_to_check(i)) - expected_cls(i)) > tolerance) &
                            .or. (ieee_is_nan(cl(rows_to_check(i))))) then
                print *, "Cl mismatch, ", &
                         "Row: ", rows_to_check(i), &
                         " Expected: ", expected_cls(i), &
                         " Actual: ", cl(rows_to_check(i))
            end if
        end do
    end if

    ! Check the first two and last two rows of cd
    if (all(abs(cd(rows_to_check) - expected_cds) <= tolerance)) then
        print *, "Cd values matched expected values."
        passed_tests = passed_tests + 1
    else
        do i = 1, size(rows_to_check)
            if ((abs(cd(rows_to_check(i)) - expected_cds(i)) > tolerance) &
                            .or. (ieee_is_nan(cd(rows_to_check(i))))) then
                print *, "Cd mismatch, ", &
                         "Row: ", rows_to_check(i), &
                         " Expected: ", expected_cds(i), &
                         " Actual: ", cd(rows_to_check(i))
            end if
        end do
    end if

    ! Check the first two and last two rows of cdp
    if (all(abs(cdp(rows_to_check) - expected_cdps) <= tolerance)) then
        print *, "Cdp values matched expected values."
        passed_tests = passed_tests + 1
    else
        do i = 1, size(rows_to_check)
            if ((abs(cdp(rows_to_check(i)) - expected_cdps(i)) > tolerance) &
                            .or. (ieee_is_nan(cdp(rows_to_check(i))))) then
                print *, "Cdp mismatch, ", &
                         "Row: ", rows_to_check(i), &
                         " Expected: ", expected_cdps(i), &
                         " Actual: ", cdp(rows_to_check(i))
            end if
        end do
    end if

    ! Check the first two and last two rows of cm
    if (all(abs(cm(rows_to_check) - expected_cms) <= tolerance)) then
        print *, "Cm values matched expected values."
        passed_tests = passed_tests + 1
    else
        do i = 1, size(rows_to_check)
            if ((abs(cm(rows_to_check(i)) - expected_cms(i)) > tolerance) &
                            .or. (ieee_is_nan(cm(rows_to_check(i))))) then
                print *, "Cm mismatch, ", &
                         "Row: ", rows_to_check(i), &
                         " Expected: ", expected_cms(i), &
                         " Actual: ", cm(rows_to_check(i))
            end if
        end do
    end if

    ! Check the first two and last two rows of top_xtr
    if (all(abs(top_xtr(rows_to_check) - expected_top_xtrs) <= tolerance)) then
        print *, "Top_xtr values matched expected values."
        passed_tests = passed_tests + 1
    else
        do i = 1, size(rows_to_check)
            if ((abs(top_xtr(rows_to_check(i)) - expected_top_xtrs(i)) > tolerance) &
                            .or. (ieee_is_nan(top_xtr(rows_to_check(i))))) then
                print *, "Top_xtr mismatch, ", &
                         "Row: ", rows_to_check(i), &
                         " Expected: ", expected_top_xtrs(i), &
                         " Actual: ", top_xtr(rows_to_check(i))
            end if
        end do
    end if

    ! Check the first two and last two rows of bot_xtr
    if (all(abs(bot_xtr(rows_to_check) - expected_bot_xtrs) <= tolerance)) then
        print *, "Bot_xtr values matched expected values."
        passed_tests = passed_tests + 1
    else
        do i = 1, size(rows_to_check)
            if ((abs(bot_xtr(rows_to_check(i)) - expected_bot_xtrs(i)) > tolerance) &
                            .or. (ieee_is_nan(bot_xtr(rows_to_check(i))))) then
                print *, "Bot_xtr mismatch, ", &
                         "Row: ", rows_to_check(i), &
                         " Expected: ", expected_bot_xtrs(i), &
                         " Actual: ", bot_xtr(rows_to_check(i))
            end if
        end do
    end if

    print *, "Passed tests: ", passed_tests, "/", nr_tests

    if (passed_tests == nr_tests) then
        print *, "All tests passed successfully."
    end if

end program import_test