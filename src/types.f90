module types
    use iso_fortran_env, only: real64
    implicit none

    public :: aerodynamic_polar_type, aerodynamic_dataset_type

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
    
end module types