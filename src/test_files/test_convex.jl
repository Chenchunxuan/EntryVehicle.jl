#Text convex.jl
using Convex
using LinearAlgebra
using SCS
using Plots
using Roots
using Distributions
using Mosek
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

D1 = Uniform(-5, 5)
D2 = Uniform(0, 10)
x1 = zeros(1, 4)
x2 = zeros(1, 4)
rand!(D1, x1)
rand!(D2, x2)
x = vcat(x1, x2)

#=
n, m = size(x);

A = Semidefinite(n)
b = Variable(n)
problem = maximize(logdet(A), [norm(A*x[:, i]+b, 2)<=1 for i = 1:1:m])

Convex.solve!(problem, SCSSolver())

problem.status
problem.optval

A = A.value
b = b.value =#


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
    obj = objective_value(model)
    A = JuMP.value.(A)
    b = JuMP.value.(b)
    return A, b, obj
end

A, b = points2ellipse_mosek(x)

angles = 0.0:0.01:2*pi
B = zeros(2, length(angles))
for i = 1:1:length(angles)
      B[:, i] = [cos(angles[i]) - b[1], sin(angles[i]) - b[2]]
end


ellipse  = A \ B

Plots.scatter(x[1,:], x[2,:])
Plots.plot!(ellipse[1, :], ellipse[2, :])

XX = points(A, b)
XXX = points2_chol(A, b)
Plots.scatter!(XX[1, :], XX[2, :])
Plots.scatter!(XXX[1, :], XXX[2, :])

function points(A, b)
      n = length(b)
      W = inv(A)
      M = -inv(A)*b
      X = zeros(2, 4)
      for i=1:1:n
            X[:, 2*i-1] = M- W[:, i]
            X[:, 2*i] = M +W[:, i]
      end
      return X
end

function points2_chol(A, b)
      n = length(b)
      W = inv(A)
      M = -inv(A)*b
      X = zeros(2, 4)
      AA = A*A
      C = cholesky(AA)
      L = C.L
      SV = svd(L)
      U = SV.U
      Σ = Diagonal(SV.S)
      for i=1:1:n
            X[:, 2*i-1] = M-(1/Σ[i, i])*U[:, i]
            X[:, 2*i] = M+(1/Σ[i, i])*U[:, i]
      end
      return X
end

######################
###DIFFERENT STUFF####
######################


M = -inv(A)*b
T = A'*A
F = eigen(T)
W = F.vectors
V = F.values
v1 = M+(1/sqrt(V[2]))*W[:, 2]
v2 = M+(1/sqrt(V[1]))*W[:, 1]
v3 = M-(1/sqrt(V[2]))*W[:, 2]
v4 = M-(1/sqrt(V[1]))*W[:, 1]

scatter!([v1[1], v2[1], v3[1], v4[1]], [v1[2], v2[2], v3[2], v4[2]])



Plots.scatter()

#b = [-0.339299; -0.0561543]
#A = [2.42823 -0.0557447; -0.0557448 2.96796]

b = b.value
A = A.value
@show(A)
@show(b)
angles = 0.0:0.05:2*pi
angles2 = 0.0:0.05:2*pi
B = zeros(3)
function job()
      B = zeros(3)
      for i = 1:1:length(angles)
            for j = 1:1:length(angles2)
                  B = hcat(B, [cos(angles[i])*sin(angles2[j]) - b[1]; sin(angles[i])*sin(angles2[j]) - b[2]; cos(angles2[j])-b[3]])
            end
      end
      return B
end
B = job()

ellipse  = A \ B

scatter3d(x[1,:], x[2,:], x[3,:])
plot3d!(ellipse[1, 2:end], ellipse[2, 2:end], ellipse[3, 2:end])
plot3d!(ellipse[1, 2:end], ellipse[2, 2:end])


M = -inv(A)*b
C = -inv(A[1:2, 1:2])*b[1:2]

scatter!(M[1, :], M[2, :], markersize = 20.0) #center of the ellipse fitted
scatter!(C[1, :], C[2, :])

T = A'*A
F = eigen(T)
W = F.vectors
V = F.values
v1 = M+(1/sqrt(V[2]))*W[:, 2]
v2 = M+(1/sqrt(V[1]))*W[:, 1]
v3 = M-(1/sqrt(V[2]))*W[:, 2]
v4 = M-(1/sqrt(V[1]))*W[:, 1]
scatter!([v1[1], v2[1], v3[1], v4[1]], [v1[2], v2[2], v3[2], v4[2]], markersize = 20.0)

#this enables to extract different points (not the same as the previous method actually)
#this second one is the one used by DIRTREL paper in fact.
T = inv(A'*A)
F = eigen(T)
V = F.vectors
val = F.values
R = V*Diagonal(sqrt.(val))*inv(V)
v1 = M+R[:, 2]
v2 = M+R[:, 1]
v3 = M-R[:, 2]
v4 = M-R[:, 1]
v5 = M+R[:, 3]
v6 = M-R[:, 3]

scatter!([v1[1], v2[1], v3[1], v4[1]], [v1[2], v2[2], v3[2], v4[2]])

#Plot in 3D case for further verification
using PyPlot
using3D()
pygui(true)

fig = figure()
ax = fig[:gca](projection="3d")

Plots.scatter(x[1,:], x[2,:], x[3,:], markersize = 20.0)
#surface(ellipse[1, 2:end], ellipse[2, 2:end], ellipse[3, 2:end])
Plots.plot!(ellipse[1, 2:end], ellipse[2, 2:end], ellipse[3, 2:end])
Plots.scatter!(M[1, :], M[2, :], M[3, :], markersize =20.0)
Plots.scatter!([v1[1], v2[1], v3[1], v4[1], v5[1], v6[1]], [v1[2], v2[2], v3[2], v4[2], v5[2], v6[2]], [v1[3], v2[3], v3[3], v4[3], v5[3], v6[3]], markersize=20.0)

#=
R = W*Diagonal(sqrt.(V))*inv(W)
VV = eigvals(R)
WW = eigvecs(R)=#

#scatter!([M[1]+W[1, 1];M[1]+W[1, 2]], [M[2]+W[2, 1];M[2]+W[2, 2]]) #THIS IS THE WAY TO DO IT

#f(λ) = norm(A*λ*W[:,1], 2)-1
#z = find_zeros(f, -100, 100)

#using equation's roots
#V1 = M + z[1]*W[:, 1]
#V2 = M + z[2]*W[:, 1]

#using eigenvalues
v1 = M+(1/sqrt(V[2]))*W[:, 2]
v2 = M+(1/sqrt(V[1]))*W[:, 1]
v3 = M-(1/sqrt(V[2]))*W[:, 2]
v4 = M-(1/sqrt(V[1]))*W[:, 1]

scatter!([v1[1], v2[1], v3[1], v4[1]], [v1[2], v2[2], v3[2], v4[2]])


#scatter!([V1[1], V2[1]], [V1[2], V2[2]])
#scatter!([M[1]+z[2]*W[1, 1], M[1]+z[1]*W[1, 1]], [M[2]+z[2]*W[2, 1], M[2]+z[1]*W[2, 1]])

#new test with another parameterization:

x = [1.55  2.0 1.0;
      2.25  2.35 3.0 ;
     2.2   2.2 5.0;
     2.25 2.1 3.0 ;
     2.0  2.3 2.0 ;
      2.4  2.2 1.0]';
n, m = size(x);

A = Semidefinite(n)
v = Variable(n)
problem = maximize(logdet(A), vcat([(x[:, i]-v)'*A*(x[:, i]-v)<=1 for i = 1:1:m], [A[1, 2]==A[2, 1]]))

solve!(problem, SCSSolver())

problem.status
problem.optval

#b = [-0.339299; -0.0561543]
#A = [2.42823 -0.0557447; -0.0557448 2.96796]

b = b.value
b = [0.0; 0.0]
A = A.value
angles = 0.0:0.01:2*pi
B = zeros(2, length(angles))
for i = 1:1:length(angles)
      B[:, i] = [cos(angles[i]) - b[1], sin(angles[i]) - b[2]]
end

ellipse  = A \ B

scatter(x[1,:], x[2,:])
plot!(ellipse[1, :], ellipse[2, :])

#new test

x = [1.55  2.0;
      2.25  2.35;
     2.2   2.2;
     2.25 2.1;
     2.0  2.3;
      2.4  2.2 ]';
n, m = size(x);

A = Semidefinite(n)
v = Variable(n)
problem = maximize(logdet(A), [norm(A*(x[:, i]-v))<=1 for i = 1:1:m])

Convex.solve!(problem, SCSSolver())

problem.status
problem.optval

#b = [-0.339299; -0.0561543]
#A = [2.42823 -0.0557447; -0.0557448 2.96796]

v = v.value
b = [0.0; 0.0]
A = A.value
angles = 0.0:0.01:2*pi
B = zeros(2, length(angles))
for i = 1:1:length(angles)
      B[:, i] = [cos(angles[i]) - b[1], sin(angles[i]) - b[2]]
end

ellipse  = A \ B

scatter(x[1,:], x[2,:])
plot!(ellipse[1, :], ellipse[2, :])

#test eigenvalues and eigenvectors
U = [2.0 1.0 3.0; 1.0 2.0 3.0; 3.0 3.0 20.0]
V = eigvals(U)
W = eigvecs(U)

F = eigen(U)
W = F.vectors
V = F.values

U = [2.0 1.0 0.0; 1.0 1.0 0.0; 0.0 0.0 1.5]
F = eigen(U)
W = F.vectors
V = F.values

U*W[:, 1] == V[1]*W[:, 1]
U*W[:, 1]
V[1]*W[:, 1]

U*W[:, 2]
V[2]*W[:, 2]

U*W[:, 3]
V[3]*W[:, 3]

#ENIEME test on ellipses in 3D
using LinearAlgebra

Q = Matrix(Diagonal([0.1^2; 0.1^2; 0.4^2])) #covariance matrix
x = [3.0;2.0;1.0] #center (nominal value)
A = sqrt(inv(Q)) #matrix substitution
b = -A*x #center subsitution

A = Matrix(cholesky(inv(Q)).U)

W = inv(A)

#A = A1[4:6, 4:6]
#b = b1[4:6]
angles = 0.0:0.05:2*pi
angles2 = 0.0:0.05:2*pi
B = zeros(3)
function job()
      B = zeros(3)
      for i = 1:1:length(angles)
            for j = 1:1:length(angles2)
                  B = hcat(B, [cos(angles[i])*sin(angles2[j]) - b[1]; sin(angles[i])*sin(angles2[j]) - b[2]; cos(angles2[j])-b[3]])
            end
      end
      return B
end
B = job()

ellipse  = A \ B
Plots.plot(ellipse[1, 2:end], ellipse[2, 2:end], ellipse[3, 2:end])

scatter3d!(W[1, :], W[2, :], W[3, :])
