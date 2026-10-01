program test_crm_run_inspection

    use types, only: run_info_type
    use data_io, only: inspect_crm_run

    implicit none

    type(run_info_type) :: info
    integer :: stat

    print *
    print *, "========================================"
    print *, "Test: CRM run inspection"
    print *, "========================================"
    print *

    call inspect_crm_run("data/phase_2/t197R39.csv", info, stat)

    if (stat /= 0) then
        print *, "CRM inspection failed. staus:", stat
        error stop 
    end if

    if (info%test /= 197) then
        error stop "Incorrect TEST."
    end if

    if (info%run /= 39) then
        error stop "Incorrect RUN."
    end if

    if (info%series /= 11) then
        error stop "Incorrect SERIES."
    end if

    if (info%config /= 1) then
        error stop "Incorrect CONFIG."
    end if

    if (info%confts /= 1) then
        error stop "Incorrect CONFTS."
    end if

    if (info%conft /= 99) then
        error stop "Incorrect CONFT."
    end if

    print *
    print *, "PASS: CRM run inspection"
    print *

end program test_crm_run_inspection