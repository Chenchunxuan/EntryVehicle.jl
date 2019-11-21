#test ellipsoid lower dimensional system
using LinearAlgebra
using DifferentialEquations
using Plots
using Convex
using SCS
using Distributions
using Random
using Mosek, Mosek.Ext
using JuMP
using ECOS #does not solver SDPs
using MathProgBase
using Gurobi #works properly but
using MathOptInterface
using MosekTools
pyplot()
gr()

function sys!(du,u,p,t)
 du[1] = u[2]
 du[2] = -u[1]+u[1]^2
end

u0 = [0.1;0.13]
tspan = (0.0,400.0)
prob = ODEProblem(sys!,u0,tspan)
sol = DifferentialEquations.solve(prob, reltol=1e-10,abstol=1e-10)

plot(sol, vars=(1,2))


#initialization
u0 = [0.1;0.13]
Q0 = Matrix(Diagonal([0.0001, 0.0001]))
A0 = inv(sqrt(Q0)) #matrix at t=0.0
b0 = -A0*u0 #center at t=0.0

Δt = 3000.0 #length simulation
dt = 1.0
T = 0.0:dt:Δt
n = 2

#######################
###### FUNCTIONS ######
#######################

function ellipse2points(A, b)
    #A is the matrix we obtain from the previous step
    n = length(b)
    points = zeros(n, 6*n+1)
    M = -inv(A)*b #center of the ellipse considered
    #L = A'*A
    #F = eigen(L)
    #W = F.vectors
    #z = F.values
    W = inv(A)
    #@show(z)
    #@show(b)
    for i = 1:n
        points[:, 6*i-5] = M + 0.5*W[:, i]
        points[:, 6*i-4] = M - 0.5*W[:, i]
        points[:, 6*i-3] = M - 0.8*W[:, i]
        points[:, 6*i-2] = M + 0.8*W[:, i]
        points[:, 6*i-1] = M - W[:, i]
        points[:, 6*i] = M + W[:, i]
    end
    points[:, 6*n+1] = M
    return points #return 2n+1 points
end

function points2ellipse(X)
    #X is the set of points propagated through the non linear dynamics
    n, m = size(X);
    #Define Convex Optimization Problem using Convex.jl
    A = Semidefinite(n) #I think should be positivedefinite
    b = Variable(n)
    problem = maximize(logdet(A), vcat([norm(A*X[:, i]+b, 2)<=1 for i = 1:1:m], [A[k, j]==A[j, k] for k=1:n for j=1:n])) #[A\Matrix{Float64}(I, n, n)]))
    Convex.solve!(problem, SCSSolver(verbose = true))
    b = b.value
    A = A.value
    return A, b
end

function prop_points_continuous(X, dt)
    tspan = (0.0,dt) #autonomous system so don't care
    m = length(X[1, :])
    Xnew = zeros(size(X))
    for i=1:1:m
        prob = ODEProblem(duffing!, X[:, i], tspan, p)
        sol = solve(prob, reltol=1e-10,abstol=1e-10)
        Xnew[:, i] = sol.u[end]
    end
    return Xnew
end


function prop(A1, b1)
    blist = zeros(n, length(T))
    Alist = zeros(n, n, length(T))
    centerlist = zeros(n, length(T))
    XX = zeros(n, 6*n+1, length(T))
    for i=1:1:length(T)
        t = T[i]
        @show(t)
        X1 = ellipse2points(A1, b1) #return a set of points
        X2 = prop_points_continuous(X1, dt) #prop_points(X1, t, dt, u, w)
        A2, b2 = points2ellipse_mosek(X2)
        blist[:, i] = b1
        Alist[:, :, i] = A1
        centerlist[:, i] = -inv(A1)*b1
        A1 = A2
        b1 = b2
        XX[:, :, i] = X1
        #@show(X1)
    end
    return Alist, blist, centerlist, XX
end

function ellipse2points2(A, b)
    #A is the matrix we obtain from the previous step
    n = length(b)
    angles = 0.0:0.2:2*pi
    B = zeros(2, length(angles))
    for i = 1:1:length(angles)
          B[:, i] = [cos(angles[i]) - b[1], sin(angles[i]) - b[2]]
    end
    ellipse  = A \ B
    return ellipse
end

function points2ellipse(X)
    #X is the set of points propagated through the non linear dynamics
    n, m = size(X);
    #Define Convex Optimization Problem using Convex.jl
    A = Semidefinite(n) #I think should be positivedefinite
    b = Variable(n)
    problem = maximize(logdet(A), vcat([norm(A*X[:, i]+b, 2)<=1 for i = 1:1:m], [A[k, j]==A[j, k] for k=1:n for j=1:n])) #[A\Matrix{Float64}(I, n, n)]))
    Convex.solve!(problem, SCSSolver(verbose = true, max_iters=50000))
    b = b.value
    A = A.value
    return A, b
end

function prop_points_continuous(X, dt)
    tspan = (0.0,dt) #autonomous system so don't care
    m = length(X[1, :])
    Xnew = zeros(size(X))
    for i=1:1:m
        prob = ODEProblem(sys!, X[:, i], tspan)
        sol = DifferentialEquations.solve(prob, AutoTsit5(Rosenbrock23()), reltol=1e-10,abstol=1e-10)
        Xnew[:, i] = sol.u[end]
    end
    return Xnew
end

function prop2(A1, b1)
    blist = zeros(n, length(T))
    Alist = zeros(n, n, length(T))
    centerlist = zeros(n, length(T))
    angles = 0.0:0.2:2*pi
    XX = zeros(n, length(angles), length(T))
    E = zeros(n, length(angles), length(T)) #store the propagation of the ellipses
    for i=1:1:length(T)
        t = T[i]
        @show(t)
        X1 = ellipse2points2(A1, b1) #return a set of points (big set here)
        X2 = prop_points_continuous(X1, dt) #prop_points(X1, t, dt, u, w)
        A2, b2 = points2ellipse_mosek(X2)
        blist[:, i] = b1
        Alist[:, :, i] = A1
        centerlist[:, i] = -inv(A1)*b1
        E[:, :, i] = X2
        A1 = A2
        b1 = b2
        XX[:, :, i] = X1
        #@show(X1)
    end
    return Alist, blist, centerlist, XX, E
end

function plot_traj_center(centerlist)
    X = zeros(length(T))
    Y = zeros(length(T))
    for j=1:length(T)
        X[j] = centerlist[1, j]#*Re
        Y[j] = centerlist[2, j]#*Re
    end
    Plots.scatter(X, Y)
end

#First method (points extracted along the semi axes)
Alist, blist, centerlist, XX = prop(A0, b0)

#Second method (points extracted all along the ellipse frontier)
Alist, blist, centerlist, XX, E = prop2(A0, b0)


plot_traj_center(centerlist)
j = 1
angles = 0.0:0.01:2*pi
B = zeros(2, length(angles))
for i = 1:1:length(angles)
    B[:, i] = [cos(angles[i]) - blist[1, j], sin(angles[i]) - blist[2, j]]
end

ellipse  = Alist[1:2, 1:2, j] \ B
plot!(ellipse[1, :], ellipse[2, :])
scatter!([centerlist[1, j]],[centerlist[2, j]] )
scatter!(XX[1, :, j], XX[2, :, j])
#title!("simple pendulum - no damping")
#xlabel!("x")
#ylabel!("ẋ")
#Plots.savefig("duffing - 1 sec - 0.001 step - interior points ")

function uncertainty(Alist)
    t = length(Alist[1, 1, :])
    U = zeros(t)
    for i=1:1:t
        U[i] = tr(inv(Alist[:, :, i]))
    end
    Plots.plot(U)
    Plots.xlabel!("time")
    Plots.ylabel!("uncertainty matrix trace")
end

uncertainty(Alist)
Alist[:,:,170]


###############################
######TEST ELLIPSE FIT 2D######
###############################

#test ellipse fitting in 2D
D1 = Uniform(-3, 10)
D2 = Uniform(1, 5)
x1 = zeros(1, 5)
x2 = zeros(1, 5)
rand!(D1, x1)
rand!(D2, x2)
x = vcat(x1, x2)

n, m = size(x);

A = Semidefinite(n)
b = Variable(n)
problem = maximize(logdet(A), vcat([norm(A*x[:, i]+b, 2)<=1 for i = 1:1:m], [A[k, j]==A[j, k] for k=1:n for j=1:n]))

#s = GurobiSolver()
using MathOptInterface
s = SCSSolver()
m = Mose() #need to use MathProgBase I believe
Convex.solve!(problem, s)

problem.status
problem.optval

b = b.value
A = A.value
@show(A) #A is not even symmetric here : problem
@show(inv(A))
@show(b)
angles = 0.0:0.01:2*pi
B = zeros(2, length(angles))
for i = 1:1:length(angles)
      B[:, i] = [cos(angles[i]) - b[1], sin(angles[i]) - b[2]]
end

ellipse  = A \ B
scatter(x[1,:], x[2,:])
plot!(ellipse[1, :], ellipse[2, :])
Y = A\[cos(pi/2)-b[1], sin(pi/2)-b[2]]
scatter!([Y[1]], [Y[2]])
xlims!(-2.0, 11.0)
ylims!(-2.0, 11.0)

#A = [0.2135 -0.0628927; -0.0628927 0.2135]

#D = inv(A'*A)
#V = eigen(inv(A)).values


xc = -inv(A)*b
scatter!([xc[1]], [xc[2]])

scatter!([xc[1]+inv(A)[1, 1]], [xc[2]+inv(A)[2, 1]]) #corresponds to angle = 0.0 in ellipse plotting above in fact
scatter!([xc[1]-inv(A)[1, 1]], [xc[2]-inv(A)[2, 1]])
scatter!([xc[1]-inv(A)[2, 1]], [xc[2]-inv(A)[2, 2]])
scatter!([xc[1]+inv(A)[2, 1]], [xc[2]+inv(A)[2, 2]])


#######################################
########TEST WEAK NONLINEAR SYSTEM#####
#######################################

function sys!(du,u,p,t)
 du[1] = u[2]
 du[2] = -u[1] +u[1]^2
end

#initialization
u0 = [0.1;0.13]
Q0 = Matrix(Diagonal([0.02, 0.01]))
A0 = inv(sqrt(Q0)) #matrix at t=0.0
b0 = -A0*u0 #center at t=0.0

Δt = 1.0 #length simulation
dt = 0.01
T = 0.0:dt:Δt
n = 2



Alist, blist, centerlist, XX, E = prop2(A0, b0)



plot_traj_center(centerlist)
j = 1
angles = 0.0:0.01:2*pi
B = zeros(2, length(angles))
for i = 1:1:length(angles)
    B[:, i] = [cos(angles[i]) - blist[1, j], sin(angles[i]) - blist[2, j]]
end

ellipse  = Alist[1:2, 1:2, j] \ B
plot!(ellipse[1, :], ellipse[2, :])
scatter!([centerlist[1, j]],[centerlist[2, j]] )
scatter!(XX[1, :, j], XX[2, :, j])
scatter!(E[1, :, j], E[2, :, j])
#title!("simple pendulum - no damping")
#xlabel!("x")
#ylabel!("ẋ")
savefig("pendulum - 0.5 sec - 0.05 step")

#simple test on quaternions

theta = 2.1 #radians
q1 = [cos(theta); sin(theta)*[1.0; 0.0; 0.0]] #this is the ref quat
q2 = [cos(theta+0.1); sin(theta+0.1)*[1.0; 0.0;0.0]] #this is the point qi for instance
δq = qmult(qconj(q1), q2)

norm(q1)
norm(q2)
norm(δq)
a = δq[2:end]
Δq = [sqrt(1-a'*a); a]
δq == Δq #okay does not seem that bad

####################################
###########DUFFING OSCILLATOR#######
####################################

function duffing!(du,u,p,t)
    # p = α, β, δ, γ, ω
    α = -1.0 #p[1]
    β = 1.0 #p[2]
    δ = 0.2 #p[3]
    γ = 0.1 #p[4]
    ω = 1.0 #p[5]
    du[1] = u[2]
    du[2] =  γ*p(t)-δ*u[2]-α*u[1]-β*u[1]^3
end


function prop_points_continuous(X, dt, t)
    tspan = (t,t+dt) #autonomous system so don't care #NOT ANYMORE HERE THATS WHY
    m = length(X[1, :])
    Xnew = zeros(size(X))
    for i=1:1:m
        prob = ODEProblem(duffing!, X[:, i], tspan, M)
        sol = DifferentialEquations.solve(prob, AutoTsit5(Rosenbrock23()), reltol=1e-10,abstol=1e-10)
        Xnew[:, i] = sol.u[end]
    end
    return Xnew
end

a=1


function prop2(A1, b1)
    blist = zeros(n, length(T))
    Alist = zeros(n, n, length(T))
    centerlist = zeros(n, length(T))
    angles = 0.0:0.2:2*pi
    #XX = zeros(n, length(angles), length(T))
    #E = zeros(n, length(angles), length(T)) #store the propagation of the ellipses
    XX = zeros(n, 13, length(T))
    E = zeros(n, 13, length(T))
    for i=1:1:length(T)
        t = T[i]
        @show(t)
        X1 = ellipse2points(A1, b1) #return a set of points (big set here)
        X2 = prop_points_continuous(X1, dt, t) #prop_points(X1, t, dt, u, w)
        A2, b2 = points2ellipse_mosek(X2)
        blist[:, i] = b1
        Alist[:, :, i] = A1
        centerlist[:, i] = -inv(A1)*b1
        E[:, :, i] = X2
        A1 = A2
        b1 = b2
        XX[:, :, i] = X1
        #@show(X1)
    end
    return Alist, blist, centerlist, XX, E
end

function ellipse2points2(A, b)
    #A is the matrix we obtain from the previous step
    n = length(b)
    angles = 0.0:0.2:2*pi
    B = zeros(2, length(angles))
    for i = 1:1:length(angles)
          B[:, i] = [cos(angles[i]) - b[1], sin(angles[i]) - b[2]]
    end
    ellipse  = A \ B
    return ellipse
end

function points2ellipse(X)
    #X is the set of points propagated through the non linear dynamics
    n, m = size(X);
    #Define Convex Optimization Problem using Convex.jl
    A = Semidefinite(n) #I think should be positivedefinite
    b = Variable(n)
    problem = maximize(logdet(A), vcat([norm(A*X[:, i]+b, 2)<=1 for i = 1:1:m], [A[k, j]==A[j, k] for k=1:n for j=1:n])) #[A\Matrix{Float64}(I, n, n)]))
    Convex.solve!(problem, SCSSolver(verbose = true, max_iters=50000))
    b = b.value
    A = A.value
    return A, b
end

a=1

function points2ellipse_mosek(X)
    n, m = size(X);
    s = MathOptInterface.LogDetConeTriangle(n)
    model = Model(with_optimizer(Mosek.Optimizer, MSK_DPAR_INTPNT_CO_TOL_DFEAS=10^(-9), MSK_DPAR_INTPNT_CO_TOL_PFEAS=10^(-9), MSK_DPAR_INTPNT_CO_TOL_MU_RED = 10^(-10))) #MSK_DPAR_INTPNT_CO_TOL_INFEAS=10^(-12), MSK_IPAR_INTPNT_MAX_ITERATIONS=1000))
    @variable(model, A[1:n, 1:n], PSD)
    @variable(model, b[1:n])
    @variable(model , t)
    @objective(model, Max, t)
    @constraint(model, con[i = 1:m], [1.0; A*X[:, i]+b] in SecondOrderCone())
    V = [A[i, j] for j in 1:1:n for i in 1:1:j] #vectorize form of the matrix
    @constraint(model, [t;1.0;V] in s)
    #@show(con)
    #MathOptInterface.TimeLimitSec() = 0.5
    JuMP.optimize!(model)
    a = JuMP.termination_status(model)
    @show(a)
    @show(objective_value(model))
    A = JuMP.value.(A)
    b = JuMP.value.(b)
    return A, b
end

function plot_traj_center(centerlist)
    X = zeros(length(T))
    Y = zeros(length(T))
    for j=1:length(T)
        X[j] = centerlist[1, j]#*Re
        Y[j] = centerlist[2, j]#*Re
    end
    Plots.scatter(X, Y)
end


#PHASE PORTRAIT AND STUFF
u0 = [0.1; 10.0]
tspan = (0.0,100.0)
p = [-1.0; 1.0; 0.2; 0.1; 1.0]
M  = t->cos(t)
prob = ODEProblem(duffing!,u0,tspan, M)
sol = DifferentialEquations.solve(prob, reltol=1e-10,abstol=1e-10)

#plot the phase portrait of the system
Plots.plot!(sol, vars=(1,2), legend = false)
sol.u[end]

#Initialization
u0 = [0.1; 10.0]
Q0 = Matrix(Diagonal([0.01, 0.01]))
A0 = inv(sqrt(Q0)) #matrix at t=0.0
b0 = -A0*u0 #center at t=0.0

Δt = 100.0 #length simulation
dt = 1.0
T = 0.0:dt:Δt
n = 2

Alist, blist, centerlist, XX, E = prop2(A0, b0)

plot_traj_center(centerlist)
uncertainty(Alist)
savefig("MC2")

a=1

anim = @animate for j=1:500:5000
    angles = 0.0:0.01:2*pi
    B = zeros(2, length(angles))
    for i = 1:1:length(angles)
        #B[:, i] = [cos(angles[i]) - blist[1, j], sin(angles[i]) - blist[2, j]]
        B[:, i] = [cos(angles[i]), sin(angles[i])]
    end
    ellipse  = Alist[1:2, 1:2, j] \ B
    #Plots.plot(sol, vars=(1,2), legend = false)
    plot(ellipse[1, :], ellipse[2, :], legend = false)
    #xlims!(-0.01, 0.01)
    #ylims!(-0.01, 0.01)
    #scatter!([centerlist[1, j]],[centerlist[2, j]] )
    #scatter!(XX[1, :, j], XX[2, :, j])
    #plot_traj_center(centerlist)
    #scatter!(E[1, :, j], E[2, :, j])
    #xlabel!("position")
    #ylabel!("velocity")
    title!("Ellipse propagation step=$(j)")
end
gif(anim, "test.gif", fps = 2)


#Let's do MC on these systems
using Distributions
using Random

u0 = [0.1; 10.0]
σ_x = 0.1 #actual value of one branch of the semi-axe
σ_y = 0.1
Q0 = Matrix(Diagonal([σ_x^2, σ_y^2]))
A0 = inv(sqrt(Q0)) #matrix at t=0.0
b0 = -A0*u0 #center at t=0.0

Δt = 100.0 #length simulation
dt = 1.0
T = 0.0:dt:Δt
n = 2

D1 = Uniform(u0[1]-σ_x, u0[1]+σ_x)
D2 = Uniform(u0[2]-σ_y, u0[2]+σ_y)
x1 = zeros(1, 1000)
x2 = zeros(1, 1000)
rand!(D1, x1)
rand!(D2, x2)
x = vcat(x1, x2)

function prop_MC(x)
    n, m = size(x)
    saveAT = 1.0
    tspan = (0.0,1000.0)
    traj = zeros(n, 1001, m)
    for i=1:1:m
        Z = zeros(n, 1001)
        u0 = x[:, i]
        #p = [-1.0; 1.0; 0.2; 0.1; 1.0]
        M  = t->cos(t)
        prob = ODEProblem(duffing!,u0,tspan,M)
        sol = DifferentialEquations.solve(prob, saveat = saveAT, abstol = 1e-9, reltol = 1e-9)
        for j =1:1:1001
            Z[:, j] = (sol.u)[j]
        end
        traj[:, :, i] = Z
    end
    return traj
end

traj = prop_MC(x)

Plots.scatter!(traj[1, end, :], traj[2, end, :])
Plots.scatter!(traj[1, 1, :], traj[2, 1, :])

traj[1, 2, :]
traj[2, 2, :]


#check ellipsoid fit after propagation of the points
j = 2
angles = 0.0:0.01:2*pi
B = zeros(2, length(angles))
for i = 1:1:length(angles)
    B[:, i] = [cos(angles[i]) - blist[1, j+1], sin(angles[i]) - blist[2, j+1]]
end

ellipse  = Alist[1:2, 1:2, j+1] \ B
scatter(E[1, :, j], E[2, :, j])
plot!(ellipse[1, :], ellipse[2, :])
scatter!([centerlist[1, j+1]],[centerlist[2, j+1]])
j = 5
scatter(traj[1, j, :], traj[2, j, :])
scatter!(XX[1, :, j], XX[2, :, j])

#Ellipse fitting at different steps
anim = @animate for j=1:1:100
    scatter(E[1, :, j], E[2, :, j], legend = false)
    angles = 0.0:0.01:2*pi
    B = zeros(2, length(angles))
    for i = 1:1:length(angles)
        B[:, i] = [cos(angles[i]) - blist[1, j+1], sin(angles[i]) - blist[2, j+1]]
    end
    ellipse  = Alist[1:2, 1:2, j+1] \ B
    plot!(ellipse[1, :], ellipse[2, :])
    title!("Ellipse fitting t=$(j)")
    xlabel!("X")
    ylabel!("̇X")
end
gif(anim, "other_scheme_more_uncer.gif", fps = 1)

#Ellipse MC comparison
anim = @animate for j=2:1:101
    scatter(traj[1, j, :], traj[2, j, :], legend = false)
    scatter!(XX[1, :, j], XX[2, :, j])
    #plot!(sol, vars=(1, 2))
    title!("Ellipse propagation vs MC step =$(j)")
    xlabel!("X")
    ylabel!("̇X")
end
gif(anim, "prop_vc_MC_other_sampling_scheme_more_uncer_no_traj.gif", fps = 1)
