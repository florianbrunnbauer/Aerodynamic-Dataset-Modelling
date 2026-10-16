program test_flight_condition_validation
    use iso_fortran_env, only: real64
    use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_value, ieee_quiet_nan
    use types, only: aero_run_type, aero_dataset_type, representative_dataset_type, &
                     grouped_dataset_type, dataset_validation_result_type, &
                     central_flight_condition_type => flight_condition_type
    use standard_atmosphere, only: atmosphere_state_type, calculate_atmosphere, atmosphere_ok, atmosphere_outside_range
    use coefficient_query, only: query_alpha_outside, query_mach_outside, query_invalid_method
    use dataset_validation, only: validate_dataset
    use dataset_grouping, only: group_dataset
    use dataset_representative, only: build_representative_dataset
    use flight_condition_validation

    implicit none

    type(aero_run_type) :: runs(2)
    type(aero_dataset_type) :: data, bad, empty
    type(representative_dataset_type) :: structure, bad_structure, empty_structure, representatives
    type(grouped_dataset_type) :: grouped
    type(dataset_validation_result_type) :: validation
    type(atmosphere_state_type) :: air
    ! Verify that the validator accepts the shared types.f90 declaration directly.
    type(central_flight_condition_type) :: condition
    real(real64) :: length, altitude, nan, endpoint_re, nominal, trial_length
    character(len=6),parameter :: methods(3) = [character(len=6) :: 'linear','pchip','akima']
    integer :: i,m,stat,checks,g
    
    checks = 0
    nominal = 5.0e6_real64
    nan = ieee_value(0.0_real64,ieee_quiet_nan)
    
    print '(a)', ''
    print '(a)', '=== test_flight_condition_validation ==='

    call calculate_atmosphere(10000.0_real64,air,stat)
    call check(stat == atmosphere_ok,'reference atmosphere')
    ! Synthetic geometry chosen once to make Re=5e6 at a known test condition.
    ! Production calls must supply fixed actual geometry, never adjust it to pass.
    length = nominal*air%dynamic_viscosity/(air%density*0.75_real64*air%speed_of_sound)

    do i = 1, 2
        allocate(runs(i)%alpha(5),runs(i)%mach(5),runs(i)%reynolds(5), &
                 runs(i)%cl(5),runs(i)%cd(5),runs(i)%cm(5))
        runs(i)%info%test = 197
        runs(i)%info%run = i
        runs(i)%info%series = 1
        runs(i)%info%config = 1
        runs(i)%info%confts = 1
        runs(i)%info%conft = 99
        runs(i)%alpha = [0.0_real64,0.5_real64,1.5_real64,2.5_real64,4.0_real64]
        runs(i)%mach = 0.6_real64+0.1_real64*real(i,real64)
        runs(i)%reynolds = nominal
        runs(i)%cl = 0.1_real64*runs(i)%alpha+2.0_real64*runs(i)%mach
        runs(i)%cd = 0.01_real64+0.003_real64*runs(i)%alpha+0.02_real64*runs(i)%mach
        runs(i)%cm = -0.05_real64-0.007_real64*runs(i)%alpha+0.03_real64*runs(i)%mach
    end do
    ! Full data contains repeats and another Reynolds group; only the selected
    ! representative indices may affect acceptance, diagnostics, and coefficients.
    allocate(data%runs(5))
    data%runs(1) = runs(2)
    data%runs(2) = runs(1)
    data%runs(3) = runs(1)
    data%runs(4) = runs(1)
    data%runs(5) = runs(2)

    do i = 1, 5
        data%runs(i)%info%run = 100+i
    end do

    data%runs(3)%cl = data%runs(3)%cl+100.0_real64
    data%runs(3)%reynolds = nominal*1.01_real64

    call trim_run(data%runs(3),4)

    do i = 2, 5, 3
        data%runs(i)%reynolds = 30.0e6_real64
        data%runs(i)%cl = data%runs(i)%cl+10.0_real64
    end do

    allocate(structure%reynolds_groups(2))
    structure%reynolds_groups(1)%nominal_reynolds = nominal
    allocate(structure%reynolds_groups(1)%mach_groups(2))
    structure%reynolds_groups(1)%mach_groups(1)%nominal_mach = 0.8_real64
    structure%reynolds_groups(1)%mach_groups(1)%run_index = 1
    structure%reynolds_groups(1)%mach_groups(2)%nominal_mach = 0.7_real64
    structure%reynolds_groups(1)%mach_groups(2)%run_index = 4
    structure%reynolds_groups(2)%nominal_reynolds = 30.0e6_real64
    allocate(structure%reynolds_groups(2)%mach_groups(2))
    structure%reynolds_groups(2)%mach_groups(1)%nominal_mach = 0.7_real64
    structure%reynolds_groups(2)%mach_groups(1)%run_index = 2
    structure%reynolds_groups(2)%mach_groups(2)%nominal_mach = 0.8_real64
    structure%reynolds_groups(2)%mach_groups(2)%run_index = 5

    do m = 1, 3
        call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                       0.0_real64,condition,stat,alpha_method=trim(methods(m)))
        call check(stat == flight_ok.and.condition%accepted,'matched condition accepted')
        call close_to(condition%speed,0.75_real64*air%speed_of_sound,1.0e-12_real64)
        call close_to(condition%dynamic_pressure,0.5_real64*air%density*condition%speed**2,1.0e-12_real64)
        call close_to(condition%reynolds,nominal,1.0e-12_real64)
        call close_to(condition%cl,1.6_real64,1.0e-12_real64)
        call close_to(condition%cd,0.028_real64,1.0e-12_real64)
        call close_to(condition%cm,-0.0345_real64,1.0e-12_real64)
        call close_to(condition%observed_reynolds_min,nominal,1.0e-12_real64)
        call close_to(condition%observed_reynolds_max,nominal,1.0e-12_real64)
    end do

    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat,use_mean_mach=.true.)
    call check(stat == flight_ok,'optional mean-Mach forwarding')
    trial_length = length*1.02_real64
    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,trial_length, &
                                   0.01_real64,condition,stat)
    call rejected(flight_reynolds_mismatch)
    call close_to(condition%relative_reynolds_mismatch,0.02_real64,1.0e-11_real64)
    call check(condition%coefficient_stat == flight_not_evaluated,'query not run after Re rejection')
    call check(condition%speed > 0.0_real64.and.condition%dynamic_pressure > 0.0_real64,'physics diagnostics retained')
    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,trial_length, &
                                   0.02_real64,condition,stat)
    call check(stat == flight_ok,'relative tolerance boundary inclusive')

    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,9.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_coefficient_failure)
    call check(condition%coefficient_stat == query_alpha_outside,'alpha failure forwarded')
    ! Length/Mach combination keeps the same Re for this out-of-grid Mach test.
    call validate_flight_condition(data,structure,1,10000.0_real64,0.9_real64,1.0_real64,length*0.75_real64/0.9_real64, &
                                   0.001_real64,condition,stat)
    call rejected(flight_coefficient_failure)
    call check(condition%coefficient_stat == query_mach_outside,'Mach failure forwarded')
    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat,'spline')
    call rejected(flight_coefficient_failure)
    call check(condition%coefficient_stat == query_invalid_method,'method failure forwarded')
    call validate_flight_condition(data,structure,1,32001.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_atmosphere_failure)
    call check(condition%atmosphere_stat == atmosphere_outside_range,'atmosphere status retained')
    call validate_flight_condition(data,structure,1,nan,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_input)
    call validate_flight_condition(data,structure,1,10000.0_real64,0.0_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_input)
    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,-length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_input)
    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   -0.001_real64,condition,stat)
    call rejected(flight_invalid_input)
    call validate_flight_condition(data,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   1.0_real64,condition,stat)
    call rejected(flight_invalid_input)
    call validate_flight_condition(empty,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_dataset)
    call validate_flight_condition(data,structure,1,10000.0_real64,huge(1.0_real64),1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_numeric_failure)

    ! The group determines nominal Re, not the first run or a caller-supplied label.
    call validate_flight_condition(data,structure,2,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_reynolds_mismatch)
    call close_to(condition%nominal_reynolds,30.0e6_real64,1.0e-12_real64)
    call close_to(condition%observed_reynolds_min,30.0e6_real64,1.0e-12_real64)
    call close_to(condition%relative_reynolds_mismatch,5.0_real64/6.0_real64,1.0e-12_real64)

    do m = 1, 3
        call validate_flight_condition(data,structure,2,10000.0_real64,0.75_real64,1.0_real64,6.0_real64*length, &
                                       0.0_real64,condition,stat,trim(methods(m)))
        call check(stat == flight_ok.and.condition%accepted,'second nominal group accepted')
        call close_to(condition%cl,11.6_real64,1.0e-12_real64)
        call close_to(condition%nominal_reynolds,30.0e6_real64,1.0e-12_real64)
        call close_to(condition%reynolds,30.0e6_real64,1.0e-12_real64)
        call close_to(condition%observed_reynolds_max,30.0e6_real64,1.0e-12_real64)
    end do

    ! Measured Re extrema describe representative sweeps without redefining nominal Re.
    bad = data
    bad%runs(1)%reynolds = nominal+[-1.0e4_real64,0.0_real64,1.0e4_real64,0.0_real64,0.0_real64]
    bad%runs(4)%reynolds = nominal+[0.0_real64,0.0_real64,2.0e4_real64,0.0_real64,0.0_real64]

    call validate_flight_condition(bad,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.0_real64,condition,stat)
    call check(stat == flight_ok,'nominal group survives measured Reynolds variation')
    call close_to(condition%nominal_reynolds,nominal,1.0e-12_real64)
    call close_to(condition%observed_reynolds_min,nominal-1.0e4_real64,1.0e-12_real64)
    call close_to(condition%observed_reynolds_max,nominal+2.0e4_real64,1.0e-12_real64)

    call validate_flight_condition(data,structure,0,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_reynolds_group)
    call validate_flight_condition(data,structure,3,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_reynolds_group)
    call validate_flight_condition(data,empty_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_dataset)
    allocate(empty%runs(0),empty_structure%reynolds_groups(0))
    call validate_flight_condition(empty,structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_dataset)
    call validate_flight_condition(data,empty_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_dataset)
    deallocate(empty_structure%reynolds_groups)
    allocate(empty_structure%reynolds_groups(1))
    call validate_flight_condition(data,empty_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_dataset)
    allocate(empty_structure%reynolds_groups(1)%mach_groups(0))
    call validate_flight_condition(data,empty_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_dataset)
    bad_structure = structure
    bad_structure%reynolds_groups(1)%mach_groups(2)%run_index = 0
    call validate_flight_condition(data,bad_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_structure)
    bad_structure%reynolds_groups(1)%mach_groups(2)%run_index = 6
    call validate_flight_condition(data,bad_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_structure)
    bad_structure = structure
    bad_structure%reynolds_groups(1)%nominal_reynolds = -1.0_real64
    call validate_flight_condition(data,bad_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)
    call rejected(flight_invalid_structure)

    ! Missing intermediate alpha support is bridged through the v2 query.
    bad = data
    bad%runs(3) = runs(1)
    bad%runs(3)%alpha = [0.0_real64,0.1_real64,0.2_real64,0.3_real64,0.4_real64]
    bad%runs(3)%mach = 0.75_real64
    bad_structure = structure
    deallocate(bad_structure%reynolds_groups(1)%mach_groups)
    allocate(bad_structure%reynolds_groups(1)%mach_groups(3))
    bad_structure%reynolds_groups(1)%mach_groups(:2) = structure%reynolds_groups(1)%mach_groups
    bad_structure%reynolds_groups(1)%mach_groups(3)%nominal_mach = 0.75_real64
    bad_structure%reynolds_groups(1)%mach_groups(3)%run_index = 3

    do m = 1, 3
        call validate_flight_condition(bad,bad_structure,1,10000.0_real64,0.75_real64,1.0_real64,length, &
                                       0.0_real64,condition,stat,trim(methods(m)))
        call check(stat == flight_ok.and.condition%accepted,'flight query bridges missing middle sweep')
        call close_to(condition%cl,1.6_real64,1.0e-12_real64)
    end do

    ! Build structure with the actual preparation modules, then validate flight conditions.
    call validate_dataset(data,validation)

    call check(validation%is_valid,'full dataset passes upstream validation')

    call group_dataset(data,grouped,stat)

    call check(stat == 0,'full dataset groups successfully')

    call build_representative_dataset(data,grouped,representatives,stat)

    call check(stat == 0,'representative structure builds successfully')
    call check(size(representatives%reynolds_groups) == 2,'both Reynolds groups retained')

    do g = 1, size(representatives%reynolds_groups)
        trial_length = length*representatives%reynolds_groups(g)%nominal_reynolds/nominal
        do m = 1, 3
            call validate_flight_condition(data,representatives,g,10000.0_real64,0.75_real64,1.0_real64, &
                                           trial_length,0.0_real64,condition,stat,trim(methods(m)))
            call check(stat == flight_ok.and.condition%accepted,'flight validation works after actual pipeline')
            if (representatives%reynolds_groups(g)%nominal_reynolds == nominal) then
                call close_to(condition%cl,1.6_real64,1.0e-12_real64)
                call close_to(condition%observed_reynolds_max,nominal,1.0e-12_real64)
            else
                call close_to(condition%cl,11.6_real64,1.0e-12_real64)
                call close_to(condition%observed_reynolds_max,30.0e6_real64,1.0e-12_real64)
            end if
        end do
    end do

    ! Recover an independently chosen altitude via a Reynolds-matching root search.
    call find_reynolds_matched_altitude(0.75_real64,length,nominal,altitude,stat,altitude_tolerance=1.0e-5_real64)
    call check(stat == flight_ok,'matched altitude search succeeds')
    call check(abs(altitude-10000.0_real64)<1.0e-5_real64,'known altitude recovered')
    call validate_flight_condition(data,structure,1,altitude,0.75_real64,1.0_real64,length, &
                                   1.0e-8_real64,condition,stat)
    call check(stat == flight_ok.and.condition%accepted,'solver result passes full validation')
    call validate_flight_condition(data,structure,1,0.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)

    endpoint_re = condition%reynolds

    call find_reynolds_matched_altitude(0.75_real64,length,endpoint_re,altitude,stat)
    call check(stat == flight_ok.and.altitude == 0.0_real64,'sea-level root endpoint')
    call find_reynolds_matched_altitude(0.75_real64,length,2.0_real64*endpoint_re,altitude,stat)
    call check(stat == flight_no_matching_altitude.and.ieee_is_nan(altitude),'target above range rejected')
    call validate_flight_condition(data,structure,1,32000.0_real64,0.75_real64,1.0_real64,length, &
                                   0.001_real64,condition,stat)

    endpoint_re = condition%reynolds

    call find_reynolds_matched_altitude(0.75_real64,length,endpoint_re,altitude,stat)
    call check(stat == flight_ok.and.altitude == 32000.0_real64,'upper-altitude root endpoint')
    call find_reynolds_matched_altitude(0.75_real64,length,0.5_real64*endpoint_re,altitude,stat)
    call check(stat == flight_no_matching_altitude.and.ieee_is_nan(altitude),'target below range rejected')
    call find_reynolds_matched_altitude(0.75_real64,length,nominal,altitude,stat,altitude_tolerance=0.0_real64)
    call check(stat == flight_invalid_input.and.ieee_is_nan(altitude),'invalid solver tolerance')
    call find_reynolds_matched_altitude(0.75_real64,length,nan,altitude,stat)
    call check(stat == flight_invalid_input.and.ieee_is_nan(altitude),'invalid target Re')

    print '(a,i0,a)', 'PASS: ',checks,' assertions'

contains

    subroutine check(current_condition,label)
        logical,intent(in) :: current_condition
        character(len=*),intent(in) :: label
        checks = checks+1
        if (.not. current_condition) then
            print '(a)', 'FAIL: '//label
            error stop 1
        end if
    end subroutine

    subroutine close_to(actual,target,tolerance)
        real(real64),intent(in) :: actual,target,tolerance
        call check(abs(actual-target)<=tolerance*max(1.0_real64,abs(target)),'numeric result')
    end subroutine
    subroutine rejected(expected_status)
        integer,intent(in) :: expected_status
        if(stat /= expected_status)print '(a,2i4)', 'Actual/expected status:',stat,expected_status
        call check(stat == expected_status.and..not.condition%accepted,'condition rejected')
        call check(ieee_is_nan(condition%cl).and.ieee_is_nan(condition%cd).and.ieee_is_nan(condition%cm),'no coefficients')
    end subroutine
    subroutine trim_run(run,n)
        type(aero_run_type), intent(inout) :: run
        integer, intent(in) :: n
        run%alpha = run%alpha(:n)
        run%mach = run%mach(:n)
        run%reynolds = run%reynolds(:n)
        run%cl = run%cl(:n)
        run%cd = run%cd(:n)
        run%cm = run%cm(:n)
    end subroutine
end program test_flight_condition_validation
