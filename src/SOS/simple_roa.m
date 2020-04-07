% Test on simple system. ROA known

clc;clear;clear all; 

epsi = 1e-2;
d = 10;
sdpvar x1 x2 rho
x = [x1;x2];
f = [-x2; x1+((x1^2)-1)*x2]; %non-linear dynamics equation
A = [0.0 -1.0; 1.0 -1.0]; %linearization at point (0.0,0.0) stable equi point
S = lyap(A', eye(2));
V0 = x'*S*x;
V = V0;
imp = 10.0; %improvement from one outer iteration to the other
m = 0.0;

%% %while abs(imp) > 1e-1 %no need for abs because guaranteed to improve at each step rho
for i=1:2
    u = m+10.0; %Now binary search over rho to maximize rho
    l = m; %We know that one works (we want at least this next)
    while abs(u-l)>epsi
        t = (u+l)/2
        [s3,v3,Q3] = step_3(t,V,f,x,d);
        result = s3.problem
        if result == 0 || result == 4
            l = t;
        else
            u = t;
        end
    end
    L = v3{1}'*Q3{1}*v3{1};
    L = L/(sum(coefficients(L,x)));
    sdisplay(L)
    [s1,v1,Q1] = step_1(rho,L,f,x,d);
    s1
    V = v1{1}'*Q1{1}*v1{1};
    temp = value(rho)
    imp = temp - m
    m = temp;
    l
    u
end

%% Plot result simple system (3)

V1 = sdisplay(V);

L2=strrep(strrep(V1,'*','.*'),'^','.^');V3=cell2mat((L2));

[x1,x2]=meshgrid([-5:0.01:5],[-5:0.01:5]);
surf(x1,x2,eval(V3),'FaceColor','red','FaceAlpha',0.85,'EdgeColor','none','FaceLighting','phong');hold on;grid on;
hold on 
contour(x1,x2,eval(V3),m) %to see the level set
%xlim([-3.0 3.0]);
%ylim([-3.0, 3.0]);
camlight; lighting gouraud

%% functions


function [sol,v_sol,Q_sol] = step_1(rho,L,f,x,d) 
    [a,p] = polynomial(x,d);
    dVdt = jacobian(a,x)*f;
    D = -dVdt+L*(a-rho);
    F = [sos(a),sos(D),sum(p)==1.0, p(1)==0.0];
    ops = sdpsettings('solver','mosek', 'mosek.MSK_DPAR_ANA_SOL_INFEAS_TOL', 1.0e-10);%,'verbose',0);
    [sol,v_sol,Q_sol]=solvesos(F,-rho,ops,[p;rho]);
end

function [sol,v_sol,Q_sol] = step_2(rho,V,f,x,d) 
    [L,c] = polynomial(x,d);
    dVdt = jacobian(V,x)*f;
    D = -dVdt+L*(V-rho);
    F = [sos(L),sos(D)];
    ops = sdpsettings('solver','mosek'); %'verbose',0);
    [sol,v_sol,Q_sol]=solvesos(F,[],ops,c);
end

function [sol,v_sol,Q_sol] = step_3(t,V,f,x,d)
    [b,c] = polynomial(x,d);
    dVdt = jacobian(V,x)*f;
    D = -dVdt+b*(V-t);
    F = [sos(b),sos(D),sum(c)==1.0];
    ops = sdpsettings('solver','mosek','verbose',0);
    [sol,v_sol,Q_sol]=solvesos(F,[],ops,c);
end
