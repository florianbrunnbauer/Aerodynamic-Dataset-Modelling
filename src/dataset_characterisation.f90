module dataset_characterisation

    use iso_fortran_env, only: real64

    use types, only: aero_run_type, aero_dataset_type, &
                     run_characterisation_type, &
                     dataset_characterisation_type

    implicit none

    private

    public :: characterise_run, characterise_dataset, print_characterisation_report 

contains

    subroutine characterise_run(run, result)

        type(aero_run_type), intent(in) :: run
        type(run_characterisation_type), intent(out) :: result

        integer :: n_points

        n_points = size(run%alpha)

        result%info = run%info

        result%n_points = n_points

        result%alpha_min = minval(run%alpha)
        result%alpha_max = maxval(run%alpha)

        result%mach_mean = sum(run%mach) / real(n_points, real64)
        result%mach_min  = minval(run%mach)
        result%mach_max  = maxval(run%mach)

        result%reynolds_mean = sum(run%reynolds) / real(n_points, real64)

        result%reynolds_min = minval(run%reynolds)
        result%reynolds_max = maxval(run%reynolds)

    end subroutine characterise_run

    subroutine characterise_dataset(dataset, result)

        type(aero_dataset_type), intent(in) :: dataset
        type(dataset_characterisation_type), intent(out) :: result

        integer :: i

        result%n_runs = size(dataset%runs)

        allocate(result%runs(result%n_runs))

        do i = 1, result%n_runs

            call characterise_run(dataset%runs(i), result%runs(i))

        end do

    end subroutine characterise_dataset

    subroutine print_characterisation_report(result)

        type(dataset_characterisation_type), intent(in) :: result

        integer :: i

        print *
        print *, "=============================================================="
        print *, "CRM DATASET CHARACTERISATION"
        print *, "=============================================================="
        print *

        print '(A)', &
            " Run     N     Alpha min/max       Mach mean       " // &
            "Mach range        Reynolds mean"

        do i = 1, result%n_runs

            print '(I5,2X,I4,3X,F7.3,1X,F7.3,3X,F9.5,3X,' // &
                  'F9.5,1X,F9.5,3X,ES12.4)', &
                result%runs(i)%info%run, &
                result%runs(i)%n_points, &
                result%runs(i)%alpha_min, &
                result%runs(i)%alpha_max, &
                result%runs(i)%mach_mean, &
                result%runs(i)%mach_min, &
                result%runs(i)%mach_max, &
                result%runs(i)%reynolds_mean

        end do

        print *

    end subroutine print_characterisation_report

end module dataset_characterisation