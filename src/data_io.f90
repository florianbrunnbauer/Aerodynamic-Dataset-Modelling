! Module for reading and writing data to files

module data_io
    use iso_fortran_env, only: real64, iostat_end
    use types, only: aerodynamic_polar_type, aerodynamic_dataset_type, &
                     run_info_type, aero_run_type, aero_dataset_type

    implicit none

    private

    integer, parameter :: crm_line_length = 20000

    public :: read_airfoil_data, inspect_crm_run, read_crm_run, read_crm_dataset

contains

    subroutine read_airfoil_data(filename, dataset)
        character(len=*), intent(in) :: filename
        type(aerodynamic_dataset_type), intent(out) :: dataset

        character(len=512) :: line
        character(len=256) :: error_message
        real(real64) :: alpha_temp, cl_temp, cd_temp,&
                        cdp_temp, cm_temp, top_xtr_temp, bot_xtr_temp
        integer :: ios, unit, i, parse_ios, n_rows, current_line_nr, comma_pos
        type(aerodynamic_polar_type) :: polar
        character(len=128) :: constant_name
        logical :: reynolds_found = .false., mach_found = .false.

        n_rows = 0
        current_line_nr = 0
    
        ! Open the file for reading
        open(newunit=unit, file=filename, status='old', action='read',&
            iostat=ios, iomsg=error_message)
        
        if (ios /= 0) then
            print *, "Error opening file: ", filename
            print *, "Error message: ", error_message
            error stop
        end if
    
        ! First pass: Count the number of rows in the file
        do 
            read(unit, '(A)', iostat=ios, iomsg=error_message) line

            

            if (ios == iostat_end) exit  ! End of file reached
            
            if (ios > 0) then
                print *, "Error reading number of data points from file: ", filename
                print *, "Error message: ", error_message
                close(unit)
                error stop
            end if

            current_line_nr = current_line_nr + 1

            ! Parse the line to check if it contains valid data
            read(line, *, iostat=parse_ios) alpha_temp, cl_temp, cd_temp, &
                 cdp_temp, cm_temp, top_xtr_temp, bot_xtr_temp

            if (parse_ios == 0) then

                n_rows = n_rows + 1
            
            else if (n_rows == 0) then
                ! If we haven't counted any rows yet, check for constants
                comma_pos = index(line, ",")

                if (comma_pos > 0) then
                
                    constant_name = trim(adjustl(line(:comma_pos-1)))
                
                    select case (constant_name)
                    
                    case ("Reynolds number")
                        read(line(comma_pos+1:), *, iostat=parse_ios) polar%reynolds
                    
                        if (parse_ios /= 0) then
                            close(unit)
                            error stop "Invalid Reynolds number."
                        end if

                        reynolds_found = .true.
                    
                    case ("Mach")
                        read(line(comma_pos+1:), *, iostat=parse_ios) polar%mach
                    
                        if (parse_ios /= 0) then
                            close(unit)
                            error stop "Invalid Mach number."
                        end if

                        mach_found = .true.
                    
                    end select
                
                end if
            
            else
            
                print *, "Invalid data format in row: ", current_line_nr, &
                         " - ", trim(adjustl(line))
                close(unit)
                error stop "Malformed data encountered in the file."
            
            end if

        end do

        if (.not. reynolds_found) then
            print *, "Error: Reynolds number not specified in the file."
            close(unit)
            error stop
        end if

        if (.not. mach_found) then
            print *, "Error: Mach number not specified in the file."        
            close(unit)
            error stop
        end if

        if (polar%reynolds <= 0.0_real64) then
            print *, "Error: Reynolds number must be positive."
            close(unit)
            error stop
        end if

        if (polar%mach < 0.0_real64) then
            print *, "Error: Mach number cannot be negative."
            close(unit)
            error stop
        end if

        if (n_rows <= 0) then
            close(unit)
            error stop "No aerodynamic data found in the file."
        end if

        ! return to the beginning of the file to read the data
        rewind(unit)

        allocate(polar%alpha(n_rows), polar%cl(n_rows), polar%cd(n_rows),&
                polar%cm(n_rows))
        i = 0
        
        ! Second pass: Read the data into the arrays
        do

            read(unit, '(A)', iostat=ios, iomsg=error_message) line

            if (ios == iostat_end) exit  ! End of file reached
            
            if (ios /= 0) then
                print *, "Error reading data from file: ", filename
                print *, "Error message: ", error_message
                close(unit)
                error stop
            end if

            read(line, *, iostat=parse_ios) alpha_temp, cl_temp, cd_temp,&
                       cdp_temp, cm_temp, top_xtr_temp, bot_xtr_temp

            if (parse_ios /= 0) cycle  ! Skip lines that cannot be parsed

            i = i + 1

            polar%alpha(i) = alpha_temp
            polar%cl(i) = cl_temp
            polar%cd(i) = cd_temp
            polar%cm(i) = cm_temp
            
        end do

        ! Assign the polar data to the dataset
        allocate(dataset%polars(1))
        dataset%polars(1) = polar

        ! Close the file
        close(unit)
    end subroutine read_airfoil_data
    
    subroutine inspect_crm_run(filename, info, stat)

        character(len=*), intent(in) :: filename
        type(run_info_type), intent(out) :: info
        integer, intent(out) :: stat

        character(len=crm_line_length) :: header
        character(len=crm_line_length) :: line
        character(len=256) :: error_message

        integer :: unit, ios, parse_ios
        integer :: n_columns

        integer :: test_pos, run_pos, series_pos, config_pos, confts_pos, conft_pos

        real(real64), allocatable :: values(:)

        stat = 0

        open(newunit=unit, file=filename, status="old", &
            action="read", iostat=ios, iomsg=error_message)

        if (ios /= 0) then
            stat = 1
            return
        end if

        ! Read header
        read(unit, '(A)', iostat=ios, iomsg=error_message) header

        if (ios /= 0) then
            stat = 2
            close(unit)
            return
        end if

        ! Find required columns
        test_pos   = find_csv_column(header, "TEST")
        run_pos    = find_csv_column(header, "RUN")
        series_pos = find_csv_column(header, "SERIES")
        config_pos = find_csv_column(header, "CONFIG")
        confts_pos = find_csv_column(header, "CONFTS")
        conft_pos  = find_csv_column(header, "CONFT")

        if (test_pos   == 0 .or. &
            run_pos    == 0 .or. &
            series_pos == 0 .or. &
            config_pos == 0 .or. &
            confts_pos == 0 .or. &
            conft_pos  == 0) then

            stat = 3
            close(unit)
            return

        end if

        n_columns = count_csv_columns(header)

        allocate(values(n_columns))

        ! Only the first measurement row is required for run metadata
        read(unit, '(A)', iostat=ios, iomsg=error_message) line

        if (ios /= 0) then
            stat = 4
            close(unit)
            return
        end if

        read(line, *, iostat=parse_ios) values

        if (parse_ios /= 0) then
            stat = 5
            close(unit)
            return
        end if

        info%test   = nint(values(test_pos))
        info%run    = nint(values(run_pos))
        info%series = nint(values(series_pos))

        info%config = nint(values(config_pos))
        info%confts = nint(values(confts_pos))
        info%conft  = nint(values(conft_pos))

        info%filename = trim(filename)

        close(unit)

    end subroutine inspect_crm_run

    subroutine read_crm_run(info, run, stat)

        type(run_info_type), intent(in) :: info
        type(aero_run_type), intent(out) :: run
        integer, intent(out) :: stat

        character(len=crm_line_length) :: header, line
        character(len=256) :: error_message

        integer :: unit, ios, parse_ios

        integer :: n_columns, n_rows, i

        integer :: alpha_pos, mach_pos, reynolds_pos, cl_pos, cd_pos, cm_pos

        real(real64), allocatable :: values(:)


        stat = 0
        n_rows = 0

        ! Copy the already inspected metadata into the run.
        run%info = info


        open(newunit=unit, file=info%filename, status="old", action="read", &
            iostat=ios, iomsg=error_message)

        if (ios /= 0) then
            print *, "Could not open CRM run: ", trim(info%filename)
            print *, trim(error_message)

            stat = 1
            return
        end if


        ! Read the header.
        read(unit, '(A)', iostat=ios, iomsg=error_message) header

        if (ios /= 0) then
            print *, "Could not read CRM header: ", trim(info%filename)

            stat = 2
            close(unit)
            return
        end if


        ! Determine the locations of the aerodynamic variables.
        alpha_pos = find_csv_column(header, "WCALPHA")
        mach_pos = find_csv_column(header, "WCMACH")
        reynolds_pos = find_csv_column(header, "CREYN")

        cl_pos = find_csv_column(header, "WCCLC")
        cd_pos = find_csv_column(header, "WCCDC")
        cm_pos = find_csv_column(header, "WCCMC")


        if (alpha_pos == 0 .or. &
            mach_pos == 0 .or. &
            reynolds_pos == 0 .or. &
            cl_pos == 0 .or. &
            cd_pos == 0 .or. &
            cm_pos == 0 &
        ) then

            print *, "Required aerodynamic columns missing in: ", &
                     trim(info%filename)

            stat = 3
            close(unit)
            return
        end if


        n_columns = count_csv_columns(header)

        allocate(values(n_columns))


        ! First pass:
        ! Count the number of measurement points.
        do

            read(unit, '(A)', iostat=ios, iomsg=error_message) line

            if (ios == iostat_end) exit

            if (ios /= 0) then
                print *, "Error reading CRM data: ", trim(info%filename)

                stat = 4
                close(unit)
                return
            end if


            ! Check that the row is actually numeric and complete.
            read(line, *, iostat=parse_ios) values

            if (parse_ios /= 0) then
                print *, "Malformed CRM data row in: ", &
                         trim(info%filename)

                stat = 5
                close(unit)
                return
            end if

            n_rows = n_rows + 1

        end do


        if (n_rows == 0) then
            print *, "No aerodynamic data found in: ", &
                     trim(info%filename)

            stat = 6
            close(unit)
            return
        end if


        ! Allocate only the variables required by the aerodynamic model.
        allocate(run%alpha(n_rows), run%mach(n_rows), run%reynolds(n_rows), &
            run%cl(n_rows), run%cd(n_rows), run%cm(n_rows))


        ! Return to the beginning of the file.
        rewind(unit)


        ! Skip/read the header again.
        read(unit, '(A)', iostat=ios, iomsg=error_message) header

        if (ios /= 0) then
            stat = 7
            close(unit)
            return
        end if


        i = 0


        ! Second pass:
        ! Store the selected aerodynamic variables.
        do

            read(unit, '(A)', iostat=ios, iomsg=error_message) line

            if (ios == iostat_end) exit

            if (ios /= 0) then
                print *, "Error reading CRM data: ", trim(info%filename)

                stat = 8
                close(unit)
                return
            end if


            read(line, *, iostat=parse_ios) values

            if (parse_ios /= 0) then
                print *, "Malformed CRM data row in: ", &
                         trim(info%filename)

                stat = 9
                close(unit)
                return
            end if


            i = i + 1

            run%alpha(i) = values(alpha_pos)
            run%mach(i) = values(mach_pos)
            run%reynolds(i) = values(reynolds_pos) * 1.0e6_real64

            run%cl(i) = values(cl_pos)
            run%cd(i) = values(cd_pos)
            run%cm(i) = values(cm_pos)

        end do


        close(unit)

    end subroutine read_crm_run

    subroutine read_crm_dataset(selected_runs, dataset, stat)

        type(run_info_type), intent(in) :: selected_runs(:)
        type(aero_dataset_type), intent(out) :: dataset
        integer, intent(out) :: stat

        integer :: i, run_stat

        stat = 0

        allocate(dataset%runs(size(selected_runs)))

        do i = 1, size(selected_runs)

            call read_crm_run(selected_runs(i), dataset%runs(i), run_stat)

            if (run_stat /= 0) then
                print *, "Failed to read CRM run: ", &
                         selected_runs(i)%run

                stat = 1
                return
            end if

        end do

    end subroutine read_crm_dataset

    integer function count_csv_columns(line) result(n_columns)

        character(len=*), intent(in) :: line
        integer :: i

        if (len_trim(line) == 0) then
            n_columns = 0
            return
        end if

        n_columns = 1

        do i = 1, len_trim(line)

            if (line(i:i) == ",") then
                n_columns = n_columns + 1
            end if

        end do

    end function count_csv_columns

    integer function find_csv_column(header, column_name) result(column_index)

        character(len=*), intent(in) :: header
        character(len=*), intent(in) :: column_name

        integer :: start_pos, comma_pos, current_column, end_pos

        character(len=:), allocatable :: token

        column_index = 0
        current_column = 1
        start_pos = 1

        do

            comma_pos = index(header(start_pos:), ",")

            if (comma_pos == 0) then

                token = trim(adjustl(header(start_pos:len_trim(header))))

                if (token == trim(column_name)) then
                    column_index = current_column
                end if

                return

            end if

            end_pos = start_pos + comma_pos - 2

            token = trim(adjustl(header(start_pos:end_pos)))

            if (token == trim(column_name)) then
                column_index = current_column
                return
            end if

            start_pos = end_pos + 2
            current_column = current_column + 1

        end do

    end function find_csv_column

end module data_io  