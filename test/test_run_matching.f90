program test_run_matching

    use run_selection, only: run_matches
    use types, only: run_selection_type, run_info_type

    implicit none

    type(run_selection_type) :: selection
    type(run_info_type) :: info

    print *
    print *, "========================================"
    print *, "Test: CRM run matching"
    print *, "========================================"
    print *

    selection%config = 1
    selection%confts = 1
    selection%conft  = 99

    info%test = 197
    info%run = 39
    info%series = 11
    info%filename = "dummy_file"
    info%config = 1
    info%confts = 1
    info%conft = 99

    if (.not. run_matches(info, selection)) then
        error stop "FAILED: Matching run rejected."
    end if

    selection%config = 2
    selection%confts = 0
    selection%conft  = 99

    if (run_matches(info, selection)) then
        error stop "FAILED: Non-matching run accepted."
    end if

    info%config = 2
    info%confts = 0
    info%conft = 0

    if (run_matches(info, selection)) then
        error stop "FAILED: Non-matching run accepted. Mismatched conft: info = 0, selection = 99"
    end if

    info%config = 1
    info%conft = 99

    if (run_matches(info, selection)) then
        error stop "FAILED: Non-matching run accepted. Mismatched config: info = 1, selection = 2"
    end if

    info%config = 2
    info%confts = 1

    if (run_matches(info, selection)) then
        error stop "FAILED: Non-matching run accepted. Mismatched confts: info = 1, selection = 0"
    end if

    print *
    print *, "PASSED: CRM run matching"
    print *

end program test_run_matching