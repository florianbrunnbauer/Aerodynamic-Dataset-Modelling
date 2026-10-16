program test_coefficient_query
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_value, ieee_quiet_nan, ieee_positive_inf
    use types, only: aero_run_type, aero_dataset_type, representative_dataset_type, &
                     grouped_dataset_type, dataset_validation_result_type
    use coefficient_query
    use dataset_validation, only: validate_dataset
    use dataset_grouping, only: group_dataset
    use dataset_representative, only: build_representative_dataset

    implicit none

    type(aero_run_type) :: runs(3)
    type(aero_dataset_type) :: data, bad, short, empty, prepared
    type(representative_dataset_type) :: structure, bad_structure, short_structure, empty_structure, representatives
    type(grouped_dataset_type) :: grouped
    type(dataset_validation_result_type) :: validation
    real(real64) :: cl, cd, cm, alpha, mach, delta
    real(real64), parameter :: nominal(3) = [0.92_real64,0.7_real64,0.8_real64]
    character(len=6), parameter :: methods(3) = [character(len=6) :: 'linear','pchip','akima']
    real(real64) :: reference(5,3), nonlinear_x(6), nonlinear_y(6), queries(5)
    integer :: i, j, m, stat, checks, group_index, high_index, low_index

    checks = 0

    print '(a)', ''
    print '(a)', '=== test_coefficient_query (v2 prepared interface) ==='

    ! Same affine/reference tests as the original suite, now using indirect
    ! representative indices, unordered Mach entries, repeats, and multiple Re groups.
    do i = 1, 3
        runs(i)%info%test = 197
        runs(i)%info%run = i
        runs(i)%info%series = 1
        runs(i)%info%config = 2
        runs(i)%info%confts = 0
        runs(i)%info%conft = 0
        runs(i)%alpha = [0.0_real64,0.6_real64,1.5_real64,2.8_real64,4.0_real64]
        runs(i)%mach = nominal(i)+0.001_real64*runs(i)%alpha
        runs(i)%reynolds = 5.0e6_real64+0.0_real64*runs(i)%alpha
        runs(i)%cl = 0.1_real64*runs(i)%alpha+2.0_real64*runs(i)%mach
        runs(i)%cd = 0.01_real64+0.003_real64*runs(i)%alpha+0.02_real64*runs(i)%mach
        runs(i)%cm = -0.05_real64-0.007_real64*runs(i)%alpha+0.03_real64*runs(i)%mach
    end do

    allocate(data%runs(7))

    data%runs(1) = runs(2) ! unselected repeat: same Mach/Re, deliberately different coefficients
    data%runs(1)%cl = data%runs(1)%cl+100.0_real64
    data%runs(2) = runs(2) ! other Reynolds group
    data%runs(3) = runs(3) ! selected middle Mach
    data%runs(4) = runs(1) ! selected high Mach
    data%runs(5) = runs(2) ! selected low Mach
    data%runs(6) = runs(1) ! unselected high-Mach repeat
    data%runs(6)%cl = data%runs(6)%cl+100.0_real64
    data%runs(7) = runs(1) ! other Reynolds group

    do i = 1, 7
        data%runs(i)%info%run = i
    end do

    do i = 2, 7, 5
        data%runs(i)%reynolds = 30.0e6_real64
        data%runs(i)%cl = data%runs(i)%cl+10.0_real64
        data%runs(i)%cd = data%runs(i)%cd+0.1_real64
        data%runs(i)%cm = data%runs(i)%cm-0.2_real64
    end do

    allocate(structure%reynolds_groups(2))
    structure%reynolds_groups(1)%nominal_reynolds = 5.0e6_real64

    allocate(structure%reynolds_groups(1)%mach_groups(3))
    structure%reynolds_groups(1)%mach_groups(1)%nominal_mach = nominal(1)
    structure%reynolds_groups(1)%mach_groups(1)%run_index = 4
    structure%reynolds_groups(1)%mach_groups(2)%nominal_mach = nominal(2)
    structure%reynolds_groups(1)%mach_groups(2)%run_index = 5
    structure%reynolds_groups(1)%mach_groups(3)%nominal_mach = nominal(3)
    structure%reynolds_groups(1)%mach_groups(3)%run_index = 3
    structure%reynolds_groups(2)%nominal_reynolds = 30.0e6_real64

    allocate(structure%reynolds_groups(2)%mach_groups(2))
    structure%reynolds_groups(2)%mach_groups(1)%nominal_mach = nominal(1)
    structure%reynolds_groups(2)%mach_groups(1)%run_index = 7
    structure%reynolds_groups(2)%mach_groups(2)%nominal_mach = nominal(2)
    structure%reynolds_groups(2)%mach_groups(2)%run_index = 2

    do m = 1, 3
        do j = 0, 20
            alpha = real(j,real64)/5.0_real64
            mach = 0.75_real64+0.001_real64*alpha
            call query_coefficients(data,structure,1,alpha,mach,cl,cd,cm,stat,trim(methods(m)))
            call check(stat == query_ok,'intermediate query uses representatives only')
            call affine_values(alpha,mach)
        end do

        do i = 1, 3
            do j = 1, 5
                call query_coefficients(data,structure,1,runs(i)%alpha(j),runs(i)%mach(j), &
                                        cl,cd,cm,stat,trim(methods(m)))
                call check(stat == query_ok,'measured point succeeds')
                call close_to(cl,runs(i)%cl(j))
                call close_to(cd,runs(i)%cd(j))
                call close_to(cm,runs(i)%cm(j))
            end do
        end do

        call query_coefficients(data,structure,2,1.0_real64,0.751_real64,cl,cd,cm,stat,trim(methods(m)))
        call check(stat == query_ok,'select second Reynolds group')
        call close_to(cl,0.1_real64+2.0_real64*0.751_real64+10.0_real64)
        call close_to(cd,0.01_real64+0.003_real64+0.02_real64*0.751_real64+0.1_real64)
        call close_to(cm,-0.05_real64-0.007_real64+0.03_real64*0.751_real64-0.2_real64)
    end do

    call check(structure%reynolds_groups(1)%mach_groups(1)%run_index == 4,'structure order unchanged')
    call close_to(data%runs(1)%cl(1),runs(2)%cl(1)+100.0_real64)

    ! Exact sweep needs only its own alpha range; bridge a missing middle sweep.
    bad = data
    bad%runs(3)%alpha = bad%runs(3)%alpha-0.5_real64
    call query_coefficients(bad,structure,1,4.0_real64,runs(1)%mach(5),cl,cd,cm,stat)
    call check(stat == query_ok,'exact sweep ignores neighbor alpha domain')
    call close_to(cl,runs(1)%cl(5))

    do m = 1, 3
        call query_coefficients(bad,structure,1,4.0_real64,0.85_real64,cl,cd,cm,stat,trim(methods(m)))
        call check(stat == query_ok,'interpolate across unsupported middle sweep')
        call affine_values(4.0_real64,0.85_real64)
        call query_coefficients(bad,structure,1,4.0_real64,0.75_real64,cl,cd,cm,stat,trim(methods(m)))
        call check(stat == query_ok,'both sides of unsupported middle sweep are queryable')
        call affine_values(4.0_real64,0.75_real64)
    end do

    call query_coefficients(data,structure,1,-0.1_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_alpha_outside)

    call query_coefficients(data,structure,1,1.0_real64,0.65_real64,cl,cd,cm,stat)
    call failure(query_mach_outside)

    call query_coefficients(data,structure,1,1.0_real64,0.95_real64,cl,cd,cm,stat)
    call failure(query_mach_outside)

    call query_coefficients(data,structure,1,4.0_real64,0.702_real64,cl,cd,cm,stat)
    call failure(query_mach_outside) ! nominal Mach bounds must not replace measured coordinates

    call query_coefficients(data,structure,0,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_reynolds_group)

    call query_coefficients(data,structure,3,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_reynolds_group)

    call query_coefficients(empty,structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_empty_dataset)

    allocate(empty%runs(0))

    call query_coefficients(empty,structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_empty_dataset)

    call query_coefficients(data,empty_structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_empty_dataset)

    allocate(empty_structure%reynolds_groups(0))

    call query_coefficients(data,empty_structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_empty_dataset)

    deallocate(empty_structure%reynolds_groups)

    allocate(empty_structure%reynolds_groups(1))

    call query_coefficients(data,empty_structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_empty_dataset)

    allocate(empty_structure%reynolds_groups(1)%mach_groups(0))

    call query_coefficients(data,empty_structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_empty_dataset)

    bad_structure = structure
    bad_structure%reynolds_groups(1)%mach_groups(2)%run_index = 0

    call query_coefficients(data,bad_structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_structure)

    bad_structure%reynolds_groups(1)%mach_groups(2)%run_index = 8

    call query_coefficients(data,bad_structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_structure)

    ! An invalid reference in a different, unselected group is never dereferenced.
    bad_structure = structure
    bad_structure%reynolds_groups(2)%mach_groups(1)%run_index = 0

    call query_coefficients(data,bad_structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat)
    call check(stat == query_ok,'unselected group is not inspected')

    call affine_values(1.0_real64,0.75_real64)

    call query_coefficients(data,structure,1,1.0_real64,0.75_real64,cl,cd,cm,stat,'spline')
    call failure(query_invalid_method)

    call query_coefficients(data,structure,1,ieee_value(0.0_real64,ieee_quiet_nan), &
                            0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_input)

    call query_coefficients(data,structure,1,1.0_real64,ieee_value(0.0_real64,ieee_positive_inf),cl,cd,cm,stat)
    call failure(query_invalid_input)

    call query_coefficients(data,structure,1,1.0_real64,0.0_real64,cl,cd,cm,stat)
    call failure(query_invalid_input)

    call query_coefficients(data,structure,1,1.0_real64,-0.1_real64,cl,cd,cm,stat)
    call failure(query_invalid_input)

    ! Pointwise crossings/duplicates remain possible even with classified sweep means.
    bad = data
    bad%runs(3)%mach = [0.83_real64,0.83_real64,0.68_real64,0.83_real64,0.83_real64]

    call validate_dataset(bad,validation)
    call check(validation%is_valid,'pointwise crossing passes static data validation')
    call group_dataset(bad,grouped,stat)
    call check(stat == 0,'pointwise crossing passes mean-Mach grouping')
    call query_coefficients(bad,structure,1,1.5_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_mach_grid)

    bad = data
    delta = bad%runs(3)%mach(3)-bad%runs(5)%mach(3)
    bad%runs(3)%mach = bad%runs(3)%mach+delta/4.0_real64
    bad%runs(3)%mach(3) = bad%runs(5)%mach(3)

    call query_coefficients(bad,structure,1,1.5_real64,0.75_real64,cl,cd,cm,stat)
    call failure(query_invalid_mach_grid)

    ! Minimum method support is query-specific: upstream validation allows two points.
    allocate(short%runs(1),short_structure%reynolds_groups(1))
    short%runs(1) = runs(1)
    short%runs(1)%alpha = runs(1)%alpha(:2)
    short%runs(1)%mach = runs(1)%mach(:2)
    short%runs(1)%reynolds = runs(1)%reynolds(:2)
    short%runs(1)%cl = runs(1)%cl(:2)
    short%runs(1)%cd = runs(1)%cd(:2)
    short%runs(1)%cm = runs(1)%cm(:2)
    short_structure%reynolds_groups(1)%nominal_reynolds = 5.0e6_real64

    allocate(short_structure%reynolds_groups(1)%mach_groups(1))
    short_structure%reynolds_groups(1)%mach_groups(1)%nominal_mach = nominal(1)
    short_structure%reynolds_groups(1)%mach_groups(1)%run_index = 1

    call query_coefficients(short,short_structure,1,0.3_real64,0.9203_real64,cl,cd,cm,stat)
    call failure(query_insufficient_points)

    do m = 1, 2
        call query_coefficients(short,short_structure,1,0.3_real64,0.9203_real64,cl,cd,cm,stat,trim(methods(m)))
        call check(stat == query_ok,'two-point exact sweep for linear/PCHIP')
        call affine_values(0.3_real64,0.9203_real64)
    end do

    call query_coefficients(short,short_structure,1,0.3_real64,0.91_real64,cl,cd,cm,stat,'linear')
    call failure(query_mach_outside)

    mach = sum(runs(3)%mach)/5.0_real64

    call query_coefficients(data,structure,1,0.6_real64,mach,cl,cd,cm,stat,use_mean_mach=.true.)
    call check(stat == query_ok,'mean Mach option uses measured mean, not nominal')
    call close_to(cl,runs(3)%cl(2))

    nonlinear_x = [0.0_real64,0.6_real64,1.5_real64,2.0_real64,3.8_real64,5.0_real64]
    nonlinear_y = [0.0_real64,1.0_real64,1.5_real64,1.4_real64,2.0_real64,1.8_real64]
    queries = [0.2_real64,0.9_real64,1.8_real64,2.7_real64,4.6_real64]
    reference(:,1) = [0.3333333333333333_real64,1.1666666666666667_real64,1.44_real64, &
                       1.6333333333333333_real64,1.8666666666666667_real64]
    reference(:,2) = [0.40859940400170286_real64,1.244572158365262_real64,1.4352_real64, &
                       1.6016460905349796_real64,1.9170370370370373_real64]
    reference(:,3) = [0.41211052322163438_real64,1.2606654273320943_real64,1.4286541975603924_real64, &
                       1.6207416570629056_real64,1.9326164874551972_real64]

    bad = data

    do i = 1, 3
        j = structure%reynolds_groups(1)%mach_groups(i)%run_index
        bad%runs(j)%alpha = nonlinear_x
        bad%runs(j)%mach = nominal(i)+0.0_real64*nonlinear_x
        bad%runs(j)%reynolds = 5.0e6_real64+0.0_real64*nonlinear_x
        bad%runs(j)%cl = nonlinear_y+2.0_real64*nominal(i)
        bad%runs(j)%cd = nonlinear_y/10.0_real64+0.02_real64*nominal(i)
        bad%runs(j)%cm = -0.1_real64*nonlinear_y+0.03_real64*nominal(i)
    end do

    do m = 1, 3
        do j = 1, 5
            call query_coefficients(bad,structure,1,queries(j),0.75_real64,cl,cd,cm,stat,trim(methods(m)))
            call check(stat == query_ok,'nonlinear two-sweep query')
            call close_to(cl,reference(j,m)+1.5_real64)
            call close_to(cd,reference(j,m)/10.0_real64+0.015_real64)
            call close_to(cm,-0.1_real64*reference(j,m)+0.0225_real64)
        end do
    end do

    ! Integration with the actual preparation modules, not a mock structure.
    ! Shorten repeated runs so representative selection must choose the full sweeps.
    prepared = data
    call trim_run(prepared%runs(1),4)
    call trim_run(prepared%runs(6),4)
    call validate_dataset(prepared,validation)
    call check(validation%is_valid,'preparation dataset validates')

    call group_dataset(prepared,grouped,stat)
    call check(stat == 0,'actual grouping accepts two Reynolds groups and repeats')

    call build_representative_dataset(prepared,grouped,representatives,stat)
    call check(stat == 0,'actual representative selection succeeds')

    do group_index = 1, size(representatives%reynolds_groups)

        if (representatives%reynolds_groups(group_index)%nominal_reynolds /= 5.0e6_real64) cycle

        do j = 1, size(representatives%reynolds_groups(group_index)%mach_groups)
            i = representatives%reynolds_groups(group_index)%mach_groups(j)%run_index
            call check(i /= 1 .and. i /= 6,'short repeats are not representatives')
        end do

        do m = 1, 3
            call query_coefficients(prepared,representatives,group_index,1.0_real64,0.751_real64, &
                                    cl,cd,cm,stat,trim(methods(m)))
            call check(stat == query_ok,'query works with actual pipeline output')
            call affine_values(1.0_real64,0.751_real64)
        end do

    end do

    ! Changing preparation's representative changes the query; it is not reselected.
    bad_structure = structure
    bad_structure%reynolds_groups(1)%mach_groups(2)%run_index = 1

    call query_coefficients(data,bad_structure,1,0.6_real64,runs(2)%mach(2),cl,cd,cm,stat)
    call check(stat == query_ok,'caller-selected representative is authoritative')
    call close_to(cl,runs(2)%cl(2)+100.0_real64)

    ! Structure references are positions in data, not CRM metadata run IDs.
    bad = data
    do i = 1, size(bad%runs)
        bad%runs(i)%info%run = 1000+i
    end do

    call query_coefficients(bad,structure,1,1.0_real64,0.751_real64,cl,cd,cm,stat)
    call check(stat == query_ok,'dataset indices are independent of metadata run IDs')
    call affine_values(1.0_real64,0.751_real64)

    ! Nominal label lookup does not change data%runs or reorder the caller's structure.
    high_index = structure%reynolds_groups(1)%mach_groups(1)%run_index
    low_index = structure%reynolds_groups(1)%mach_groups(2)%run_index

    call check(high_index == 4 .and. low_index == 5,'indices preserved after all queries')
    call test_supported_gaps()

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

    end subroutine check

    subroutine close_to(actual,expected)

        real(real64),intent(in) :: actual,expected

        call check(abs(actual-expected)<1.0e-12_real64,'coefficient value')

    end subroutine close_to

    subroutine affine_values(a,mach_value)

        real(real64),intent(in) :: a,mach_value

        call close_to(cl,0.1_real64*a+2.0_real64*mach_value)
        call close_to(cd,0.01_real64+0.003_real64*a+0.02_real64*mach_value)
        call close_to(cm,-0.05_real64-0.007_real64*a+0.03_real64*mach_value)

    end subroutine affine_values

    subroutine failure(expected_status)

        integer,intent(in) :: expected_status

        if(stat/=expected_status)print '(a,2i4)', 'Actual/expected status: ',stat,expected_status
        call check(stat == expected_status,'expected rejection status')
        call check(ieee_is_nan(cl).and.ieee_is_nan(cd).and.ieee_is_nan(cm),'failure outputs are NaNs')

    end subroutine failure

    subroutine trim_run(run,n)

        type(aero_run_type),intent(inout) :: run
        integer,intent(in) :: n

        run%alpha = run%alpha(:n)
        run%mach = run%mach(:n)
        run%reynolds = run%reynolds(:n)
        run%cl = run%cl(:n)
        run%cd = run%cd(:n)
        run%cm = run%cm(:n)
    end subroutine trim_run

    subroutine test_supported_gaps()
        type(aero_dataset_type) :: gap_data
        type(representative_dataset_type) :: gap_structure
        real(real64), parameter :: levels(5) = &
            [0.70_real64,0.75_real64,0.80_real64,0.85_real64,0.86_real64]
        real(real64), parameter :: full_alpha(5) = &
            [-1.0_real64,0.0_real64,1.0_real64,2.0_real64,3.0_real64]
        integer, parameter :: permutations(5) = [5,2,1,4,3]
        integer, parameter :: patterns(8) = [0,1,3,5,10,17,21,31]
        integer :: p, mask, mode, method, q, station, entry, low, high, exact
        real(real64) :: query_label, shift, expected, weight, change

        allocate(gap_data%runs(5),gap_structure%reynolds_groups(1))

        gap_structure%reynolds_groups(1)%nominal_reynolds = 5.0e6_real64

        allocate(gap_structure%reynolds_groups(1)%mach_groups(5))

        do station = 1, 5
            gap_data%runs(station) = runs(2)
            gap_data%runs(station)%info%run = 100+station
            ! Quadratic Mach dependence makes the choice of nearest bracket observable.
            gap_data%runs(station)%cl = levels(station)**2
            gap_data%runs(station)%cd = 0.01_real64+0.1_real64*levels(station)**2
            gap_data%runs(station)%cm = -0.05_real64*levels(station)**2
            entry = permutations(station)
            gap_structure%reynolds_groups(1)%mach_groups(station)%nominal_mach = levels(entry)
            gap_structure%reynolds_groups(1)%mach_groups(station)%run_index = entry
        end do

        ! Covers no support, one sweep, consecutive support, one/multiple missing
        ! interior sweeps, missing edge sweeps, and three separated supported sweeps.
        do p = 1, size(patterns)

            mask = patterns(p)

            do station = 1, 5
                if (btest(mask,station-1)) then
                    gap_data%runs(station)%alpha = full_alpha
                else
                    gap_data%runs(station)%alpha = &
                        [0.0_real64,0.1_real64,0.2_real64,0.3_real64,0.4_real64]
                end if
                gap_data%runs(station)%mach = levels(station)+0.0001_real64*gap_data%runs(station)%alpha
            end do

            do mode = 1, 2

                shift = 0.0002_real64 ! measured Mach at alpha = 2
                if (mode == 2) shift = 0.0001_real64 ! mean measured Mach of supported sweeps
                do method = 1, 3
                    do q = 0, 40
                        query_label = 0.68_real64+real(q,real64)*0.005_real64
                        ! Independent bracket oracle: inspect eligible nominal levels
                        ! directly; their measured coordinates share a known shift.
                        low = 0; high = 0; exact = 0

                        do station = 1, 5
                            if (.not. btest(mask,station-1)) cycle
                            if (abs(query_label-levels(station)) < 1.0e-12_real64) then
                                exact = station
                            else if (levels(station) < query_label) then
                                low = station
                            else if (high == 0) then
                                high = station
                            end if
                        end do

                        call query_coefficients(gap_data,gap_structure,1,2.0_real64,query_label+shift, &
                            cl,cd,cm,stat,trim(methods(method)),use_mean_mach=mode == 2)

                        if (exact /= 0) then
                            expected = levels(exact)**2
                        else if (low /= 0 .and. high /= 0) then
                            weight = (query_label-levels(low))/(levels(high)-levels(low))
                            expected = (1.0_real64-weight)*levels(low)**2+weight*levels(high)**2
                        else
                            call check(stat /= query_ok,'missing supported bracket rejects extrapolation')
                            call check(ieee_is_nan(cl).and.ieee_is_nan(cd).and.ieee_is_nan(cm), &
                                       'gap rejection leaves NaN outputs')
                            cycle
                        end if

                        call check(stat == query_ok,'nearest supported bracket succeeds across gaps')
                        call close_to(cl,expected)
                        call close_to(cd,0.01_real64+0.1_real64*expected)
                        call close_to(cm,-0.05_real64*expected)
                    end do
                end do
            end do
        end do

        ! Check the newly adjacent supported sweeps, even when three entries between
        ! them lack alpha support. Preserve the high sweep's mean Mach classification.
        do station = 2, 4
            gap_data%runs(station)%alpha = gap_data%runs(station)%alpha-10.0_real64
        end do

        change = gap_data%runs(5)%mach(4)-0.69_real64
        gap_data%runs(5)%mach = gap_data%runs(5)%mach+change/4.0_real64
        gap_data%runs(5)%mach(4) = 0.69_real64

        call query_coefficients(gap_data,gap_structure,1,2.0_real64,0.75_real64,cl,cd,cm,stat)
        call failure(query_invalid_mach_grid)

        gap_data%runs(5)%mach = levels(5)+0.0001_real64*full_alpha
        change = gap_data%runs(5)%mach(4)-gap_data%runs(1)%mach(4)
        gap_data%runs(5)%mach = gap_data%runs(5)%mach+change/4.0_real64
        gap_data%runs(5)%mach(4) = gap_data%runs(1)%mach(4)

        call query_coefficients(gap_data,gap_structure,1,2.0_real64,0.75_real64,cl,cd,cm,stat)
        call failure(query_invalid_mach_grid)
        
    end subroutine test_supported_gaps

end program test_coefficient_query
