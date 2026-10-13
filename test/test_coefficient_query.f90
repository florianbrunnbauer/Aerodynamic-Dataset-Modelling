program test_coefficient_query
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_value, ieee_quiet_nan
    use types, only: aero_run_type
    use coefficient_query

    implicit none

    type(aero_run_type) :: runs(3), bad(3), short(1), empty(0)
    real(real64) :: cl, cd, cm, alpha, mach
    real(real64), parameter :: nominal(3) = [0.9_real64,0.7_real64,0.8_real64]
    character(len=6), parameter :: methods(3) = [character(len=6) :: 'linear','pchip','akima']
    real(real64) :: reference(5,3), nonlinear_x(6), nonlinear_y(6), queries(5)
    integer :: i, j, m, stat, checks

    checks = 0
    print '(a)', ''
    print '(a)', '=== test_coefficient_query ==='

    ! Unsorted sweeps and drifting Mach(alpha). Affine surfaces are reproduced
    ! exactly, independently of the selected alpha method.
    do i = 1, 3
        allocate(runs(i)%alpha(5),runs(i)%mach(5),runs(i)%reynolds(5), &
                 runs(i)%cl(5),runs(i)%cd(5),runs(i)%cm(5))
        runs(i)%alpha = [0.0_real64,0.6_real64,1.5_real64,2.8_real64,4.0_real64]
        runs(i)%mach = nominal(i)+0.001_real64*runs(i)%alpha
        runs(i)%reynolds = 5.0e6_real64
        runs(i)%cl = 0.1_real64*runs(i)%alpha+2.0_real64*runs(i)%mach
        runs(i)%cd = 0.01_real64+0.003_real64*runs(i)%alpha+0.02_real64*runs(i)%mach
        runs(i)%cm = -0.05_real64-0.007_real64*runs(i)%alpha+0.03_real64*runs(i)%mach
    end do

    do m = 1, 3
        do j = 0, 20
            alpha = real(j,real64)/5.0_real64
            mach = 0.75_real64+0.001_real64*alpha
            call query_coefficients(runs,alpha,mach,cl,cd,cm,stat,alpha_method=trim(methods(m)))
            call check(stat == query_ok, 'intermediate query succeeds')
            call close_to(cl,0.1_real64*alpha+2.0_real64*mach)
            call close_to(cd,0.01_real64+0.003_real64*alpha+0.02_real64*mach)
            call close_to(cm,-0.05_real64-0.007_real64*alpha+0.03_real64*mach)
        end do

        do i = 1, 3
            do j = 1, 5
                call query_coefficients(runs,runs(i)%alpha(j),runs(i)%mach(j),cl,cd,cm,stat,trim(methods(m)))
                call check(stat == query_ok, 'measured point succeeds')
                call close_to(cl,runs(i)%cl(j))
                call close_to(cd,runs(i)%cd(j))
                call close_to(cm,runs(i)%cm(j))
            end do
        end do

    end do

    ! Exact sweep remains valid when a neighboring sweep has a smaller domain.
    bad = runs
    bad(3)%alpha = bad(3)%alpha-0.5_real64

    call query_coefficients(bad,4.0_real64,runs(1)%mach(5),cl,cd,cm,stat)
    call check(stat == query_ok,'exact sweep ignores neighbor alpha domain')
    call close_to(cl,runs(1)%cl(5))
    call query_coefficients(bad,4.0_real64,0.85_real64,cl,cd,cm,stat)
    call failure(query_alpha_outside)

    ! No bridging across the unavailable intermediate sweep.
    call query_coefficients(bad,4.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_alpha_outside)

    call query_coefficients(runs,-0.1_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_alpha_outside)

    call query_coefficients(runs,1.0_real64,0.65_real64,cl,cd,cm,stat)
    call failure(query_mach_outside)

    call query_coefficients(runs,1.0_real64,0.95_real64,cl,cd,cm,stat)
    call failure(query_mach_outside)
    
    ! Measured-Mach range differs slightly from the mean range.
    call query_coefficients(runs,4.0_real64,0.702_real64,cl,cd,cm,stat)
    call failure(query_mach_outside)

    call query_coefficients(empty,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_empty_dataset)

    call query_coefficients(runs,1.0_real64,0.75_real64,cl,cd,cm,stat,'spline')
    call failure(query_invalid_method)

    call query_coefficients(runs,ieee_value(0.0_real64,ieee_quiet_nan),0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_input)

    bad = runs

    bad(1)%alpha(2) = bad(1)%alpha(1)

    call query_coefficients(bad,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_data)

    bad = runs

    deallocate(bad(1)%cd)
    call query_coefficients(bad,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_data)

    bad = runs

    bad(1)%cl(2) = ieee_value(0.0_real64,ieee_quiet_nan)
    call query_coefficients(bad,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_data)

    bad = runs

    bad(1)%mach = runs(2)%mach
    call query_coefficients(bad,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_mach_grid)

    bad = runs

    bad(1)%info%config = bad(2)%info%config+1
    call query_coefficients(bad,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_incompatible_runs)

    bad = runs

    bad(1)%reynolds = 10.0e6_real64
    call query_coefficients(bad,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_incompatible_runs)

    short(1) = runs(1)
    short(1)%alpha = runs(1)%alpha(:2)
    short(1)%mach = runs(1)%mach(:2)
    short(1)%reynolds = runs(1)%reynolds(:2)
    short(1)%cl = runs(1)%cl(:2)
    short(1)%cd = runs(1)%cd(:2)
    short(1)%cm = runs(1)%cm(:2)

    call query_coefficients(short,0.3_real64,0.9003_real64,cl,cd,cm,stat)
    call failure(query_insufficient_points)

    call query_coefficients(short,0.3_real64,0.9003_real64,cl,cd,cm,stat,'pchip')
    call check(stat == query_ok,'two-point PCHIP exact sweep')
    call close_to(cl,0.03_real64+1.8006_real64)

    ! Mean-Mach option: exact sweep at its mean, independent of queried alpha.
    mach = sum(runs(3)%mach)/5.0_real64
    call query_coefficients(runs,0.6_real64,mach,cl,cd,cm,stat,use_mean_mach=.true.)
    call check(stat == query_ok,'mean Mach mode exact sweep')
    call close_to(cl,runs(3)%cl(2))

    ! Independent nonlinear references: SciPy 1.17, on an uneven alpha grid.
    nonlinear_x = [0.0_real64,0.6_real64,1.5_real64,2.0_real64,3.8_real64,5.0_real64]
    nonlinear_y = [0.0_real64,1.0_real64,1.5_real64,1.4_real64,2.0_real64,1.8_real64]
    queries = [0.2_real64,0.9_real64,1.8_real64,2.7_real64,4.6_real64]
    reference(:,1) = [0.3333333333333333_real64,1.1666666666666667_real64,1.44_real64, &
                       1.6333333333333333_real64,1.8666666666666667_real64]
    reference(:,2) = [0.40859940400170286_real64,1.244572158365262_real64,1.4352_real64, &
                       1.6016460905349796_real64,1.9170370370370373_real64]
    reference(:,3) = [0.41211052322163438_real64,1.2606654273320943_real64,1.4286541975603924_real64, &
                       1.6207416570629056_real64,1.9326164874551972_real64]

    bad = runs

    do i = 1, 3
        bad(i)%alpha = nonlinear_x
        bad(i)%mach = nominal(i)+0.0_real64*nonlinear_x
        bad(i)%reynolds = 5.0e6_real64+0.0_real64*nonlinear_x
        bad(i)%cl = nonlinear_y+2.0_real64*nominal(i)
        bad(i)%cd = nonlinear_y/10.0_real64+0.02_real64*nominal(i)
        bad(i)%cm = -0.1_real64*nonlinear_y+0.03_real64*nominal(i)
    end do

    do m = 1, 3
        do j = 1, 5
            call query_coefficients(bad,queries(j),0.75_real64,cl,cd,cm,stat,trim(methods(m)))
            call check(stat == query_ok,'nonlinear two-sweep query')
            call close_to(cl,reference(j,m)+1.5_real64)
            call close_to(cd,reference(j,m)/10.0_real64+0.015_real64)
            call close_to(cm,-0.1_real64*reference(j,m)+0.0225_real64)
        end do
    end do
    print '(a,i0,a)', 'PASS: ',checks,' assertions' 

contains

    subroutine check(condition,label)

        logical,intent(in) :: condition
        character(len=*),intent(in) :: label

        checks = checks+1

        if (.not. condition) then
            print '(a)', 'FAIL: '//label
            error stop 1
        end if

    end subroutine

    subroutine close_to(actual,expected)

        real(real64),intent(in) :: actual,expected

        call check(abs(actual-expected)<1.0e-12_real64,'coefficient value')

    end subroutine

    subroutine failure(expected_status)

        integer,intent(in) :: expected_status

        if(stat/=expected_status)print '(a,2i4)', 'Actual/expected status: ',stat,expected_status
        call check(stat == expected_status,'expected rejection status')
        call check(ieee_is_nan(cl).and.ieee_is_nan(cd).and.ieee_is_nan(cm),'failure outputs are NaNs')

    end subroutine
    
end program test_coefficient_query
