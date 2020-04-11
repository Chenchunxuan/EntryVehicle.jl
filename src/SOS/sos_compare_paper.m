% Compare results with literature 
% PAPER = Application of sum-of-squares method in 
% estimation of region of attraction for nonlinear polynomial systems 
% AUTHOR = F. Meng

%% They start with V fixed first (using LQR estimate)
clc;clear;clear all; 

epsi = 1e-3;
d = 4;
sdpvar x1 x2 rho
x = [x1;x2];
f = [-x2; x1+((x1^2)-1)*x2]; %non-linear dynamics equation
A = [0.0 -1.0; 1.0 -1.0]; %linearization at point (0.0,0.0) stable equi point
Q1 = eye(2);
Q2 = [1.0 0.0; 0.0 2.0];
Q3 = [5.0 0.0; 0.0 2.0];
S = lyap(A', Q1);
V0 = x'*S*x;
V = V0;
m = 0.0;

%% 
%I believe they run the loop once only and see what they get for different
%initial value for V (related to changing the value of Q cost matrix in the
%Lyapunov equation)

for i=1:1
    u = m+10.0; %Now binary search over rho to maximize rho
    l = m; %We know that one works (we want at least this next)
    while abs(u-l)>epsi
        t = (u+l)/2
        [s3,v3,Q3] = step_2(t,V,f,x,d);
        result = s3.problem
        if result == 0
            l = t;
        else
            u = t;
        end
    end
    L = v3{1}'*Q3{1}*v3{1};
    L = clean(L/(sum(coefficients(L,x))), 1e-5);
    sdisplay(L)
    sdisplay(V)
    m = t;
end

%% Plot the different ROA estimates (level sets of Lyap functions)

V1 = sdisplay(V);
L2=strrep(strrep(V1,'*','.*'),'^','.^');V3=cell2mat((L2));
[x1,x2]=meshgrid([-3:0.01:3],[-3:0.01:3]);
hold on 
%figure()
contour(x1,x2,eval(V3),[1 1], 'Color', 'r') %to see the level set
camlight; lighting gouraud

%% Try to optimize further using a shape factor polynomial h(x)

clc;clear;clear all; 

epsi = 1e-3;
d = 6;
d1 = 4;
d2 = 2;
sdpvar x1 x2 beta
x = [x1;x2];
f = [-x2; x1+((x1^2)-1)*x2]; %non-linear dynamics equation
A = [0.0 -1.0; 1.0 -1.0]; %linearization at point (0.0,0.0) stable equi point
Q1 = eye(2);
Q2 = [1.0 0.0; 0.0 2.0];
Q3 = [5.0 0.0; 0.0 2.0];
S = lyap(A', Q1);
%V0 = x'*S*x;
%V = V0;
V = (0.65217*x1^2-0.43478*x1*x2+0.43478*x2^2);
m = 0.0;
h = [x1 x2]*[x1; x2]; %shape factor
%h = 2*x1^2-x1*x2+1.5*x2^2;
l1 = 1e-6*h;
l2 = 1e-6*h;

%%

for i=1:8
    u = m+10.0; %Now binary search over rho to maximize rho
    l = m-1.0; %We know that one works (we want at least this next)
    while abs(u-l)>1e-3
        t = (u+l)/2
        [s,v,Q] = step_4(t,V,f,h,l1,l2,x,d1,d2);
        result = s.problem
        if result == 0
            l = t;
            s1 = v{1}'*Q{1}*v{1};
            s2 = v{2}'*Q{2}*v{2};
        else
            u = t;
        end
    end
    %s1 = clean(s1/(sum(coefficients(s1,x))), 1e-9);
    %s2 = clean(s2/(sum(coefficients(s2,x))), 1e-9);
    m = t;
    u = m+10.0; %Now binary search over rho to maximize rho
    l = m-0.1; %We know that one works (we want at least this next)
    [ss,vv,QQ] = step_5(beta,s1,s2,f,h,l1,l2,x,d);
    ss.problem
    m = value(beta)
    %{
while abs(u-l)>1e-3
        t = (u+l)/2
        [ss,vv,QQ] = step_5(t,s1,s2,f,h,l1,l2,x,d);
        res = ss.problem
        if res ==4
            t
            sdisplay(s1)
            sdisplay(s2)
            sdisplay(h)
            sdisplay(l1)
            sdisplay(l2)
            break
        end
        if res == 0 
            l = t;
        else
            u = t;
        end
end
    %}
    V = vv{1}'*QQ{1}*vv{1}+l1;
    sdisplay(V)
end



%% Optimization FuV1 = sdisplay(V);

function [sol,v_sol,Q_sol] = step_1(rho,L,f,x,d)
    [a,p] = polynomial(x,d);
    dVdt = jacobian(a,x)*f;
    D = -dVdt+L*(a-rho);
    F = [sos(a),sos(D),sum(p)==1.0, p(1)==0.0];
    ops = sdpsettings('solver','mosek', 'mosek.MSK_DPAR_ANA_SOL_INFEAS_TOL', 1.0e-10,... 
    'verbose', 0.0);
    [sol,v_sol,Q_sol]=solvesos(F,-rho,ops,[p;rho]);
end

function [sol,v_sol,Q_sol] = step_2(rho,V,f,x,d) 
    [L,c] = polynomial(x,d);
    dVdt = jacobian(V,x)*f;
    D = -dVdt+L*(V-rho);
    F = [sos(L),sos(D)];
    ops = sdpsettings('solver','mosek','verbose',0);
    [sol,v_sol,Q_sol]=solvesos(F,[],ops,c);
end

function [sol,v_sol,Q_sol] = step_3(t,V,g,f,x,d)
    [b,c] = polynomial(x,d);
    [s1,c1] = polynomial(x,d); [s2,c2] = polynomial(x,d); [s3,c3] = polynomial(x,d); [s4,c4] = polynomial(x,d);
    [r1,d1] = polynomial(x,d); [r2,d2] = polynomial(x,d); [r3,d3] = polynomial(x,d); [r4,d4] = polynomial(x,d);
    dVdt = jacobian(V,x)*f;
    D = -dVdt+b*(V-t);
    F = [sos(b-[s1 s2 s3 s4]*g),sos(D-[r1 r2 r3 r4]*g),sos(s1),sos(s2),sos(s3),sos(s4),sos(r1),sos(r2),sos(r3),sos(r4)];
    ops = sdpsettings('solver','mosek','verbose',1);
    [sol,v_sol,Q_sol]=solvesos(F,[],ops,[c,c1,c2,c3,c4,d1,d2,d3,d4]);
end

%Additional functions used for the "shape factor" method

function [sol,v_sol,Q_sol] = step_4(beta,V,f,h,l1,l2,x,d1,d2) 
    [s1,c1] = polynomial(x,d1);
    [s2,c2] = polynomial(x,d2);
    dVdt = jacobian(V,x)*f;
    D = -(dVdt+l2)+s1*(V-1.0);
    E = (h-beta)*s2 + (1.0-V);
    F = [sos(s1),sos(s2),sos(D),sos(E)];
    ops = sdpsettings('solver','mosek','verbose',0);
    [sol,v_sol,Q_sol]=solvesos(F,[],ops,[c1;c2]);
end

function [sol,v_sol,Q_sol] = step_5(beta,s1,s2,f,h,l1,l2,x,d)
    [V,p] = polynomial(x,d);
    dVdt = jacobian(V,x)*f;
    D = -(l2+dVdt)+s1*(V-1);
    E = (h-beta)*s2+ (1-V);
    F = [sos(V-l1),sos(D),sos(E)];
    ops = sdpsettings('solver','mosek','verbose', 0.0);
    [sol,v_sol,Q_sol]=solvesos(F,-beta,ops,[beta;p]);
end