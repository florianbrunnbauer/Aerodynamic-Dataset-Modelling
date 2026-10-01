program test_dataset_catalogue

    use types, only: run_info_type
    use dataset_catalogue, only: build_run_catalogue

    implicit none

    type(run_info_type), allocatable :: catalogue(:)

    integer :: stat
    integer :: i


    print *
    print *, "========================================"
    print *, "Test: CRM dataset catalogue"
    print *, "========================================"
    print *

    call build_run_catalogue("data/phase_2", catalogue, stat)


    if (stat /= 0) then
        print *, "FAILED: catalogue creation, Exit Status:", stat
        error stop 
    end if


    if (size(catalogue) <= 0) then
        error stop "FAILED: empty catalogue"
    end if


    print *, "Number of runs: ", size(catalogue)

    do i = 1, size(catalogue)

        print *, &
            catalogue(i)%filename, &
            catalogue(i)%run, &
            catalogue(i)%series, &
            catalogue(i)%config, &
            catalogue(i)%confts, &
            catalogue(i)%conft

    end do

    print *
    print *, "PASS: CRM dataset catalogue"
    print *

end program test_dataset_catalogue