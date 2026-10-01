module dataset_catalogue

    use iso_fortran_env, only: iostat_end
    use types, only: run_info_type
    use data_io, only: inspect_crm_run

    implicit none
    private

    public :: build_run_catalogue

contains

    subroutine build_run_catalogue(directory, catalogue, stat)

        character(len=*), intent(in) :: directory
        type(run_info_type), allocatable, intent(out) :: catalogue(:)
        integer, intent(out) :: stat

        integer, parameter :: filename_length = 4096
        integer, parameter :: command_length = 8192

        character(len=filename_length) :: filename
        character(len=filename_length) :: list_filename
        character(len=command_length) :: command
        character(len=256) :: command_message

        integer :: list_unit, ios, n_files, i, inspect_stat

        integer :: command_stat, exit_stat, clock_count

        stat = 0
        n_files = 0

        ! Standard Fortran cannot directly capture the stdout of
        ! execute_command_line. Therefore, store the filenames temporarily.
        call system_clock(count=clock_count)

        write(list_filename, '(A,I0,A)') &
            '/tmp/aero_dataset_catalogue_', clock_count, '.txt'

        command = 'find "' // trim(directory) // &
                  '" -type f -name "*.csv" -print > "' // &
                  trim(list_filename) // '"'

        command_stat = 0
        exit_stat = 0
        command_message = ''

        call execute_command_line(trim(command), wait=.true., exitstat=exit_stat, &
                                cmdstat=command_stat, cmdmsg=command_message)

        if (command_stat /= 0) then
            print *, "Could not execute dataset file search."
            print *, trim(command_message)
            stat = 1
            return
        end if

        if (exit_stat /= 0) then
            print *, "Dataset file search failed for directory: ", &
                     trim(directory)
            stat = 2
            return
        end if

        open(newunit=list_unit, file=trim(list_filename), &
                        status="old", action="read", iostat=ios)

        if (ios /= 0) then
            print *, "Could not open temporary dataset file list."
            stat = 3
            return
        end if


        ! First pass: determine how many CSV files exist.
        do

            read(list_unit, '(A)', iostat=ios) filename

            if (ios == iostat_end) exit

            if (ios /= 0) then
                print *, "Error while reading temporary dataset file list."
                close(list_unit, status="delete")
                stat = 4
                return
            end if

            if (len_trim(filename) > 0) then
                n_files = n_files + 1
            end if

        end do


        if (n_files == 0) then
            print *, "No CSV files found in directory: ", trim(directory)

            close(list_unit, status="delete")
            allocate(catalogue(0))

            stat = 5
            return
        end if


        allocate(catalogue(n_files))
        rewind(list_unit)

        i = 0


        ! Second pass: inspect each CRM CSV and store its metadata.
        do

            read(list_unit, '(A)', iostat=ios) filename

            if (ios == iostat_end) exit

            if (ios /= 0) then
                print *, "Error while reading temporary dataset file list."

                close(list_unit, status="delete")
                deallocate(catalogue)

                stat = 6
                return
            end if

            if (len_trim(filename) == 0) cycle

            i = i + 1

            call inspect_crm_run(trim(filename), catalogue(i), inspect_stat)

            if (inspect_stat /= 0) then
                print *, "Could not inspect CRM file: ", trim(filename)
                print *, "inspect_crm_run status: ", inspect_stat

                close(list_unit, status="delete")
                deallocate(catalogue)

                stat = 7
                return
            end if

        end do


        close(list_unit, status="delete")

    end subroutine build_run_catalogue

end module dataset_catalogue