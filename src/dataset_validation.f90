module dataset_validation

    use types, only: validation_result_type, dataset_validation_result_type,&
                      aero_run_type, aero_dataset_type
    use ieee_arithmetic, only: ieee_is_finite
    use iso_fortran_env, only: real64
    implicit none

    private

    public :: validate_run, validate_dataset
    
contains

    subroutine validate_run(current_run, result)
        type(aero_run_type), intent(in) :: current_run
        type(validation_result_type), intent(out) :: result

        integer :: i, n_points


        if (.not. (allocated(current_run%alpha) .and. &
                   allocated(current_run%cl) .and. &
                   allocated(current_run%cd) .and. &
                   allocated(current_run%cm) .and. &
                   allocated(current_run%mach) .and. &
                   allocated(current_run%reynolds))) then

            result%is_valid = .false.
            result%arrays_allocated = .false.
            return
        end if
        
        n_points = size(current_run%alpha)  
        result%n_points = n_points      

        if (n_points < 2) then
            result%is_valid = .false.
            result%enough_points = .false.
            return
        end if    

        if ((n_points /= size(current_run%cl)) .or. &
            (n_points /= size(current_run%cd)) .or. &
            (n_points /= size(current_run%cm)) .or. &
            (n_points /= size(current_run%mach)) .or. &
            (n_points /= size(current_run%reynolds))) then
            result%is_valid = .false.
            result%n_points = 0
            result%consistent_sizes = .false.
            return
        end if

        result%n_invalid_values = &
            count(.not. ieee_is_finite(current_run%alpha)) + &
            count(.not. ieee_is_finite(current_run%cl)) + &
            count(.not. ieee_is_finite(current_run%cd)) + &
            count(.not. ieee_is_finite(current_run%cm)) + &
            count(.not. ieee_is_finite(current_run%mach)) + &
            count(.not. ieee_is_finite(current_run%reynolds))

        if (result%n_invalid_values > 0) then
            result%is_valid = .false.
            result%values_finite = .false.
        end if

        ! Check for duplicate alpha values
        do i = 2, n_points
            if (any(current_run%alpha(i) == current_run%alpha(1:i-1))) then
                result%n_duplicate_alpha = result%n_duplicate_alpha + 1
                result%is_valid = .false.
            end if
        end do

        ! Check if alpha is sorted
        result%alpha_sorted = all(current_run%alpha(2:n_points) >= &
                                  current_run%alpha(1:n_points-1))

        if (.not. result%alpha_sorted) then
            result%is_valid = .false.
            result%alpha_sorted = .false.
        end if

        if (any(current_run%mach < 0.0_real64) .or. &
            any(current_run%reynolds <= 0.0_real64)) then
            result%is_valid = .false.
            result%mach_reynolds_valid = .false.
        end if

    end subroutine validate_run


    subroutine validate_dataset(dataset, result)

        type(aero_dataset_type), intent(in) :: dataset
        type(dataset_validation_result_type), intent(out) :: result

        integer :: i

        if (.not. allocated(dataset%runs)) then
            result%is_valid = .false.
            return
        end if

        result%n_runs = size(dataset%runs)

        if (result%n_runs == 0) then
            result%is_valid = .false.
            return
        end if

        allocate(result%run_results(result%n_runs))

        do i = 1, result%n_runs

            call validate_run(dataset%runs(i), result%run_results(i))

            if (result%run_results(i)%is_valid) then

                result%n_valid_runs = result%n_valid_runs + 1

            else

                result%n_invalid_runs = result%n_invalid_runs + 1

            end if

        end do

        result%is_valid = result%n_invalid_runs == 0

    end subroutine validate_dataset

    subroutine print_validation_report(result)

        type(dataset_validation_result_type), intent(in) :: result

        integer :: i

        print *
        print *, "===== CRM dataset validation ====="
        print *, "Runs:    ", result%n_runs
        print *, "Valid:   ", result%n_valid_runs
        print *, "Invalid: ", result%n_invalid_runs
        print *

        do i = 1, result%n_runs

            if (result%run_results(i)%is_valid) cycle

            print *, "Dataset entry ", i, " is invalid:"

            if (result%run_results(i)%n_duplicate_alpha > 0) then
                print *, "  - duplicate alpha values: ", &
                         result%run_results(i)%n_duplicate_alpha
            end if

            if (.not. result%run_results(i)%alpha_sorted) then
                print *, "  - alpha values are not sorted"
            end if

            if (result%run_results(i)%n_invalid_values > 0) then
                print *, "  - invalid values: ", &
                         result%run_results(i)%n_invalid_values
            end if

            print *

        end do

    end subroutine print_validation_report
    
end module dataset_validation