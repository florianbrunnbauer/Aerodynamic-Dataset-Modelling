module types
    use iso_fortran_env, only: real64
    implicit none


    !--------------------------------
    !Types for X-Foil-like data
    !--------------------------------

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

    !--------------------------------
    !Multiple types for dataset management
    !--------------------------------

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

    type :: run_selection_type

        integer :: config
        integer :: confts
        integer :: conft
    
    end type run_selection_type

    !--------------------------------
    !Types for validation results
    !--------------------------------

    type :: validation_result_type

        logical :: is_valid = .true.

        logical :: arrays_allocated = .true.
        logical :: consistent_sizes = .true.
        logical :: enough_points = .true.
        logical :: values_finite = .true.
        logical :: alpha_sorted = .true.
        logical :: mach_reynolds_valid = .true.

        integer :: n_points = 0
        integer :: n_duplicate_alpha = 0
        integer :: n_invalid_values = 0

    end type validation_result_type

    type :: dataset_validation_result_type

        logical :: is_valid = .true.

        integer :: n_runs = 0
        integer :: n_valid_runs = 0
        integer :: n_invalid_runs = 0

        type(validation_result_type), allocatable :: run_results(:)

    end type dataset_validation_result_type

    !--------------------------------
    ! Types for dataset characterisation
    !--------------------------------
    
    type :: run_characterisation_type
    
        type(run_info_type) :: info
    
        integer :: n_points = 0
    
        real(real64) :: alpha_min = 0.0_real64
        real(real64) :: alpha_max = 0.0_real64
    
        real(real64) :: mach_mean = 0.0_real64
        real(real64) :: mach_min  = 0.0_real64
        real(real64) :: mach_max  = 0.0_real64
    
        real(real64) :: reynolds_mean = 0.0_real64
        real(real64) :: reynolds_min  = 0.0_real64
        real(real64) :: reynolds_max  = 0.0_real64
    
    end type run_characterisation_type
    
    
    type :: dataset_characterisation_type
    
        integer :: n_runs = 0
    
        type(run_characterisation_type), allocatable :: runs(:)
    
    end type dataset_characterisation_type

    !--------------------------------
    ! Types for dataset grouping
    !--------------------------------

    type :: mach_group_type

        real(real64) :: nominal_mach = 0.0_real64

        integer, allocatable :: run_indices(:)

    end type mach_group_type

    type :: reynolds_group_type

        real(real64) :: nominal_reynolds = 0.0_real64

        type(mach_group_type), allocatable :: mach_groups(:)

    end type reynolds_group_type

    type :: grouped_dataset_type

        type(reynolds_group_type), allocatable :: reynolds_groups(:)

    end type grouped_dataset_type

    !--------------------------------
    ! Types for repeatability analysis
    !--------------------------------

    type :: repeatability_group_type

        real(real64) :: nominal_reynolds = 0.0_real64
        real(real64) :: nominal_mach = 0.0_real64

        integer :: n_runs = 0
        integer :: n_points = 0

        real(real64) :: alpha_min = 0.0_real64
        real(real64) :: alpha_max = 0.0_real64

        real(real64), allocatable :: alpha(:)

        real(real64), allocatable :: cl_mean(:)
        real(real64), allocatable :: cl_std(:)
        real(real64), allocatable :: cl_spread(:)

        real(real64), allocatable :: cd_mean(:)
        real(real64), allocatable :: cd_std(:)
        real(real64), allocatable :: cd_spread(:)

        real(real64), allocatable :: cm_mean(:)
        real(real64), allocatable :: cm_std(:)
        real(real64), allocatable :: cm_spread(:)

    end type repeatability_group_type


    type :: dataset_repeatability_type

        integer :: n_groups = 0

        type(repeatability_group_type), allocatable :: groups(:)

    end type dataset_repeatability_type

    !--------------------------------
    ! Types for representative dataset
    !--------------------------------
    
    type :: representative_mach_type
    
        real(real64) :: nominal_mach = 0.0_real64
    
        integer :: run_index = 0
    
    end type representative_mach_type
    
    
    type :: representative_reynolds_type
    
        real(real64) :: nominal_reynolds = 0.0_real64
    
        type(representative_mach_type), allocatable :: mach_groups(:)
    
    end type representative_reynolds_type
    
    
    type :: representative_dataset_type
    
        type(representative_reynolds_type), allocatable :: reynolds_groups(:)
    
    end type representative_dataset_type

    !--------------------------------
    ! Types for atmosphere
    !--------------------------------

    type :: atmosphere_state_type
        real(real64) :: geometric_altitude=0.0_real64             ! [m above sea level]
        real(real64) :: geopotential_altitude=0.0_real64          ! [m]
        real(real64) :: temperature=0.0_real64                    ! [K]
        real(real64) :: pressure=0.0_real64                       ! [Pa]
        real(real64) :: density=0.0_real64                        ! [kg/m^3]
        real(real64) :: speed_of_sound=0.0_real64                 ! [m/s]
        real(real64) :: dynamic_viscosity=0.0_real64              ! [Pa s = kg/(m s)]
    end type atmosphere_state_type

    !--------------------------------
    ! Types for flight conditions
    !--------------------------------

    type :: flight_condition_type

        type(atmosphere_state_type) :: air
        logical :: accepted=.false.
        integer :: atmosphere_stat = -1
        integer :: coefficient_stat = -1
        real(real64) :: alpha = 0.0_real64                      ! degrees
        real(real64) :: mach = 0.0_real64                       ! dimensionless
        real(real64) :: reference_length = 0.0_real64           ! m; definition used for dataset Re
        real(real64) :: nominal_reynolds = 0.0_real64
        real(real64) :: reynolds_tolerance = 0.0_real64         ! relative, explicit caller policy
        real(real64) :: speed = 0.0_real64                      ! m/s
        real(real64) :: dynamic_pressure = 0.0_real64           ! Pa
        real(real64) :: reynolds = 0.0_real64
        real(real64) :: relative_reynolds_mismatch = 0.0_real64
        real(real64) :: observed_reynolds_min = 0.0_real64
        real(real64) :: observed_reynolds_max = 0.0_real64
        real(real64) :: cl = 0.0_real64, cd = 0.0_real64, cm = 0.0_real64

    end type

    type :: reference_conditions

        real(real64) :: reference_length   = 0.0_real64
        real(real64) :: reference_area     = 0.0_real64
        real(real64) :: reference_chord    = 0.0_real64
        real(real64) :: re_tolerance       = 0.0_real64
        integer      :: re_number_position = 0.0_real64

    end type

end module types