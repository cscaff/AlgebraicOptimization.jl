using AlgebraicDynamics.UWDDynam
using AlgebraicOptimization.OpenProblems
using AlgebraicOptimization.FlowGraphs
using Catlab
using NLsolve
using Optim
using ForwardDiff
using BlockDiagonals
using Test
using LinearAlgebra

# Make a flow graph from a catlab graph

#=g = wheel_graph(Graph, 6)

flow_costs = [x -> x^2 for e in 1:ne(g)]
flows = zeros(nv(g))
flows[1] = 10
flows[nv(g)] = -10
pm = FinFunction([1,nv(g)])

fg = FlowGraph(g, flow_costs, flows, pm)
A = node_incidence_matrix(fg)

p = to_problem(fg)

s = gradient_flow(p)

#flow_s = λ -> eval_dynamics(s, λ)

ds = euler_approx(s, 0.1)


function iterate(f, x0, num_iters)
    x = x0
    for i in 1:num_iters
        x = f(x)
    end
    return x
end

dual_sol = iterate(u -> eval_dynamics(ds, u), zeros(nv(g)), 100)
primal_sol = primal_solution(p, dual_sol)
#dual_sol = nlsolve(flow_s, zeros(nv(g)), xtol=0.01)

#primal_sol = primal_solution(p, dual_sol)
#primal_sol = iterate(x -> x - 0.001*ForwardDiff.gradient(x->objective(p)(x,dual_sol), x), zeros(ne(g)), 100000)

function uzawas(L::Function, init_x, init_λ, γ_init, γ_decay, iters)
    x_old = init_x
    x_new = x_old
    y_old = init_λ
    y_new = y_old
    γ = γ_init
    for i in 1:iters
        x_new = x_old - γ*ForwardDiff.gradient(x->L(x,y_old), x_old)
        y_new = y_old + γ*ForwardDiff.gradient(y->L(x_old,y), y_old)
        x_old = x_new
        y_old = y_new
        γ -= γ_decay
    end
    return x_new, y_new
end

function dual_ascent(L::Function, primal_dim, init_y, γ, iters)
    y = init_y
    x(y) = optimize(x->L(x,y), zeros(primal_dim), NewtonTrustRegion(), autodiff=:forward)
    for i in 1:iters
        x_star = x(y).minimizer
        y = y + γ*ForwardDiff.gradient(y->L(x_star,y), y)
    end
    return x(y).minimizer, y
end

function negative_dual_gradient(L::Function, primal_dim)
    return function g!(G, y)
        x(y) = optimize(x->L(x,y), zeros(primal_dim), NewtonTrustRegion(), autodiff=:forward)
        x_star = x(y).minimizer
        G .= -ForwardDiff.gradient(y->L(x_star,y), y)
    end
end
x(y) = optimize(x->objective(p)(x,y), zeros(ne(g)), NewtonTrustRegion(), autodiff=:forward).minimizer
q(y) = -objective(p)(x(y), y)
#ups, uds = uzawas(objective(p), zeros(ne(g)), zeros(nv(g)), .001, 0, 100000)
daps, dads = dual_ascent(objective(p), ne(g), zeros(nv(g)), 0.1, 100)
@time ods = optimize(q, #=negative_dual_gradient(objective(p), ne(g)),=# zeros(nv(g)), BFGS())
ops = x(ods.minimizer)=#

# Start testing stuff

g1 = wheel_graph(Graph, 20)
g2 = complete_graph(Graph, 10)
g3 = wheel_graph(Graph, 30)

K1 = [x -> x^2 for e in 1:ne(g1)]
K2 = [x -> x^2 for e in 1:ne(g2)]
K3 = [x -> x^2 for e in 1:ne(g3)]

b1 = zeros(nv(g1))
b1[1] = Float64(rand(1:10))
b1[end] = -b1[1]
b2 = zeros(nv(g2))
b2[1] = Float64(rand(1:10))
b2[end] = -b2[1]
b3 = zeros(nv(g3))
b3[1] = Float64(rand(1:10))
b3[end] = -b3[1]

pm1 = FinFunction([1,nv(g1)])
pm2 = FinFunction([1,nv(g2)])
pm3 = FinFunction([1,nv(g3)])

fg1 = FlowGraph(g1, K1, b1, pm1)
fg2 = FlowGraph(g2, K2, b2, pm2)
fg3 = FlowGraph(g3, K3, b3, pm3)

p1 = to_problem(fg1)
p2 = to_problem(fg2)
p3 = to_problem(fg3)

s1 = gradient_flow(p1)
s2 = gradient_flow(p2)
s3 = gradient_flow(p3)

ds1 = euler_approx(s1, 0.01)
ds2 = euler_approx(s2, 0.01)
ds3 = euler_approx(s3, 0.01)

d = @relation (x,y,z) begin
    fg1(x,z)
    fg2(y,z)
    fg3(x,y)
end

composite_problem = oapply(d, [p1,p2,p3])
total_ds = euler_approx(gradient_flow(composite_problem), 0.01)

composite_ds = oapply(d, [ds1,ds2,ds3])

total_V = nvars(composite_problem)

dual_sol1 = iterate(u -> eval_dynamics(total_ds, u), zeros(total_V), 1000)

println("Time for dual ascent on total problem:")
@time iterate(u -> eval_dynamics(total_ds, u), zeros(total_V), 1000)

dual_sol2 = iterate(u -> eval_dynamics(composite_ds, u), zeros(total_V), 1000)

println("Time for dual decomposition on UWD structure:")
@time iterate(u -> eval_dynamics(composite_ds, u), zeros(total_V), 1000)

@test dual_sol1 ≈ dual_sol2

ps = [p1,p2,p3]

M = coproduct((FinSet∘nvars).(ps))
incs(b::Int) = legs(M)[b]
Mpo = induced_vars(d, ps, incs)

A1 = node_incidence_matrix(fg1)
A2 = node_incidence_matrix(fg2)
A3 = node_incidence_matrix(fg3)

P = induced_matrix(legs(Mpo)[1])
A = P'*BlockDiagonal([A1,A2,A3])
b = P'*vcat(b1,b2,b3)
primal_sol = primal_solution(composite_problem, dual_sol2)

@test norm(A*primal_sol - b) < 0.5

# Maximally decomposed version
N = n_primal_vars(composite_problem)
L(i) = (x,y) -> x[1]^2 + y'*(A[:,i]*x[1] - 1/N*b)
L(x,y) = sum([L(i)(x[i],y) for i in 1:N])

function dual_decomp(y0, ss, iters)
    y = y0
    x = zeros(N)
    for i in 1:iters
        for i in 1:N
            x[i] = (optimize(x -> L(i)(x,y), [0.0], LBFGS(), autodiff=:forward).minimizer)[1]
        end
        y = y + ss*ForwardDiff.gradient(y->L(x,y),y)
    end
    return y
end

dd_sol = dual_decomp(zeros(total_V), 0.01, 1000)

println("Time for complete dual decomposition:")
@time dual_decomp(zeros(total_V), 0.01, 1000);

println("Done.")
