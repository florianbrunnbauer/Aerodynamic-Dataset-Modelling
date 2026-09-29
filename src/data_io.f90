! Module for reading and writing data to files

module data_io
  use iso_fortran_env, only: real64, iostat_end
  use types, only: aerodynamic_polar_type, aerodynamic_dataset_type
  implicit none
  private

  public :: read_airfoil_data

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
    
end module data_io  