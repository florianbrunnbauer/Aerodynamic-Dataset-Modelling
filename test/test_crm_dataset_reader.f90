program test_crm_dataset_reader

    use data_io, only: read_crm_dataset
    use types, only: run_info_type, aero_dataset_type, run_selection_type
    use dataset_catalogue, only: build_run_catalogue
    use run_selection, only: select_runs
    use iso_fortran_env, only: real64

    implicit none

    type(run_info_type), allocatable :: catalogue(:)
    type(run_info_type), allocatable :: selected_runs(:)

    type(run_selection_type) :: selection
    type(aero_dataset_type) :: dataset

    integer :: stat_catalogue, stat_crm, i, n, n_rows
    character(len=24) :: filename(12)
    real(real64) :: alpha(12), reynolds(12), mach(12), cl(12), cd(12), cm(12)
    type(aero_dataset_type) :: reference_dataset

    filename = ["data/phase_2/t197R39.csv", "data/phase_2/t197R41.csv", &
                "data/phase_2/t197R42.csv", "data/phase_2/t197R43.csv", &
                "data/phase_2/t197R44.csv", "data/phase_2/t197R46.csv", &
                "data/phase_2/t197R47.csv", "data/phase_2/t197R48.csv", &
                "data/phase_2/t197R50.csv", "data/phase_2/t197R51.csv", &
                "data/phase_2/t197R52.csv", "data/phase_2/t197R53.csv"]
    
    alpha = [-2.89024_real64, -2.84175_real64, -2.88902_real64, -2.84141_real64, &
             -2.8238_real64, -2.85128_real64, -2.82662_real64, -2.84672_real64, &
             2.23531_real64, 2.26614_real64, 2.17194_real64, 2.22523_real64]

    reynolds = [4.99514e6_real64, 4.99184e6_real64, 4.99496e6_real64, 4.999e6_real64, &
                4.99559e6_real64, 4.98974e6_real64, 5.00143e6_real64, 4.99481e6_real64, &
                4.99804e6_real64, 4.98569e6_real64, 4.99902e6_real64, 4.98202e6_real64]

    mach = [0.700381_real64, 0.750028_real64, 0.800459_real64, 0.831331_real64, &
            0.851335_real64, 0.861337_real64, 0.871019_real64, 0.882066_real64, &
            0.70158_real64, 0.852314_real64, 0.700999_real64, 0.851893_real64]

    cl = [-0.144471_real64, -0.150983_real64, -0.176721_real64, -0.189481_real64, &
          -0.202219_real64, -0.204275_real64, -0.19675_real64, -0.189243_real64, &
          0.367853_real64, 0.426696_real64, 0.361241_real64, 0.421582_real64]

    cd = [0.0159214_real64, 0.0162938_real64, 0.0173375_real64, 0.0187529_real64, &
          0.0221172_real64, 0.0246407_real64, 0.0266915_real64, 0.029333_real64, &
          0.0191393_real64, 0.022121_real64, 0.0189728_real64, 0.0218792_real64]

    cm = [-0.0278011_real64, -0.0246125_real64, -0.0188903_real64, -0.01227_real64, &
          -0.00219044_real64, -0.000235721_real64, -0.000122903_real64, -0.00119283_real64, &
          -0.0453093_real64, -0.0566445_real64, -0.0451576_real64, -0.0561117_real64]
    
    allocate(reference_dataset%runs(12))

    do i = 1, 12

        reference_dataset%runs(i)%info%filename = filename(i)
        reference_dataset%runs(i)%info%run = i
        reference_dataset%runs(i)%info%test = 2
        reference_dataset%runs(i)%info%series = 1
        reference_dataset%runs(i)%info%config = 1
        reference_dataset%runs(i)%info%confts = 1
        reference_dataset%runs(i)%info%conft = 99

        n_rows = 1

        allocate(reference_dataset%runs(i)%alpha(n_rows), reference_dataset%runs(i)%mach(n_rows), &
            reference_dataset%runs(i)%reynolds(n_rows), reference_dataset%runs(i)%cl(n_rows), &
            reference_dataset%runs(i)%cd(n_rows), reference_dataset%runs(i)%cm(n_rows))
        
        reference_dataset%runs(i)%alpha(1) = alpha(i)
        reference_dataset%runs(i)%mach(1) = mach(i)
        reference_dataset%runs(i)%reynolds(1) = reynolds(i)
        reference_dataset%runs(i)%cl(1) = cl(i)
        reference_dataset%runs(i)%cd(1) = cd(i)
        reference_dataset%runs(i)%cm(1) = cm(i)

    end do

    print *
    print *, "========================================"
    print *, "Test: CRM dataset reader"
    print *, "========================================"
    print *

    call build_run_catalogue("data/phase_2", catalogue, stat_catalogue)

    if (stat_catalogue /= 0) then
        error stop "FAILED: catalogue creation"
    end if


    selection%config = 1
    selection%confts = 1
    selection%conft  = 99


    call select_runs(catalogue, selection, selected_runs)

    call read_crm_dataset(selected_runs, dataset, stat_crm)

    if (stat_crm /= 0) then
        error stop "FAILED: CRM dataset reader"
    end if

    if (size(dataset%runs) /= size(selected_runs)) then
        error stop "FAILED: incorrect number of loaded runs"
    end if

    do i = 1, size(dataset%runs)

        if (size(dataset%runs(i)%alpha) /= &
            size(dataset%runs(i)%cl)) then

            error stop "FAILED: inconsistent run data"

        end if

    end do

    do i = 1, size(dataset%runs)

        if (dataset%runs(i)%info%run /= selected_runs(i)%run) then
            error stop "FAILED: run metadata mismatch"
        end if

    end do

    if (size(dataset%runs) /= size(reference_dataset%runs)) then
        error stop "FAILED: dataset size mismatch"
    end if

    dataset_loop: do i = 1, size(dataset%runs)

        reference_loop: do n = 1, size(reference_dataset%runs)

            if (dataset%runs(i)%info%filename == reference_dataset%runs(n)%info%filename) then
                
                if (dataset%runs(i)%alpha(1) /= reference_dataset%runs(n)%alpha(1)) then
                    error stop "FAILED: alpha mismatch"
                end if
                if (dataset%runs(i)%mach(1) /= reference_dataset%runs(n)%mach(1)) then
                    error stop "FAILED: mach mismatch"
                end if
                if (dataset%runs(i)%reynolds(1) /= reference_dataset%runs(n)%reynolds(1)) then
                    error stop "FAILED: reynolds mismatch"
                end if
                if (dataset%runs(i)%cl(1) /= reference_dataset%runs(n)%cl(1)) then
                    error stop "FAILED: cl mismatch"
                end if
                if (dataset%runs(i)%cd(1) /= reference_dataset%runs(n)%cd(1)) then
                    error stop "FAILED: cd mismatch"
                end if
                if (dataset%runs(i)%cm(1) /= reference_dataset%runs(n)%cm(1)) then
                    error stop "FAILED: cm mismatch"
                end if

                print *, "PASSED: Run ", dataset%runs(i)%info%filename, " matches reference data."

                exit reference_loop

            end if

            if (n == size(reference_dataset%runs)) then
                error stop "FAILED: run not found in reference dataset"
            end if
        end do reference_loop
    
    end do dataset_loop

    print *
    print *, "PASSED: CRM dataset reader"
    print *

end program test_crm_dataset_reader