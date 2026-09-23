! Module for reading and writing data to files

module data_io
  use iso_fortran_env, only: real64, iostat_end
  implicit none
  private

  public :: read_airfoil_data

contains

    subroutine read_airfoil_data(filename, alpha, cl, cd, cdp, cm, top_xtr, bot_xtr)
        character(len=*), intent(in) :: filename
        real(real64), allocatable, intent(out) :: alpha(:), cl(:), cd(:), &
                                       cdp(:), cm(:), top_xtr(:), bot_xtr(:)
        
        character(len=512) :: line
        character(len=256) :: error_message
        real(real64) :: alpha_temp, cl_temp, cd_temp,&
                        cdp_temp, cm_temp, top_xtr_temp, bot_xtr_temp
        integer :: ios, unit, i, parse_ios, n_rows, current_line_nr

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

            if ((parse_ios /= 0) .and. (n_rows == 0)) cycle  ! Skip lines that are part of the header (only if no valid data has been read yet)

            if ((parse_ios /= 0) .and. (n_rows > 0)) then
                print *, "Invalid data format in row: ", current_line_nr, " - ", trim(adjustl(line))
                close(unit)
                error stop "Malformed data encountered in the file."
            end if
                
            n_rows = n_rows + 1              

        end do

        ! return to the beginning of the file to read the data
        rewind(unit)
    
        ! Allocate the array to hold the data
        allocate(alpha(n_rows), cl(n_rows), cd(n_rows),&
                 cdp(n_rows), cm(n_rows), top_xtr(n_rows), bot_xtr(n_rows))

        i = 0
        
        ! Second pass: Read the data into the arrays
        do

            read(unit, '(A)', iostat=ios, iomsg=error_message) line

            if (ios == iostat_end) exit  ! End of file reached
            
            if (ios > 0) then
                print *, "Error reading data from file: ", filename
                print *, "Error message: ", error_message
                close(unit)
                error stop
            end if

            read(line, *, iostat=parse_ios) alpha_temp, cl_temp, cd_temp,&
                       cdp_temp, cm_temp, top_xtr_temp, bot_xtr_temp

            if (parse_ios /= 0) cycle  ! Skip lines that cannot be parsed

            i = i + 1

            alpha(i) = alpha_temp
            cl(i) = cl_temp
            cd(i) = cd_temp
            cdp(i) = cdp_temp
            cm(i) = cm_temp
            top_xtr(i) = top_xtr_temp
            bot_xtr(i) = bot_xtr_temp
            
        end do

        ! Close the file
        close(unit)
    end subroutine read_airfoil_data
    
end module data_io  