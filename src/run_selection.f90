module run_selection

    use types, only: run_info_type, run_selection_type

    implicit none
    private

    public :: run_matches, select_runs

contains

    pure logical function run_matches(info, selection) result(matches)

        type(run_info_type), intent(in) :: info
        type(run_selection_type), intent(in) :: selection

        matches = &
            info%config == selection%config .and. &
            info%confts == selection%confts .and. &
            info%conft  == selection%conft

    end function run_matches

    subroutine select_runs(catalogue, selection, selected_runs)

        type(run_info_type), intent(in) :: catalogue(:)
        type(run_selection_type), intent(in) :: selection

        type(run_info_type), allocatable, intent(out) :: selected_runs(:)

        integer :: n_selected, i, j

        
        n_selected = 0

        ! First pass: count matching runs.
        do i = 1, size(catalogue)

            if (run_matches(catalogue(i), selection)) then
                n_selected = n_selected + 1
            end if

        end do


        allocate(selected_runs(n_selected))


        ! Second pass: copy matching run metadata.
        j = 0

        do i = 1, size(catalogue)

            if (run_matches(catalogue(i), selection)) then

                j = j + 1
                selected_runs(j) = catalogue(i)

            end if

        end do

    end subroutine select_runs

end module run_selection