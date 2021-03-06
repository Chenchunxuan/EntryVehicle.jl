"""
Aerodynamics.jl contains code to compute the aerodynamics coefficients for
a given Vehicle
Currently using a Newton's Panel Method for computing the coefficients in the
hypersonic regime.
See the paper:
Analytic Hypersonic Aerodynamics for Conceptual Design of Entry Vehicles
by Grant and Braun.


The Frame of Reference considered for aerodynamic computation is defined as follows:
Z : Along the nose of the entry capsule (axis of symmetry revolution)
X, Y : Parameterizing the base plan of the vehicle (perpendicular to Z)

"""

#=
# TO DO: Evaluate the use of the following structure potentially

abstract type Aerodynamics{T} end

struct ThreeDOFAero{T} <: Aerodynamics
    C_D::Array{T, 2}
    C_L::Array{T, 2}
end

struct SixDOFAero{T} <: Aerodynamics
    forces
    moments
    damping
end

=#



function exponential_atmosphere(h,ρ0,H)
    #ρ0 = 0.0158 #kg/m3 here #*10^9 #0.026455*10^9 #sea level density (kg/km^3)
    #h0 = 9.35458*1e3 #scale height on Mars(m)
    #ρ0 = 1.22 #kg/m3
    #h0 = 8000.0
    ρ = ρ0*exp(-h/H)
end

function speed_sound(h)
    #returns speed of sound with respect to altitude (fit model for h in m)
    #h in M (meters)
    #martian atmopshere data
    # See Advances in Entry Guidance paper by Manrique
    β0 = 223.8
    β1 = -0.0002004
    β2 = -1.588e-8
    β3 = 1.404e-13
    v_s = β0 + β1*h + β2*h^2 + β3*h^3
    return v_s
end


#test for offline coefficients computation

function compute_aero2(vehicle::Vehicle{T}, α::T)  where {T}
    #general case: v is the relative velocity of spacecraft wrt atm
    #Compute the Coefficients for a Vehicle "vechile" with spherecone type of
    #geometry for a speicfic value of angle of attack α
    #damping should be true if want to be included, false otherwise

    δ = vehicle.geometry.δ
    r_min = vehicle.geometry.r_min
    r_cone = vehicle.geometry.r_cone
    r_G = vehicle.r_com

    CF_aero_body = [0.0;0.0;0.0]
    Cτ_aero_body = [0.0;0.0;0.0]
    Cτ_damping = [0.0;0.0;0.0]
    v_body = [sin(α), 0.0, cos(α)]
    #@show(norm(v))
    #@show(norm(v_body))
    dr = 0.1
    dv = pi/10.0
    A = 0.0
    #A_cone = (pi*r_cone*sqrt(r_cone^2 + (r_cone/tan(δ))^2)) #m^2
    A_ref = pi*r_cone^2
    L_ref = r_cone
    for r_i in r_min:dr:r_cone
        for a in 0:dv:(2*pi-dv)
            n̂ = [cos(a)*cos(δ); sin(a)*cos(δ); sin(δ)] #normal outward
            dA = r_i*dv*dr/sin(δ) #dA in m^2pos_end, state_end
            dA = dA #dA in m^2
            r_element = [r_i*cos(a); r_i*sin(a); (r_cone-r_i)/tan(δ)]
            A = A + dA
            if n̂'*v_body > 0
                #dC = dot(n̂, v_body/norm(v_body))*dA*n̂
                #F_element = -0.5*exponential_atmosphere(h)*(norm(v_body)^2)*dC
                F_element = n̂'*v_body*dA*n̂*2*(n̂'*v_body)
                τ_element = cross((r_element-r_G), F_element)
                CF_aero_body = CF_aero_body + F_element #m^2
                Cτ_aero_body = Cτ_aero_body + τ_element #m^3
                Cτ_damping[1] += (-4.0*(n̂'*v_body)*((cross(r_element-r_G, n̂)[1])^2)*dA)/(A_ref*(L_ref^2))
                Cτ_damping[2] += (-4.0*(n̂'*v_body)*((cross(r_element-r_G, n̂)[2])^2)*dA)/(A_ref*(L_ref^2))
                Cτ_damping[3] += (-4.0*(n̂'*v_body)*((cross(r_element-r_G, n̂)[3])^2)*dA)/(A_ref*(L_ref^2))
            end
        end
    end
    return CF_aero_body/A_ref, Cτ_aero_body/(A_ref*L_ref), Cτ_damping #CF_aero_body*(A_cone/A), Cτ_aero_body*(A_cone/A); #CF_aero_body, Cτ_aero_body  #
end

function table_aero(vehicle::Vehicle{T}) where {T}
    α = 0.0:1.0:359.0
    n = length(α)
    table_CF = zeros(n, 3)
    table_Cτ = zeros(n, 3)
    for i = 1:n
        CF, Cτ = compute_aero2(vehicle, α[i]*pi/180)
        table_CF[i, :] = CF
        table_Cτ[i, :] = Cτ
    end
    return table_CF, table_Cτ
end

function compute_aero_sphere(vehicle::Vehicle{T}, α::T) where {T}
    #general case: v is the relative velocity of spacecraft wrt atm

    δ = vehicle.geometry.δ
    r_min = vehicle.geometry.r_min
    r_cone = vehicle.geometry.r_cone
    r_G = vehicle.r_com

    CF_aero_body = [0.0;0.0;0.0]
    Cτ_aero_body = [0.0;0.0;0.0]
    Cτ_damping = [0.0;0.0;0.0]
    v_body = [sin(α), 0.0, cos(α)] #okay convention chosen, fair
    l = (r_cone-r_min)/tan(δ)
    dz = 0.1
    dv = pi/10.0
    A = 0.0
    r_sphere = r_min/cos(δ) #radius where cone is cut
    h = r_sphere*(1-sin(δ)) #height above the cut
    A_sphere = pi*(h^2+r_min^2) #m^2 # overall area of the spherical cap
    A_ref = pi*r_sphere^2
    L_ref = r_sphere
    for z in r_sphere-h:dz:r_sphere #check that
        for a in 0:dv:(2*pi-dv)
            n̂ = [1*cos(a)*sqrt(1-(z/r_sphere)^2); sin(a)*sqrt(1-(z/r_sphere)^2); z/r_sphere] #normal outward
            dA = (sqrt(r_sphere^2-z^2)*dv)*dz #dA in m^2
            dA = dA #dA in m^2
            r_element = [sqrt(r_sphere^2-z^2)*cos(a); sqrt(r_sphere^2-z^2)*sin(a); l-r_sphere+h+z]
            A = A + dA
            if n̂'*v_body > 0
                F_element = n̂'*v_body*dA*n̂*2*(n̂'*v_body)
                τ_element = cross((r_element-r_G), F_element) #okay computed at COM
                CF_aero_body = CF_aero_body + F_element #m^2
                Cτ_aero_body = Cτ_aero_body + τ_element #m^3
                Cτ_damping[1] += (-4.0*(n̂'*v_body)*((cross(r_element-r_G, n̂)[1])^2)*dA)/(A_ref*(L_ref^2))
                Cτ_damping[2] += (-4.0*(n̂'*v_body)*((cross(r_element-r_G, n̂)[2])^2)*dA)/(A_ref*(L_ref^2))
                Cτ_damping[3] += (-4.0*(n̂'*v_body)*((cross(r_element-r_G, n̂)[3])^2)*dA)/(A_ref*(L_ref^2))
            end
        end
    end
    return CF_aero_body/A_ref, Cτ_aero_body/(A_ref*L_ref), Cτ_damping #CF_aero_body*(A_sphere/A), Cτ_aero_body*(A_sphere/A)
end

function table_aero_spherecone(vehicle::Vehicle{T}) where {T}
    #Based on traditional notation, here this function gives CA, -CY, CN (or -CX, -CY, -CZ)
    #BUT as I changed the order, I actually return in this order: CN, -CY, CA (That's for FORCES)

    # unpack geometry and COM location for computation
    δ = vehicle.geometry.δ
    r_min = vehicle.geometry.r_min
    r_cone = vehicle.geometry.r_cone
    r_G = vehicle.r_com

    α = 0.0:1.0:359.0
    n = length(α)
    table_CF = zeros(n, 3)
    table_Cτ = zeros(n, 3)
    table_damping = zeros(n, 3)
    r_sphere = r_min/cos(δ) #radius where cone is cut
    A_ref_s = pi*r_sphere^2
    L_ref_s = r_sphere
    A_ref_c = pi*r_cone^2
    L_ref_c = r_cone
    A_ref = pi*r_cone^2
    L_ref = r_cone
    for i = 1:n
        CF_cone, Cτ_cone, Cd_cone = compute_aero2(vehicle, α[i]*pi/180)
        CF_sphere, Cτ_sphere, Cd_sphere = compute_aero_sphere(vehicle, α[i]*pi/180)
        table_CF[i, :] = (CF_cone*A_ref_c+CF_sphere*A_ref_s)/A_ref
        table_Cτ[i, :] = (Cτ_cone*A_ref_c*L_ref_c+Cτ_sphere*A_ref_s*L_ref_s)/(A_ref*L_ref)
        table_damping[i, :] = (Cd_cone*A_ref_c*L_ref_c+Cd_sphere*A_ref_s*L_ref_s)/(A_ref*L_ref)
    end
    return table_CF, table_Cτ, table_damping
end

function drag_lift_coeff(vehicle::Vehicle{T}, α::T) where {T}

    # unpack geometry and COM location for computation
    δ = vehicle.geometry.δ
    r_min = vehicle.geometry.r_min
    r_cone = vehicle.geometry.r_cone
    r_G = vehicle.r_com

    # computation
    r_sphere = r_min/cos(δ) #radius where cone is cut
    A_ref_s = pi*r_sphere^2
    L_ref_s = r_sphere
    A_ref_c = pi*r_cone^2
    L_ref_c = r_cone
    A_ref = pi*r_cone^2
    L_ref = r_cone
    CF_cone, Cτ_cone = compute_aero2(vehicle, α)
    CF_sphere, Cτ_sphere = compute_aero_sphere(vehicle, α)
    CF = (CF_cone*A_ref_c+CF_sphere*A_ref_s)/A_ref #this is CN, -CY, CA (in this order)
    Cτ = (Cτ_cone*A_ref_c*L_ref_c+Cτ_sphere*A_ref_s*L_ref_s)/(A_ref*L_ref)
    CN = CF[1]
    CA = CF[3]
    CD = CA*cos(α)+CN*sin(α)
    CL = CN*cos(α)-CA*sin(α)
    return CD, CL
end

function drag_lift_table(vehicle::Vehicle{T}) where {T}

    # unpack geometry and COM location for computation
    δ = vehicle.geometry.δ
    r_min = vehicle.geometry.r_min
    r_cone = vehicle.geometry.r_cone
    r_G = vehicle.r_com

    # Fill in offline table
    α = 0.0:1.0:180.0
    n = length(α)
    table_CD = zeros(n)
    table_CL = zeros(n)
    for i=1:length(α)
        CD, CL = drag_lift_coeff(vehicle, α[i]*pi/180)
        table_CD[i] = CD
        table_CL[i] = CL
    end
    return table_CD, table_CL
end

function coeff_interp_6dof(vehicle::Vehicle{T}) where {T}

    # unpack geometry and COM location for computation
    δ = vehicle.geometry.δ
    r_min = vehicle.geometry.r_min
    r_cone = vehicle.geometry.r_cone
    r_G = vehicle.r_com

    # compute coefficients
    table_CF, table_Cτ, table_damping = table_aero_spherecone(δ, r_min, r_cone, r_G)
    #Sequence for interpolation of aerodynamics coefficients
    α = 0.0:1.0:181.0
    tableFX = table_CF[:,1]
    tableFY = table_CF[:,2]
    tableFZ = table_CF[:,3]
    tableτX = table_Cτ[:,1]
    tableτY = table_Cτ[:,2]
    tableτZ = table_Cτ[:,3]
    tabledx = table_damping[:, 1]
    tabledy = table_damping[:, 2]
    tabledz = table_damping[:, 3]
    order = 14
    C_FX = compute_chebyshev_coefficients_aerodynamics(α, tableFX[1:182], order)
    C_FY = compute_chebyshev_coefficients_aerodynamics(α, tableFY[1:182], order)
    C_FZ = compute_chebyshev_coefficients_aerodynamics(α, tableFZ[1:182], order)
    C_τX = compute_chebyshev_coefficients_aerodynamics(α, tableτX[1:182], order)
    C_τY = compute_chebyshev_coefficients_aerodynamics(α, tableτY[1:182], order)
    C_τZ = compute_chebyshev_coefficients_aerodynamics(α, tableτZ[1:182], order)
    DX = compute_chebyshev_coefficients_aerodynamics(α, tabledx[1:182], order)
    DY = compute_chebyshev_coefficients_aerodynamics(α, tabledy[1:182], order)
    DZ = compute_chebyshev_coefficients_aerodynamics(α, tabledz[1:182], order)
    return C_FX,C_FY,C_FZ,C_τX,C_τY,C_τZ,DX,DY,DZ
end


# UNIT TESTING using reference paper

# Defining Vehicle used in the reference paper for coefficients comparison

function define_test_vehicle()
    δ = 70*pi/180                       # Semi-angle at apex of the capsule
    r_cone = 0.762/2                    # Radius of base of the vehicle
    r_min = 0.09144*cos(δ)              # Smallest Radius for vehicle (top)
    r_G = [0.0; 0.0; -0.1]              # Position Center of Gravity in Vehicle Frame
    AeroTestGeometry = SphereConeGeometry{Float64}(δ, r_cone, r_min)
    m = 1.0                             # irrelevant for aero computation here
    J = Matrix(Diagonal(ones(3)))          # irrelevant for aero computation here
    J_inv = J                           # irrelevant for aero computation here
    AeroTestVehicle = Vehicle{Float64}(AeroTestGeometry, m, J, J_inv, r_G)
    return AeroTestVehicle
end

# Aerodynamics coefficients

# Plot forces coefficients
function aero_coeff_plot_forces!(vehicle::Vehicle{Float64}, α_max::Float64)
    # Function computing spherecone coefficients for geometry in reference paper
    # For Paper comparison damping should be
    t_coeff_force, t_coeff_moment, t_damping = table_aero_spherecone(vehicle)
    #@show(typeof(t_coeff_force))
    α = 0.0:1.0:α_max
    ind_lim = Int(round(α_max))+1
    plt = plot(layout = (1, 3))
    Plots.plot!(α, [t_coeff_force[1:ind_lim, 1],
                        t_coeff_force[1:ind_lim, 2],
                        t_coeff_force[1:ind_lim, 3]],
                layout = (1, 3),
                legend = false,
                xlabel = ["angle of attack" "angle of attack" "angle of attack"],
                ylabel = ["values" "" ""],
                title = ["CX" "CY" "CZ"])
    display(plt)
    return nothing
end


# Plot moments coefficients
function aero_coeff_plot_moments!(vehicle::Vehicle{Float64}, α_max::Float64)
    # Function computing spherecone coefficients for geometry in reference paper
    # For Paper comparison damping should be
    t_coeff_force, t_coeff_moment, t_damping = table_aero_spherecone(vehicle)
    α = 0.0:1.0:α_max
    ind_lim = Int(round(α_max))+1
    plt = plot(layout = (1, 3))
    Plots.plot!(α, [t_coeff_moment[1:ind_lim, 1],
                        t_coeff_moment[1:ind_lim, 2],
                        t_coeff_moment[1:ind_lim, 3]],
                layout = (1, 3),
                legend = false,
                xlabel = ["angle of attack" "angle of attack" "angle of attack"],
                ylabel = ["values" "" ""],
                title = ["CL" "CM" "CN"])
    display(plt)
    return nothing
end

# Plot damping coefficients
function aero_coeff_plot_damping!(vehicle::Vehicle{Float64}, α_max::Float64)
    # Function computing spherecone coefficients for geometry in reference paper
    # For Paper comparison damping should be
    t_coeff_force, t_coeff_moment, t_damping = table_aero_spherecone(vehicle)
    α = 0.0:1.0:α_max
    ind_lim = Int(round(α_max))+1
    plt = plot(layout = (1, 3))
    Plots.plot!(α, [t_damping[1:ind_lim, 1],
                        t_damping[1:ind_lim, 2],
                        t_damping[1:ind_lim, 3]],
                layout = (1, 3),
                legend = false,
                xlabel = ["angle of attack" "angle of attack" "angle of attack"],
                ylabel = ["values" "" ""],
                title = ["CdampL" "CdampM" "CdampN"])
    display(plt)
    return nothing
end

# Speed of Sound with respect to altitude
function plot_speed_of_sound(increment, alt_max)
    # input in meters
    plt = plot()
    H = 0.0:increment:alt_max
    V = [speed_sound(h) for h in H]
    Plots.plot!(H/1e3, V,
                xlabel = "Altitude (km)",
                ylabel = "Speed of sound (m.s-1)",
                title = "Mars speed of sound profile")
    display(plt)
    return nothing
end


#=
# Actual Test
using LinearAlgebra
using Plots
include("Vehicles.jl")
TestVehicle = define_test_vehicle()
aero_coeff_plot_forces!(TestVehicle, 60.0)
aero_coeff_plot_moments!(TestVehicle, 60.0)
aero_coeff_plot_damping!(TestVehicle, 60.0)
=#
