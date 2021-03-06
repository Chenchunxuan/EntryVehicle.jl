#6 dof entry vehicle dynamics

#TO DO
#Add break point when reaching the ground
#see integration

include("quaternions.jl")

function entry_vehicle_6dof_dynamics!(ẋ::AbstractVector,x::AbstractVector,#=u::AbstractVector=#params,t::AbstractFloat)
    ## States: X ∈ R^13;
    # x
    # y
    # z
    # q0
    # q1
    # q2
    # q3
    # xdot
    # ydot
    # zdot
    # omega1
    # omega2
    # omega3

    r = view(x,1:3)
    q = view(x,4:7)/(norm(view(x,4:7)))
    v = view(x,8:10)
    ω = view(x,11:13)

    #Parameters
    env = params[:Env]
    vehicle = params[:Vehicle]
    R_p = env.R_p
    ρ0 = env.ρ0
    H = env.H
    μ_p = env.μ_p
    A_ref = params[:A_ref]
    L_ref = params[:L_ref]
    m = vehicle.m
    J = vehicle.J
    Jinv = vehicle.Jinv
    ω_p = env.ω_p
    coeff_interp = params[:coeff_interp]

    ω_mars = @SVector [0.0,0.0,ω_p]
    #Compute aerodnyamic forces
    v_rel = v-cross(ω_mars, r) #velocity of spacecraft wrt atm
    v_body = qrot(qconj(q), v_rel) #velocity of spacecraft wrt atm in body frame
    α = acos(v_body[3]/norm(v_body)) #in fact total angle of attack, positif necessarily
    ϕ_w = atan(v_body[2], v_body[1])
    q_v_b = @SVector [cos(ϕ_w/2), 0.0, 0.0, sin(ϕ_w/2)]

    α = α*180/pi #degrees

    CF = [table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.C_FX);
        table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.C_FY);
        table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.C_FZ)]

    Cτ = [table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.C_τX);
        table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.C_τY);
        table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.C_τZ)] #given the plotted coeff curve but...

    Cd = [table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.DX);
        table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.DY);
        table_aero_chebyshev(α, 0.0, 181.0, coeff_interp.DZ)]

    Cτ_final = @SVector [Cτ[1] - ω[1]*(L_ref/norm(v_body))*Cd[1],
                Cτ[2] - ω[2]*(L_ref/norm(v_body))*Cd[2],
                Cτ[3] - ω[3]*(L_ref/norm(v_body))*Cd[3]]

    h = (norm(r)-R_p)
    F_aero_v = -0.5*exponential_atmosphere(h,ρ0,H)*((norm(v_rel))^2)*CF*A_ref
    τ_aero_v = -0.5*exponential_atmosphere(h,ρ0,H)*((norm(v_rel))^2)*Cτ_final*A_ref*L_ref
    F_aero_eci = qrot(qmult(q, q_v_b), F_aero_v)
    τ_aero_body = qrot(q_v_b, τ_aero_v)

    #Controller
    q_ref = Q
    kd = 100.0 #30.0
    kp = -100.0 #-20.0
    q_err = qmult(qconj(q), q_ref) # perfect measurements
    τ_c = -kd*(ω)-kp*q_err[2:4]

    #Compute gravitation & J2 acceleration
    F_grav_eci = -m*μ_p*r/((norm(r)^3))
    #=F_J2_eci = [J2*r[1]/norm(r)^7*(6*r[3]-1.5*(r[1]^2+r[2]^2)),
     J2*r[2]/norm(r)^7*(6*r[3]-1.5*(r[1]^2+r[2]^2)),
     J2*r[3]/norm(r)^7*(3*r[3]-4.5*(r[1]^2+r[2]^2))]=#

    #Compute total forces and moments
    F_total_eci = F_grav_eci + F_aero_eci #+ F_J2_eci
    τ_total_body = τ_aero_body # computed at COM

    #Compute state derivatives
    ẋ[1:3] = v # velocity in planet fixed frame
    ẋ[4:7] = 0.5*qmult(q, [0.; ω]) # quaternion derivatives
    ẋ[8:10] = (F_total_eci/m) # acceleration in planet fixed frame
    ẋ[11:13] = Jinv*(τ_total_body-cross(ω, J*ω)) # euler equation for ω
    return ẋ
end
