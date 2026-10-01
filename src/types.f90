module types
    use iso_fortran_env, only: real64
    implicit none

    public :: aerodynamic_polar_type
    public :: aerodynamic_dataset_type
    public :: run_info_type
    public :: aero_run_type
    public :: aero_dataset_type
    public :: aero_model_type
    public :: run_selection_type

    type :: aerodynamic_polar_type

        real(real64) :: reynolds
        real(real64) :: mach

        real(real64), allocatable :: alpha(:)
        real(real64), allocatable :: cl(:)
        real(real64), allocatable :: cd(:)
        real(real64), allocatable :: cm(:)

    end type aerodynamic_polar_type

    type :: aerodynamic_dataset_type
        type(aerodynamic_polar_type), allocatable :: polars(:)
    end type aerodynamic_dataset_type

    type :: run_info_type

        integer :: test
        integer :: run
        integer :: series

        integer :: config
        integer :: confts
        integer :: conft

        character(len=:), allocatable :: filename
    
    end type run_info_type

    type :: aero_run_type

        type(run_info_type) :: info

        real(real64), allocatable :: alpha(:)
        real(real64), allocatable :: mach(:)
        real(real64), allocatable :: reynolds(:)

        real(real64), allocatable :: cl(:)
        real(real64), allocatable :: cd(:)
        real(real64), allocatable :: cm(:)

    end type aero_run_type

    type :: aero_dataset_type

        type(aero_run_type), allocatable :: runs(:)

    end type aero_dataset_type

    type :: aero_model_type

        real(real64), allocatable :: reynolds_grid(:)
        real(real64), allocatable :: mach_grid(:)
        real(real64), allocatable :: alpha_grid(:)

        real(real64), allocatable :: cl(:, :, :)
        real(real64), allocatable :: cd(:, :, :)
        real(real64), allocatable :: cm(:, :, :)

    end type aero_model_type

    type :: run_selection_type

        integer :: config
        integer :: confts
        integer :: conft
    
    end type run_selection_type
    
end module types