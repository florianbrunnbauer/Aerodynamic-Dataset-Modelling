program main
    use iso_fortran_env, only: real64
    use types, only: aerodynamic_dataset_type
    use data_io, only: read_airfoil_data
    use linear_interpolation, only: linear_interpolate
    implicit none
    
    character(len=*), parameter :: filename = "../data/naca0012.csv"
    type(aerodynamic_dataset_type) :: dataset
    real(real64) :: interpolater_value, interpolated_value

    ! Read the airfoil data from the CSV file
    call read_airfoil_data(filename, dataset)

    ! Example usage of linear interpolation
    print *, "Enter an alpha value for interpolation:"
    read(*,*) interpolater_value

    call linear_interpolate(dataset%polars(1)%alpha, dataset%polars(1)%cl, &
                            interpolater_value, interpolated_value)

    print *, "Interpolated Cl value at alpha =", interpolater_value, "is", interpolated_value

end program main