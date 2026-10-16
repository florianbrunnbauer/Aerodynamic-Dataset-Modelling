program main
    use iso_fortran_env, only: real64, input_unit, output_unit, iostat_end
    use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
    use types, only: run_info_type, aero_dataset_type, run_selection_type, dataset_validation_result_type, &
                     grouped_dataset_type, representative_dataset_type, flight_condition_type, reference_conditions
    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use data_io, only: read_crm_dataset
    use dataset_grouping, only: group_dataset
    use dataset_validation, only: validate_dataset
    use dataset_representative, only: build_representative_dataset
    use coefficient_query, only: query_status_message
    use standard_atmosphere, only: atmosphere_status_message
    use aerodynamic_properties, only: calculate_aerodynamic_loads, calculate_lift_to_drag, &
                                      properties_ok, properties_zero_drag
    use flight_condition_validation, only: validate_flight_condition, &
        find_reynolds_matched_altitude, flight_ok, flight_status_message

    implicit none

    type(aero_dataset_type) :: data
    type(representative_dataset_type) :: structure
    type(reference_conditions) :: references
    integer :: menu, call_status
    
    print '(a)', ''
    print '(a)', '=== Aerodynamic Dataset Modelling ==='
    print '(a)', 'Corrected CRM coefficients; linear Mach interpolation; no extrapolation.'
    print '(a)', 'Enter q at any prompt to quit. Altitudes are geometric metres above sea level.'
    print '(a)', 'Loads retain the dataset coordinate signs and pitching-moment reference point.'

    do 
        call select_dataset(data, structure)

        call select_geometry_and_policy(structure, references, call_status)

        if (call_status == 0) exit
    end do

    do
        print '(a)', ''
        print '(a)', '1: Query a flight condition'
        print '(a)', '2: Select another dataset/configuration'
        print '(a)', '3: Change reference geometry or Reynolds acceptance tolerance'
        print '(a)', '0: Exit'

        menu = ask_integer('Choice', 0, 3, 1)
        
        select case (menu)
        case (0)
            exit
        case (1)
            call query_and_report(data, structure, references)
        case (2)
            do 
                call select_dataset(data, structure)

                call select_geometry_and_policy(structure, references, call_status)

                if (call_status == 0) exit
            end do
        case (3)
            call select_geometry_and_policy(structure, references, call_status)
        end select
    end do
    
    print '(a)', 'Finished.'

    contains 

    subroutine select_dataset(dataset, representative)

        type(aero_dataset_type), intent(out) :: dataset
        type(representative_dataset_type), intent(out) :: representative

        character(len=:), allocatable :: dataset_path
        type(run_info_type), allocatable :: catalogue(:), selected_runs(:)
        type(run_selection_type) :: selection
        type(dataset_validation_result_type) :: validation_result
        type(grouped_dataset_type) :: grouped
        
        integer :: stat

        ! ------------------------------------------------------------
        ! 1. Build catalogue from complete CRM dataset
        ! ------------------------------------------------------------
        do 
            dataset_path = ask_text('CRM CSV directory', "data/phase_2")

            call build_run_catalogue(dataset_path, catalogue, stat)

            if (stat /= 0) then
                print *, "failed catalogue creation, please pick a valid dictionary"
                cycle
            end if
            ! ------------------------------------------------------------
            ! 2. Select one aerodynamic configuration
            ! ------------------------------------------------------------
            do 
                selection%config = ask_integer('CONFIG', 0, 100, 1)
                selection%confts = ask_integer('CONFTS', 0, 100, 1)
                selection%conft  = ask_integer('CONFT', 0, 100, 99)

                call select_runs(catalogue, selection, selected_runs)

                if (size(selected_runs) /= 0) exit

                print *, "no runs available for the selected configurations"
                print *, "please pick a configuration with runs available"
            end do
            ! ------------------------------------------------------------
            ! 3. Read complete selected dataset
            ! ------------------------------------------------------------
            call read_crm_dataset(selected_runs, dataset, stat)

            if (stat /= 0) then
                print *, "could not read parts of the CRM dataset"
                print *, "please try a different configuration or directory"
                cycle
            end if
            ! ------------------------------------------------------------
            ! 4. Validate dataset
            ! ------------------------------------------------------------
            call validate_dataset(dataset, validation_result)

            if (.not. validation_result%is_valid) then
                print *, "parts of the CRM dataset are invalid"
                print *, "please try a different configuration or directory"
                cycle
            end if
            ! ------------------------------------------------------------
            ! 5. Group dataset
            ! ------------------------------------------------------------                
            call group_dataset(dataset, grouped, stat)

            if (stat /= 0) then            
                print *, "could not group the dataset"
                print *, "please try a different configuration or directory"
                cycle
            end if        
            ! ------------------------------------------------------------
            ! 6. Build representative dataset
            ! ------------------------------------------------------------        
            call build_representative_dataset(dataset, grouped, representative, stat)
        
            if (stat /= 0) then
                print *, "could not build the representative dataset"
                print *, "please try a different configuration of directory"
                cycle 
            else
                exit
            end if
        
        end do

    end subroutine select_dataset

    subroutine select_geometry_and_policy(data_structure, ref, status)

        type(representative_dataset_type), intent(in) :: data_structure        
        type(reference_conditions), intent(out) :: ref
        integer, intent(out) :: status

        real(real64) :: percent
        integer :: stat

        status = 0

        print '(a)', ''
        print '(a)', '--- Fixed reference geometry and acceptance policy ---'
        print '(a)', 'Use the area and lengths used to define the dataset coefficients and Reynolds number.'
        print '(a)', 'For a scaled geometry, scale all reference dimensions consistently.'

        ref%reference_area = ask_real('Reference area [m^2]', tiny(1.0_real64), huge(1.0_real64))
        ref%reference_length = ask_real('Reynolds reference length [m]', tiny(1.0_real64), huge(1.0_real64))
        ref%reference_chord = ask_real('Pitching-moment reference chord [m]', tiny(1.0_real64), huge(1.0_real64))

        print '(a)', 'Re tolerance is an explicit acceptance policy, not a validated aerodynamic accuracy band.'
        print '(a)', 'Enter a percentage: 1 means 1%. Zero requires agreement within roundoff.'

        do
            percent = ask_real('Allowed Reynolds mismatch [%]', 0.0_real64, 100.0_real64)
            if (percent < 100.0_real64) exit
            print '(a)', 'Tolerance must be less than 100%.'
        end do

        ref%re_tolerance = percent/100.0_real64

        call ask_reynoldsnumber(data_structure, ref%re_number_position, stat)

        if (stat /= 0) status = 1
        
    end subroutine select_geometry_and_policy

    subroutine ask_reynoldsnumber(data_structure, position, stat)

        type(representative_dataset_type), intent(in) :: data_structure
        integer, intent(out) :: position
        integer, intent(out) :: stat

        integer :: i

        stat = 0

        if (.not. allocated(data_structure%reynolds_groups)) then
            stat = 1
            return
        end if

        if (size(data_structure%reynolds_groups) == 0) then
            stat = 2
            return
        end if
        
        print '(a)', ''
        print '(a)', '--- Pick Reynolds Number ---'
        print '(a)', 'Available Reynolds Numbers:'

        do i = 1, size(data_structure%reynolds_groups)
            print *, i , ') ', data_structure%reynolds_groups(i)%nominal_reynolds
        end do    

        position = ask_integer('Enter Position of your desired Reynolds Number', 1, size(data_structure%reynolds_groups), 1)

    end subroutine ask_reynoldsnumber

    subroutine query_and_report(dataset, struct, ref)

        type(aero_dataset_type), intent(in) :: dataset
        type(representative_dataset_type), intent(in) :: struct
        type(reference_conditions), intent(in) :: ref

        type(flight_condition_type) :: condition
        real(real64) :: alpha, mach, altitude, lift, drag, moment, ratio, nominal_reynolds, min_mach, max_mach
        integer :: mode, method, coordinates, stat, load_stat, ratio_stat, i
        character(len=6), parameter :: methods(3) = [character(len=6) :: 'linear', 'pchip', 'akima']
        logical :: mean_mach

        nominal_reynolds = struct%reynolds_groups(ref%re_number_position)%nominal_reynolds

        min_mach = 100
        max_mach = 0

        do i = 1, size(struct%reynolds_groups(ref%re_number_position)%mach_groups)
            if (struct%reynolds_groups(ref%re_number_position)%mach_groups(i)%nominal_mach < min_mach) &
                    min_mach = struct%reynolds_groups(ref%re_number_position)%mach_groups(i)%nominal_mach 

            if (struct%reynolds_groups(ref%re_number_position)%mach_groups(i)%nominal_mach > max_mach) &
                    max_mach = struct%reynolds_groups(ref%re_number_position)%mach_groups(i)%nominal_mach
        end do

        print '(a)', ''
        print '(a)', '--- Flight condition ---'
        print '(a)', '1: Enter altitude; 2: Find altitude matching nominal dataset Re'

        mode = ask_integer('Altitude mode', 1, 2, 1)

        print '(a)', 'Choose Mach number between'

        do 
            print *, 'Min: ', min_mach, 'Max: ', max_mach
            mach = ask_real('Mach number', tiny(1.0_real64), huge(1.0_real64))

            if (mach <= max_mach .and. mach >= min_mach) exit

            print '(a)', 'Please choose a Number inside bounds'

        end do
        
        alpha = ask_real('Alpha [degrees]', -huge(1.0_real64), huge(1.0_real64))

        print '(a)', 'Alpha interpolation: 1 linear, 2 PCHIP, 3 classical Akima'

        method = ask_integer('Alpha method', 1, 3, 3)

        print '(a)', 'Mach coordinates: 1 measured Mach(alpha), 2 sweep mean Mach'

        coordinates = ask_integer('Mach coordinate mode', 1, 2, 1)

        mean_mach = coordinates == 2

        if (mode == 1) then
            altitude = ask_real('Geometric altitude [m], 0 to 32000', 0.0_real64, 32000.0_real64)
        else
            ! Tight numerical precision helps strict policies; never relax the user's Re tolerance.
            call find_reynolds_matched_altitude(mach, ref%reference_length, nominal_reynolds, &
                                                altitude, stat, altitude_tolerance=1.0e-9_real64)

            if (stat /= flight_ok) then
                print '(a)', 'Altitude search failed: '//flight_status_message(stat)
                return
            end if
            
            call show_value('Reynolds-matched altitude [m]', altitude)
        end if

        call validate_flight_condition(dataset, struct, ref%re_number_position, altitude, mach, alpha, &
                                       ref%reference_length, ref%re_tolerance, & 
                                       condition, stat, alpha_method=trim(methods(method)), use_mean_mach=mean_mach)

        print '(a)', ''
        print '(a)', '--- Condition and compatibility ---'
        print '(a)', 'Alpha method: '//trim(methods(method))//'; Mach interpolation: linear'

        if (mean_mach) then
            print '(a)', 'Mach coordinates: sweep means'
        else
            print '(a)', 'Mach coordinates: measured Mach(alpha)'
        end if

        call show_value('Alpha [degrees]', alpha)
        call show_value('Mach', mach)
        call show_value('Geometric altitude [m]', altitude)

        call show_value('Temperature [K]', condition%air%temperature)
        call show_value('Pressure [Pa]', condition%air%pressure)
        call show_value('Density [kg/m^3]', condition%air%density)
        call show_value('Speed of sound [m/s]', condition%air%speed_of_sound)
        call show_value('Dynamic viscosity [Pa s]', condition%air%dynamic_viscosity)

        call show_value('True airspeed [m/s]', condition%speed)
        call show_value('Dynamic pressure [Pa]', condition%dynamic_pressure)
        call show_value('Flight Reynolds number', condition%reynolds)
        call show_value('Nominal dataset Reynolds number', nominal_reynolds)
        call show_value('Observed dataset Re minimum', condition%observed_reynolds_min)
        call show_value('Observed dataset Re maximum', condition%observed_reynolds_max)
        call show_value('Re mismatch [fraction]', condition%relative_reynolds_mismatch)
        call show_value('Allowed Re mismatch [fraction]', ref%re_tolerance)

        print '(a)', 'Status: '//flight_status_message(stat)

        if (stat /= flight_ok) then
            if (condition%coefficient_stat >= 0) then
                print '(a)', 'Coefficient query: '//query_status_message(condition%coefficient_stat)
            end if

            if (condition%atmosphere_stat > 0) then
                print '(a)', 'Atmosphere: '//atmosphere_status_message(condition%atmosphere_stat)
            end if

            print '(a)', 'No loads calculated. Change the condition, geometry, policy, or selected sweeps as appropriate.'

            return
        end if

        call calculate_aerodynamic_loads(condition%cl, condition%cd, condition%cm, condition%dynamic_pressure, &
                                         ref%reference_area, ref%reference_chord, lift, drag, moment, load_stat)

        call calculate_lift_to_drag(condition%cl, condition%cd, ratio, ratio_stat)

        print '(a)', ''
        print '(a)', '--- Aerodynamic results ---'

        call show_value('Cl', condition%cl)
        call show_value('Cd', condition%cd)
        call show_value('Cm', condition%cm)

        if (ratio_stat == properties_ok) then
            call show_value('Cl/Cd (signed)', ratio)
        else if (ratio_stat == properties_zero_drag) then
            print '(a)', 'Cl/Cd: undefined because Cd is zero.'
        else
            print '(a,i0)', 'Cl/Cd calculation failed; properties status: ', ratio_stat
        end if

        call show_value('Reference area [m^2]', ref%reference_area)
        call show_value('Reynolds reference length [m]', ref%reference_length)
        call show_value('Moment reference chord [m]', ref%reference_chord)

        if (load_stat == properties_ok) then
            call show_value('Lift [N]', lift)
            call show_value('Drag [N]', drag)
            call show_value('Pitching moment [N m]', moment)
        else
            print '(a,i0)', 'Load calculation failed; properties status: ', load_stat
        end if

    end subroutine query_and_report

    subroutine show_value(label, value)
        character(len=*), intent(in) :: label
        real(real64), intent(in) :: value
        if (ieee_is_finite(value)) print '(a38,2x,es17.9)', label//':', value
    end subroutine show_value

    function read_line(prompt) result(line)

        character(len=*), intent(in) :: prompt
        character(len=:), allocatable :: line
        character(len=8192) :: buffer
        integer :: stat

        do
            write(output_unit, '(a)', advance='no') trim(prompt)//': '
            flush(output_unit)
            read(input_unit, '(a)', iostat=stat) buffer

            if (stat == iostat_end) then
                print '(a)', ''
                print '(a)', 'Input ended. Finished.'
                stop
            end if

            if (stat /= 0) then
                print '(a)', 'Cannot read terminal input.'
                stop 1
            end if

            if (len_trim(buffer) == len(buffer)) then
                print '(a)', 'Input is too long. Please use fewer than 8192 characters.'
                cycle
            end if

            line = trim(adjustl(buffer))

            if (line == 'q' .or. line == 'Q') then
                print '(a)', 'Finished.'
                stop
            end if

            return

        end do

    end function read_line

    function ask_text(prompt, default) result(value)

        character(len=*), intent(in) :: prompt, default
        character(len=:), allocatable :: value

        value = read_line(prompt//' ['//default//']')
        if (len(value) == 0) value = default

    end function ask_text

    integer function ask_integer(prompt, lower, upper, default) result(value)

        character(len=*), intent(in) :: prompt
        integer, intent(in) :: lower, upper
        integer, intent(in), optional :: default
        character(len=:), allocatable :: line, label
        character(len=32) :: default_text
        integer :: stat

        label = prompt

        if (present(default)) then
            write(default_text, '(i0)') default
            label = prompt//' ['//trim(default_text)//']'
        end if

        do
            line = read_line(label)

            if (len(line) == 0 .and. present(default)) then
                value = default
                return
            end if

            if (len(line) > 0) then
                if (verify(line, '+-0123456789') == 0) then

                    read(line, *, iostat=stat) value

                    if (stat == 0) then
                        if (value >= lower .and. value <= upper) return
                    end if

                end if
            end if

            print '(a,i0,a,i0,a)', 'Enter one integer from ', lower, ' to ', upper, '.'

        end do

    end function ask_integer

    real(real64) function ask_real(prompt, lower, upper, default) result(value)

        character(len=*), intent(in) :: prompt
        real(real64), intent(in) :: lower, upper
        real(real64), intent(in), optional :: default
        character(len=:), allocatable :: line, label
        character(len=32) :: default_text
        integer :: stat

        label = prompt

        if (present(default)) then
            write(default_text, '(es12.4)') default
            label = prompt//' ['//trim(adjustl(default_text))//']'
        end if

        do

            line = read_line(label)

            if (len(line) == 0 .and. present(default)) then
                value = default
                return
            end if

            if (len(line) > 0) then
                ! Reject list-directed nulls, repeated values, and extra tokens.
                if (verify(line, '+-0123456789.eEdD') == 0) then

                    read(line, *, iostat=stat) value

                    if (stat == 0) then
                        if (ieee_is_finite(value)) then
                            if (value >= lower .and. value <= upper) return
                        end if
                    end if

                end if
            end if

            print '(a)', 'Enter one finite number in the allowed range (use a decimal point).'
        end do

    end function ask_real

end program main