### A Pluto.jl notebook ###
# v0.19.22

using Markdown
using InteractiveUtils

# ╔═╡ 07e68196-1f07-41f2-9849-685d1748a3d7
begin
	using LinearAlgebra
	using Plots
	using LaTeXStrings
	using Parameters
	using Statistics
	using QuantEcon
	using Roots: fzero
	theme(:default)
end

# ╔═╡ 305d8ffd-8e96-4463-b4d3-f4a5a770d3a2
md"""
# Application: Uninsured Idiosyncratic Risk and Aggregate Saving, Aiyagari (QJE 1994)

[This paper](https://academic.oup.com/qje/article-abstract/109/3/659/1838287) is a workhorse macro model of incomplete markets: *consumers cannot perfectly insure against income fluctations*. 
"""

# ╔═╡ c1388e32-4a26-11ec-3def-9d7f551edcca
md"""

In the model, there is one riskless asset which people can use to smooth consumption fluctuations (by saving), but there is a borrowing constraint. The GE nature of the model stems from the assumption that the aggregate capital stock $K$ needs to be built out of the savings of individual households. 

## Firms

Firm output is given by

$$Y_t = A K_t^\alpha N^{1-\alpha}$$

Notice that we keep productivity $A > 0$ and labor supply $N>0$ constant here. This form of production function implies:

1. Firms produce output by combining capital and labor.
2. The production function has constant returns to scale: it does not make a difference whether we have
    - 3 firms that each use $K$ capital and $N$ workers: they output $3Y$.
    - a single firm that uses $3K$ capital and $3N$ workers. it outputs
$$A (3K)_t^\alpha (3N)^{1-\alpha} = 3AK_t^\alpha N^{1-\alpha} = 3Y$$
3. So we just look at *a single representative firm*
4. (The firm *still* is a price taker as if there were *many competitors around*!)

The the firm's problem is as usual to maximize profits. There is just one final good, so no relative price to consider, and we want that the firm

$$\max_{K_t,N} A K_t^\alpha N^{1-\alpha} - (r + \delta)K_t - wN$$

where $\delta$ is the depreciation rate of capital and where $(r,w)$ are the rental prices of capital and labor, respectively. $w$ is usually called *wage* 😉. First order conditions on this last expression yield

$$\begin{align}
r_t &= A\alpha \left(\frac{N}{K_t}\right)^{1-\alpha} - \delta \quad \quad\quad \quad (1)\\
w_t &= A(1-\alpha) \left(\frac{N}{K_t}\right)^{-\alpha} \quad \quad\quad \quad (2)\\
\end{align}$$

Now express the first one in terms of $\frac{N}{K_t}$ and plug into the second one to find

$$w(r_t) = A(1-\alpha) \left(\frac{A \alpha}{r + \delta}\right)^{\frac{\alpha}{1-\alpha}}  \quad \quad\quad \quad (3)$$
"""

# ╔═╡ bfbc42d2-c7bb-4a13-8c5d-95512940ceee
md"""
## Consumers

They solve a savings problem:

$$\max_{\{c_t\}_{t=0}^\infty} \sum_{t=0}^\infty \beta^t u(c_t)$$

subject to

$$a_{t+1} + c_t = w_t z_t + (1+r_t)a_t, c_t\geq 0 , a_t \geq -B$$

Here:
* There is an exogenously evolving productivity shock $z_t$ with transition matrix $\mathbf{P}$
* Prices $w_t,r_t$ are as above

## Equilibrium

* Aggregates and prices are constant over time: That concerns in particular $K$ ($N$ assumed constant).
* firms optimize profits and are price takers
* households maximize utility, also as price takers
* household savings represents *capital supply*, and in equilibrium it has to match *capital demand* of firms.

"""

# ╔═╡ 20ef10f8-8a61-492e-9496-3bdd10aaadef
md"""
# `QuantEcon.jl` implementation: the `DP` type

The [`QuantEcon`](https://julia.quantecon.org/dynamic_programming/discrete_dp.html) website introduces the `DP` type (discrete dynamic programming). We will quickly introduce this object and use it to solve the Aiyagari model with it.

The API expects us to supply at a minimum 3 objects: 

1. A *reward array* `R` s.t. `R[index of state,index of action] = reward`. This will be *utility* for most of our applications.
1. A *transition array* `Q` s.t. `Q[ix state(t),ix action,ix state(t+1)] = prob`, i.e. the probability with which we end up in a certain state tomorrow, dependent on today's state and the action we choose.
1. A discount factor β.

Let us start by loading the required packages and by defining a named tuple for an *Aiyagari* household with the `Parameters.jl` package. This package exports the `@with_kw` macro, allowing us to set default values on named tuples as follows:

"""

# ╔═╡ 8db93197-27b2-4420-9f22-83b1975c4b2a
md"""
Next, let's create a `Household` data type represented by a `NamedTuple` on which we can set elements with a keyword constructor from the `Parameters.jl` package:
"""

# ╔═╡ b35dd772-18d8-4184-8ee1-b9d71ed02d40
theme(:default)

# ╔═╡ 1a1ffd28-2f8a-415c-b188-7a51c18733b7
md"""
## Setting up the State Space

* Organising the data layout of a model is an important task and you should dedicate enough time to designing it.
* It [can matter for performance](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-column-major) how you access memory in arrays.
* The present consumer model has two state variables: $a$ and $z$. 
* So, we recursively write the above problem as

$$V(a,z) = \max_{a'} u((1+r)a + wz - a') + \beta \mathbb{E}_{z'|z}\left(V(a',z')\right)$$

* In the `DP` implementation, both state and choice space (and $z$) will be discretized, hence calling $\mathbf{P}$ the transition matrix of $z$, we have

$$V(a_i,z_j) = \max_{a_k} u((1+r)a_i + wz_j - a_k) + \beta \sum_{m=1}^M \mathbf{P}(z_m|z_j) V(a_k,z_m).$$ 
  

* The `DP` API wants us to provide a single index $i$ which runs down the rows of a matrix with `a_size * z_size` rows and `a_size` columns. 
* We need on object that maps $i$ into a value of both $(a,z)$.
* Here it is:

"""

# ╔═╡ c9cc0192-6965-4a8b-b8ea-5fe54a6860a9
md"""
This matrix has for each state index (each row) the values of each state variable. Of course, if we had 3 instead of 2 state variables, here we would have 3 columns. This was obtained with the very useful `gridmake` function from the `QuantEcon.jl` library:
"""

# ╔═╡ dac90a6c-190b-4d32-82ff-40e4d55cada0
gridmake([1,2],[11,12,13])

# ╔═╡ fa6baa0b-f496-4665-a7c8-3e4230f1ea6f
md"""
We also store a similar object `s_i_vals` (state *index* values), that will hold the index of each state variable *in its own grid*, as a function of $i$: 
"""

# ╔═╡ e5f8d659-4987-4f71-8d4b-fc6d07304f08
md"""

Now we can take a stab at setting up the required objects for this toolbox:

## Setting up `Q` and `R`

The key input from the user is going to be set up both arrays `Q` and `R`. Again, indexing with $i$ states and with $j$ actions, the contents of both arrays are

$$R[i,j] = \begin{cases}u( w z(i) + (1 + r)a(i) - a_j) & \text{if }w z(i) + (1 + r)a(i) - a_j >0 \\
-\infty & \text{else.}\end{cases}$$

So here, $i$ runs over both state variables, and I have written $a(i),z(i)$ as our way of computing the corresponding values from it. $a_j$, on the other hand, is just the $j$-th index in array $a$. 

Here is $Q$:

$$Q[i,j,i_+] = \mathbf{P}(i,i_+)$$

where $\mathbf{P}(i,i_+)$ is row $i$, column $i_+$ from the transition matrix describing the process of $z$ - $j$ is the index of the asset choice.
"""

# ╔═╡ cc388378-4ea9-453f-b079-30ecbf2e79a8
# R will be an (a_size * z_size, a_size) array.
# that is, a_size * z_size are all possible states, and
# a_size are all possible choices. Notice that we handle only *one* choice here.
# i.e. one row for each combination of a and z values
# and one column for each possible a choice.
# `a_vals` is (a_size,1)
# `s_vals` is (a_size * z_size,2): col 1 is a, col 2 is z
function setup_R!(R, a_vals, s_vals, r, w, u)
	# looping over columns
	# remember that first index varies fastest, so filling column-wise is performant
    for new_a_i in 1:size(R, 2)  # asset choice indices
        a_new = a_vals[new_a_i]  # asset choice values
		# looping over rows
        for s_i in 1:size(R, 1)
            a = s_vals[s_i, 1]  # tease out current state of a
            z = s_vals[s_i, 2]  # current state of z
            c = w * z + (1 + r) * a - a_new  # compute consumption
            if c > 0
                R[s_i, new_a_i] = u(c)
			end # we dont put an `else` because we filled R with -Inf
        end
    end
    return R
end

# ╔═╡ 2559490c-66e6-42a5-b4bd-285fe5f417c7
# Q will be an (z_size * a_size, a_size, z_size * a_size) array.
# At each state (dimension 1)
# given each choice (dim 2)
# what's the probability that you end up in tomorrow's state (a',z') (dim 3)
function setup_Q!(Q, s_i_vals, z_chain)
    for next_s_i in 1:size(Q, 3)  # loop over tomorrow's state indices
        for a_i in 1:size(Q, 2)   # loop over current choice indices
            for s_i in 1:size(Q, 1)  # loop over current state indices
                z_i = s_i_vals[s_i, 2]  # get current index (!) of z
                next_z_i = s_i_vals[next_s_i, 2]  # get index of next z
                next_a_i = s_i_vals[next_s_i, 1]  # get index of next a
                if next_a_i == a_i  # only up in state a' if we also chose a'
                    Q[s_i, a_i, next_s_i] = z_chain.p[z_i, next_z_i]
                end
            end
        end
    end
    return Q
end


# ╔═╡ 4b805387-b7a3-432a-883c-7c4230842451
Household = @with_kw (r = 0.01,
                      w = 1.0,
                      σ = 1.0,
                      β = 0.96,
                      z_chain = MarkovChain([0.9 0.1; 0.1 0.9], [0.1; 1.0]),
                      a_min = 1e-10,
                      a_max = 5.0,
                      a_size = 200,
                      a_vals = range(a_min, a_max, length = a_size),
                      z_size = length(z_chain.state_values),
                      n = a_size * z_size,
                      s_vals = gridmake(a_vals, z_chain.state_values),
                      s_i_vals = gridmake(1:a_size, 1:z_size),
                      u = σ == 1 ? x -> log(x) : x -> (x^(1 - σ) - 1) / (1 - σ),
					  # will define those two functions in detail below!
                      R = setup_R!(fill(-Inf, n, a_size), a_vals, s_vals, r, w, u),
                      # -Inf is the utility of dying (0 consumption)
                      Q = setup_Q!(zeros(n, a_size, n), s_i_vals, z_chain))

# ╔═╡ 6e6ccee2-2006-4794-a1b8-16ec70513923
h = Household();

# ╔═╡ b40a922a-4aae-40ef-aa13-51caec059323
h.s_vals  

# ╔═╡ 02d599a4-20bd-4d88-b0c1-86896703b09c
h.s_i_vals

# ╔═╡ 5eb6f22e-1080-48b9-b271-b64a05a4feb9
md"""
## Run A Household in Isolation or...*Partial Equilibrium*

So let's create one of those households, tell them what the interest and their wage are, and see how they optimally choose to behave:
"""

# ╔═╡ 25f75bf9-a55a-459d-8ecb-3b07c7dda94c
begin
	# Create an instance of Household
	# we SET the interest and wage here!
	am = Household(a_max = 20.0, r = 0.03, w = 0.956)

	# Use the instance to build a discrete dynamic program
	am_ddp = DiscreteDP(am.R, am.Q, am.β)

	# Solve using policy function iteration
	results = solve(am_ddp, PFI)	
end


# ╔═╡ 888c8f09-2a23-4b84-9c3e-f9b04ae7b2de
md"""
## 🎉 🚨 🤯

Isn't this amazing? *Everybody* can do dynamic programming thanks to `QuantEcon.jl`! 🙏🏻

Alright, let's look into the results object:
"""

# ╔═╡ 0f70d187-a378-46af-8bbe-b9a61b087e41
fieldnames(typeof(results))

# ╔═╡ 49b24328-c000-49bd-be92-418a993f7e8f
md"""
* Now we want to look at those things. Keep in mind that $i$ has all states in a row, so we need to reshape those arrays first.
"""

# ╔═╡ b3f376ae-a00a-493c-9c6a-b4816300ba4f
let
	# make an `a` by `z` array of optimal values
	vstar = reshape(results.v,am.a_size,am.z_size)
	plot(am.a_vals,vstar, legend = :bottomright, label = ["low z" "high z"],
	     xlab = "a",ylab = "V")
end

# ╔═╡ 5d8c9e42-d110-49ea-b6cc-de965f21a3a7
md"""
Similarly for the optimal policy, we need to convert the optimal *indices* in `results` into values of `a`, given `z`:
"""

# ╔═╡ 1a929222-a197-4585-abb2-b4d362b323ce
function plota(am)
	# Simplify names
	@unpack z_size, a_size, n, a_vals = am
	z_vals = am.z_chain.state_values
	a_star = reshape([a_vals[results.sigma[s_i]] for s_i in 1:n], a_size, z_size)
	labels = ["z = $(z_vals[1])" "z = $(z_vals[2])"]
	plot(a_vals, a_star, label = labels, lw = 2, alpha = 0.6, leg = :bottomright, title = L"\sigma(a,z) \mapsto a'")
	plot!(a_vals, a_vals, label = "", color = :black, linestyle = :dash)
	plot!(xlabel = L"a", ylabel = L"a'")
end

# ╔═╡ 92a82ecc-1421-4ca2-9698-96449c1b03c6
plota(am)

# ╔═╡ 3883bd18-c2a3-43d0-977e-d966db842257
md"""
## Stationary Distribution $\mu$

We have an optimal policy $\sigma(a,z)$, and we have a law of motion for the exogenous state $z$. How will this system play out if we let this agent behave optimally for a long long time?

As you can read up [here](https://julia.quantecon.org/tools_and_techniques/finite_markov.html), if the transition matrix $\mathbf{P}$ is well-defined, it admits a unique stationary distribution $\mu$ of agents over the state space.

First, we need to form a composition of the exogenous law of motion $\mathbf{P}$ and the model-implied decision rules $\sigma$. Let's write it as

$$\mathbb{P}_\sigma(a',z'|a,z) = \sigma(a,z) \circ \mathbf{P}$$

i.e. we *compose* functions $\sigma$ and $\mathbf{P}$. In practice it's all about reshaping and what shape your state space is in, so this notation keeps it at a general level.

In our setup, the distribution function $\mu(a,z)$ will tells us the probability density of agents at state $(a,z)$ *in the long run*, or in other words, *in the steady state* of this model. 

Now, if $\mu$ is a *stationary* distribution, it satisfies

$$\mu^* = \mu^*\mathbb{P}_\sigma$$

in other words, post-multiplying distribution $\mu^*$ with the *Model-times-Shocks Transition Matrix* $\mathbb{P}_\sigma$, yields the same distribution $\mu^*$ over the state space.

So, a first important question you should ask: what does this $\mathbb{P}_\sigma$ thing look like? It encodes what happens to agent in this stochastic environment under optimal behaviour. That is, we know that $\sigma(a,z) \mapsto a'$, but we don't know what combination $(a',z')$ we will end up in.

Here is what it looks like as a matrix:
"""

# ╔═╡ 6fc89260-4d01-4103-8d20-97eef0cf1d55
results.mc.p

# ╔═╡ 76b08cb1-d121-471e-a268-59e79933ce40
md"""
### Understanding Matrix $\mathbb{P}_\sigma(a',z'|a,z) = \sigma(a,z) \circ \mathbf{P}$

Here is a plot of the transition matrix that combines state with optimal actions. I suggest you read the plot row-wise, i.e. the row labeled `400` is the on assiociated to state $i=400$, i.e. highest $z$ and highest $a$, and you can now go across columns to see in which future states $(a',z')$ we are likely to end up in from here. 

* Black means *probability zero*, hence there is no way that you end up in state $(a_1,z_1)$. 
* There is a colored pixel (violet colour) representing a probability of 0.1 somewhere in the middle of the first row - so with prob 0.1 your choice $\sigma(a,z) \mapsto a'$ will take you to this very pixel. It's the state $(a',z_1)$, i.e. low income shock. 
* At the far end, the yellow point, is reached with probability 0.9, hence, it's the point $(a',z_1)$.
"""

# ╔═╡ 1ac0515a-de55-4b9a-9323-ea5e19f4621b
heatmap(results.mc.p, color = cgrad(:thermal,[0.1, 0.9],categorical = true), xlab = L"(a',z')", ylab = L"(a,z)", title = L"\mathbb{P}_\sigma(a',z'|a,z)")

# ╔═╡ ef4cfd16-4a02-4bc6-b65b-b7abf656bf59
md"""

### Obtaining $\mu$

A very useful method in this context is the `stationary_distributions` function, which will return the dynamics of the state variable if our agent follows the optimal policy (i.e. follows `results.sigma`). This distribution was obtained by starting from an arbitrary distribution over the state space and iterating on $\mu$ until convergence. Basically, the algorithm will iterate on

$$\mu = \mu\mathbb{P}_\sigma$$

starting with $\mu_0$ until left and right hand sides don't change any longer.
"""

# ╔═╡ c3e404c0-dd90-44a7-aaaa-4c726dd49a77
mm = reshape(stationary_distributions(results.mc)[1], am.a_size,am.z_size);

# ╔═╡ 9a82365e-d6ac-4e79-a23d-6792d00c9d94
bar(mm, bar_width = 2, alpha = [0.9 0.4],xticks = (1:15:am.a_size, round.(am.a_vals[1:15:am.a_size],digits = 0)),xlab = "Assets", title = "Stationary distribution of assets given z", labels = ["z low" "z high"],ylab = "Probability")

# ╔═╡ 43d1b826-9f01-4dc4-99f4-af53b49b1b6c
md"""
same object but as seen *from above*
"""

# ╔═╡ 214c2f3b-cefc-4ffc-8158-bdf295b719f4
heatmap(mm', yticks = ([1,2],["zlow", "zhigh"]), xlab = "assets", color = :viridis,colorbar_title = "\n Probability",right_margin = 0.5Plots.cm, title = "Stationary Distribution")

# ╔═╡ 7c5332a7-814e-43fd-bcd1-372ff0406a38
function plotc(am)
	# get consumption policy
	@unpack z_size, a_size, n, a_vals = am
	z_vals = am.z_chain.state_values
	c_star = reshape([am.s_vals[s_i,1]*(1+am.r) + am.w * am.s_vals[s_i,2] -  a_vals[results.sigma[s_i]] for s_i in 1:n], a_size, z_size)
	labels = ["z = $(z_vals[1])" "z = $(z_vals[2])"]
	plot(a_vals, c_star, label = labels, lw = 2, alpha = 0.6, leg = :topleft, title = "Consumption Function")
	plot!(a_vals, a_vals, label = "", color = :black, linestyle = :dash)
	plot!(xlabel = "a", ylabel = "c")
end

# ╔═╡ 137f1aac-0121-45af-aa73-bc48dfd5bd6d
plotc(am)

# ╔═╡ cbf78d45-604b-4447-93bd-dc7bd3a2a18a
md"""
## Question: change slope of that?

* How could we make them save less?
"""

# ╔═╡ a8b1395d-4c19-4b8e-abf4-95ca7f37b650
md"""
# Now GE! Firms demand $K$!

Let's put it together with firms now. The key here is that aggregate capital is going to be assembled from the sum of savings of all households. Households *supply* capital, firms *demand* it. The price of capital is the rental rate $r$, which will adjust in order to make people save more or less and in order to make firms rent more or less of it. 

1. We have not made the dependence of behaviour on $r$ explicit so far.
2. We have kept it *out of our state space*. Well, actually it's part of the agent's environment, so part of the state.
3. Not to have to reimplement everything, let's just *index* the policy function $\sigma$ by the *prevailing interest rate* $r$ in the market, like so: 

$$\sigma_r(a,z) \mapsto a'$$
"""


# ╔═╡ 62a52d7a-842a-47c3-8565-e02e89b49516
md"""


Here is the key equation of how $K$ is built:

$$K_r = \int \sigma_r(a,z) d\mu \quad \quad \quad (4)$$

You can see that for different values of $r$, people will save more or less, and the capital stock will depend on $r$. This is a typical *fixed point problem* - at which number $r$ will this equation stabilize? Here is an algorithm to find out:

## Algorithm 1

0. At iteration $j$:
1. Pick a value $K^{(j)}$
2. Obtain prices $r^{(j)},w^{(j)}$ from equations $(1)$ and $(3)$.
3. Solve consumer problem and obtain $\sigma_r(a,z)$
3. Get stationary distribution $\mu^{(j)}$.
4. compute aggregate capital as $$K^{(j+1)} = \int \sigma_r(a,s) d\mu^{(j)}$$
5. Stop if $K^{(j)} = K^{(j+1)}$, else repeat.

## Visual 1

* Let's first try with a plot.
* We want to trace out capital supply and demand as a function of it's price, the interest rate. So the axis are $K$ and $r$.

"""

# ╔═╡ 116834f6-907f-4cfc-be0f-84784d0e3c7a
begin
	
	# equation (3)
	function r_to_w(r,fp)
		@unpack A, α, δ = fp
	    return A * (1 - α) * (A * α / (r + δ)) ^ (α / (1 - α))
	end

	# equation (1)
	function rd(K,fp)
		@unpack A, α, δ, N = fp
	    return A * α * (N / K) ^ (1 - α) - δ
	end
	
	
end

# ╔═╡ c7cbcc04-836c-483b-9523-1d84489b12e0
# capital stock implied by consumer behaviour when interest is r
function next_K_stock(am, r, fp )
	# derive wage	
	w = r_to_w(r,fp)
	@unpack a_vals, s_vals, u = am

	# rebuild R! cash on hand depends on both r and w of course!
	setup_R!(am.R, a_vals, s_vals, r, w, u)

	aiyagari_ddp = DiscreteDP(am.R, am.Q, am.β)

	# Compute the optimal policy
	results = solve(aiyagari_ddp, PFI)

	# Compute the stationary distribution
	stationary_probs = stationary_distributions(results.mc)[1]

	# Return equation (4): Average steady state capital
	return dot(am.s_vals[:, 1], stationary_probs)  # s_vals[:, 1] are asset values
	end

# ╔═╡ 2ae833d2-52de-4701-a619-8a33cf1df820
function alleqs(;A = 1,N = 1, α = 0.33, β = 0.96, δ = 0.05)

	# create a firm parameter
	fp = @with_kw (A = A, N = N, α = α, δ = δ)

 	# Create an instance of Household
	am = Household(β = β, a_max = 20.0)

	# Create a grid of r values at which to compute demand and supply of capital
	r_vals = range(0.005, 0.04, length = 20)

	# Compute supply of capital
	k_vals = next_K_stock.(Ref(am), r_vals, fp )  # notice the broadcast!

	demand = rd.(k_vals,fp)
	
	(k_vals,r_vals,demand)
end

# ╔═╡ 5ca1933b-6ee7-4c6c-b8b4-53265074fda3
all_r_eq = alleqs()

# ╔═╡ 60717847-047c-4e83-85d1-ee9c66aa1e0c
function eqmplot(k_vals,r_vals,demand)
	labels =  ["demand for capital" "supply of capital"]
	plot(k_vals, [demand r_vals], label = labels, lw = 2, alpha = 0.6)
	plot!(xlabel = "capital", ylabel = "interest rate", xlim = (2, 14), ylim = (0.0, 0.1))
end

# ╔═╡ b77599a0-c289-41bf-971e-22aeed4dd4e8
visualeq = eqmplot(all_r_eq...)

# ╔═╡ 4a0792a3-a6f6-4e21-8fae-80247a7984cc
md"""
Cool! 😎 Now let's find the equilibrium $r$ numerically. Let's just define the *excess supply function* as the red minus the blue curve in this picture. A root solver will find the point where excess supply is zero!

Let's reformulate equation (1) to get $K$ from $r$:

$$K_t = N \left(\frac{A\alpha}{r_t + \delta}\right)^{1/(1-\alpha)}$$
"""

# ╔═╡ a8115315-953c-44f9-87d1-f288e7ccf8ee
# capital demand
function Kd(r,fp)
	@unpack A, α, δ, N = fp
	return N * ((A * α) / (r + δ))^(1/(1-α))
end

# ╔═╡ c0386481-4e1e-4107-b6ac-48cecab668bf
md"""
... and we are good to go! 
"""

# ╔═╡ 805799b6-1b7e-464a-ab10-f57d496833a5
function eqmfind(;A = 1,N = 1, α = 0.33, β = 0.96, δ = 0.05)

	# create a firm parameter
	fp = @with_kw (A = A, N = N, α = α, δ = δ)

 	# Create an instance of Household
	am = Household(β = β, a_max = 20.0)

	# Create a grid of r values at which to compute demand and supply of capital
	r_vals = range(0.005, 0.04, length = 20)

	ex_supply(r) = next_K_stock(am, r, fp ) - Kd(r,fp)

	res = fzero(ex_supply, 0.005,0.04)
	(res, Kd(res,fp))

end

# ╔═╡ dbaff1a5-3f7f-48df-b16b-28f23fbbb14c
rstar, kstar = eqmfind()

# ╔═╡ 7828918d-7833-4cad-b183-81385c6cd6f9
let
	title!(visualeq, "GE at r = $(round(rstar,digits=3)), K = $(round(kstar,digits=3))")
	vline!(visualeq, [kstar], color = :black, label = "")
	hline!(visualeq, [rstar], color = :black, label = "")
end

# ╔═╡ 4672052c-649a-47c2-9697-f187fde69fe1
info(text) = Markdown.MD(Markdown.Admonition("info", "Info", [text]));

# ╔═╡ fa733fea-fe6f-4487-a660-7123a6b2843c
info(md"The $r$-specific policy function $\sigma_r(a,z)$ encodes optimal behaviour when the current interest rate is equal to $r$.")

# ╔═╡ 9db0d69f-866d-4da3-9e96-72331d6640da
question(qhead,text) = Markdown.MD(Markdown.Admonition("tip", qhead, [text]));

# ╔═╡ 351b5bec-54a5-4c32-9956-1c013cbb42f3
question("What does that mean?",md"How would a world look like, where people **can** perfectly insure against income fluctuations?")

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Parameters = "d96e819e-fc66-5662-9728-84c9c7592b0a"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
QuantEcon = "fcd29c91-0bd7-5a09-975d-7ac3f643a60c"
Roots = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
LaTeXStrings = "~1.3.0"
Parameters = "~0.12.3"
Plots = "~1.23.6"
QuantEcon = "~0.16.4"
Roots = "~1.3.11"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.5"
manifest_format = "2.0"
project_hash = "2ed4dc351c86f76910bc0f7509878f8fdbaaa65f"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "69f7020bd72f069c219b5e8c236c1fa90d2cb409"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.2.1"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "84918055d15b3114ede17ac6a7182f68870c16f7"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.ArrayInterfaceCore]]
deps = ["LinearAlgebra", "SnoopPrecompile", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "e5f08b5689b1aad068e01751889f2f615c7db36d"
uuid = "30b0a656-2188-435a-8636-2ec0e6a096e2"
version = "0.1.29"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "d9a9701b899b30332bbcb3e1679c41cce81fb0e8"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.3.2"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "f885e7e7c124f8c92650d61b9477b9ac2ee607dd"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.1"

[[deps.ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "9a1d594397670492219635b35a3d830b04730d62"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.1"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "2e62a725210ce3c3c2e1a3080190e7ca491f18d7"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.7.2"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "a851fec56cb73cfdf43762999ec72eff5b86882a"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.15.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.CommonSolve]]
git-tree-sha1 = "68a0743f578349ada8bc911a5cbd5a2ef6ed6d1f"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.0"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "dce3e3fea680869eaa0b774b2e8343e9ff442313"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.40.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.1+0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[deps.Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[deps.DSP]]
deps = ["Compat", "FFTW", "IterTools", "LinearAlgebra", "Polynomials", "Random", "Reexport", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "da8b06f89fce9996443010ef92572b193f8dca1f"
uuid = "717857b8-e6f2-59f4-9121-6e50c889abd2"
version = "0.7.8"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "a4ad7ef19d2cdc2eff57abbbe68032b1cd0bd8f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.13.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "fb372fc76a20edda014dfc2cdb33f23ef80feda6"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.85"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "90630efff0894f8142308e334473eba54c433549"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.5.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "d3ba08ab64bdfd27234d3f61956c966266757fe6"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.7"

[[deps.FiniteDiff]]
deps = ["ArrayInterfaceCore", "LinearAlgebra", "Requires", "Setfield", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "04ed1f0029b6b3af88343e439b995141cb0d0b8d"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.17.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "00e252f4d706b3d55a8863432e742bf5717b498d"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.35"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "0c603255764a1fa0b61752d2bec14cfbd18f7fe8"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+1"

[[deps.GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "30f2b340c2fff8410d89bfcdc9c0a6dd661ac5f7"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.62.1"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "fd75fa3a2080109a2c0ec9864a6e14c60cca3866"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.62.0+0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "1cf1d7dcb4bc32d7b4a5add4232db3750c27ecb4"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.8.0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions", "Test"]
git-tree-sha1 = "709d864e3ed6e3545230601f94e11ebc65994641"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.11"

[[deps.Inflate]]
git-tree-sha1 = "5cd07aab533df5170988219191dfad0519391428"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.3"

[[deps.IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[deps.IntegerMathUtils]]
git-tree-sha1 = "f366daebdfb079fd1fe4e3d560f99a0c892e15bc"
uuid = "18e54dd8-cb9d-406c-a71d-865a43cbb235"
version = "0.1.0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "05110a2ab1fc5f932622ffea2a003221f4782c18"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.3.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a8f4f279b6fa3c3c4f1adadd78a621b13a506bce"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.9"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "c9551dd26e31ab17b86cbd00c2ede019c08758eb"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+1"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "f27132e551e959b3667d8c93eae90973225032dd"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.1.1"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "be9eef9f9d78cecb6f262f3c10da151a6c5ab827"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.5"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "2ce8695e1e699b68702c03402672a69f54b8aca9"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.2.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.MakieCore]]
deps = ["Observables"]
git-tree-sha1 = "2c3fc86d52dfbada1a2e5e150e50f06c30ef149c"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.6.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "Printf", "SnoopPrecompile", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "2a58c70db9287898dcc76b8394f0ff601c11b270"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.12.0"

[[deps.MathProgBase]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9abbe463a1e9fc507f12a69e7f29346c2cdc472c"
uuid = "fdba3010-5040-5b88-9595-932c9decdf73"
version = "0.7.8"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "3295d296288ab1a0a2528feb424b854418acff57"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.2.3"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NLopt]]
deps = ["MathOptInterface", "MathProgBase", "NLopt_jll"]
git-tree-sha1 = "5a7e32c569200a8a03c3d55d286254b0321cd262"
uuid = "76087f3c-5699-56af-9a33-bf431cd00edd"
version = "0.6.5"

[[deps.NLopt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9b1f15a08f9d00cdb2761dcfa6f453f5d0d6f973"
uuid = "079eb43e-fd8e-5478-9966-2cf3e3edb778"
version = "2.7.1+0"

[[deps.NaNMath]]
git-tree-sha1 = "bfe47e760d60b82b66b61d2d44128b62e3a369fb"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.5"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "6862738f9796b3edc1c09d0890afce4eca9e7e93"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.4"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "15003dcb7d8db3c6c857fda14891a539a8f2705a"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.10+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "1903afc76b7d01719d9c30d3c7d501b61db96721"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.7.4"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "67eae2738d63117a196f497d7db789821bce61d1"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.17"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "ae4bbcadb2906ccc085cf52ac286dc1377dceccc"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.1.2"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "b084324b4af5a438cd63619fd006614b3b20b87b"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.0.15"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun"]
git-tree-sha1 = "0d185e8c33401084cab546a756b387b15f76720c"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.23.6"

[[deps.Polynomials]]
deps = ["LinearAlgebra", "MakieCore", "RecipesBase"]
git-tree-sha1 = "a10bf14e9dc2d0897da7ba8119acc7efdb91ca80"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "3.2.5"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[deps.Primes]]
deps = ["IntegerMathUtils"]
git-tree-sha1 = "311a2aa90a64076ea0fac2ad7492e914e6feeb81"
uuid = "27ebfcd6-29c5-5fa9-bf4b-fb8fc14df3ae"
version = "0.5.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "0c03844e2231e12fda4d0086fd7cbe4098ee8dc5"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+2"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "786efa36b7eff813723c4849c90456609cf06661"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.8.1"

[[deps.QuantEcon]]
deps = ["DSP", "DataStructures", "Distributions", "FFTW", "Graphs", "LinearAlgebra", "Markdown", "NLopt", "Optim", "Pkg", "Primes", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "Test"]
git-tree-sha1 = "0069c628273c7a3b793383c7dc5f9744d31dfe28"
uuid = "fcd29c91-0bd7-5a09-975d-7ac3f643a60c"
version = "0.16.4"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
git-tree-sha1 = "44a75aa7a527910ee3d1751d1f0e4148698add9e"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.1.2"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "7ad0dfa8d03b7bcf8c597f59f5292801730c55b8"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.4.1"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "f65dcb5fa46aee0cf9ed6274ccbd597adc49aa7b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.1"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6ed52fdd3382cf21947b15e8870ac0ddbff736da"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.4.0+0"

[[deps.Roots]]
deps = ["CommonSolve", "Printf", "Setfield"]
git-tree-sha1 = "51ee572776905ee34c0568f5efe035d44bf59f74"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "1.3.11"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "def0718ddbabeb5476e51e5a43609bee889f285d"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.8.0"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ef28127915f4229c971eb43f3fc075dd3fe91880"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.2.0"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "3c76dde64d03699e074ac02eb2e8ba8254d428da"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.2.13"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
git-tree-sha1 = "1958272568dc176a1d881acb797beb909c785510"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.0.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "2bb0cb32026a66037360606510fca5984ccc6b75"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.13"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "f625d686d5a88bcd2b15cd81f18f98186fdc0c9a"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.0"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "2ce41e0d042c60ecd131e9fb7154a3bfadbf50d3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.3"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "fed34d0e71b91734bf0a7e10eb1bb05296ddbcd0"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "94f38103c984f89cf77c402f2a68dbd870f8165f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.11"

[[deps.URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll"]
git-tree-sha1 = "2839f1c1296940218e35df0bbb220f2a79686670"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.18.0+4"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─305d8ffd-8e96-4463-b4d3-f4a5a770d3a2
# ╟─351b5bec-54a5-4c32-9956-1c013cbb42f3
# ╟─c1388e32-4a26-11ec-3def-9d7f551edcca
# ╟─bfbc42d2-c7bb-4a13-8c5d-95512940ceee
# ╟─20ef10f8-8a61-492e-9496-3bdd10aaadef
# ╠═07e68196-1f07-41f2-9849-685d1748a3d7
# ╟─8db93197-27b2-4420-9f22-83b1975c4b2a
# ╠═b35dd772-18d8-4184-8ee1-b9d71ed02d40
# ╠═4b805387-b7a3-432a-883c-7c4230842451
# ╟─1a1ffd28-2f8a-415c-b188-7a51c18733b7
# ╠═6e6ccee2-2006-4794-a1b8-16ec70513923
# ╠═b40a922a-4aae-40ef-aa13-51caec059323
# ╟─c9cc0192-6965-4a8b-b8ea-5fe54a6860a9
# ╠═dac90a6c-190b-4d32-82ff-40e4d55cada0
# ╟─fa6baa0b-f496-4665-a7c8-3e4230f1ea6f
# ╠═02d599a4-20bd-4d88-b0c1-86896703b09c
# ╟─e5f8d659-4987-4f71-8d4b-fc6d07304f08
# ╠═cc388378-4ea9-453f-b079-30ecbf2e79a8
# ╠═2559490c-66e6-42a5-b4bd-285fe5f417c7
# ╟─5eb6f22e-1080-48b9-b271-b64a05a4feb9
# ╠═25f75bf9-a55a-459d-8ecb-3b07c7dda94c
# ╟─888c8f09-2a23-4b84-9c3e-f9b04ae7b2de
# ╠═0f70d187-a378-46af-8bbe-b9a61b087e41
# ╟─49b24328-c000-49bd-be92-418a993f7e8f
# ╠═b3f376ae-a00a-493c-9c6a-b4816300ba4f
# ╟─5d8c9e42-d110-49ea-b6cc-de965f21a3a7
# ╟─1a929222-a197-4585-abb2-b4d362b323ce
# ╠═92a82ecc-1421-4ca2-9698-96449c1b03c6
# ╟─3883bd18-c2a3-43d0-977e-d966db842257
# ╠═6fc89260-4d01-4103-8d20-97eef0cf1d55
# ╟─76b08cb1-d121-471e-a268-59e79933ce40
# ╟─1ac0515a-de55-4b9a-9323-ea5e19f4621b
# ╟─ef4cfd16-4a02-4bc6-b65b-b7abf656bf59
# ╠═c3e404c0-dd90-44a7-aaaa-4c726dd49a77
# ╠═9a82365e-d6ac-4e79-a23d-6792d00c9d94
# ╟─43d1b826-9f01-4dc4-99f4-af53b49b1b6c
# ╟─214c2f3b-cefc-4ffc-8158-bdf295b719f4
# ╟─7c5332a7-814e-43fd-bcd1-372ff0406a38
# ╠═137f1aac-0121-45af-aa73-bc48dfd5bd6d
# ╟─cbf78d45-604b-4447-93bd-dc7bd3a2a18a
# ╟─a8b1395d-4c19-4b8e-abf4-95ca7f37b650
# ╟─fa733fea-fe6f-4487-a660-7123a6b2843c
# ╟─62a52d7a-842a-47c3-8565-e02e89b49516
# ╠═116834f6-907f-4cfc-be0f-84784d0e3c7a
# ╠═c7cbcc04-836c-483b-9523-1d84489b12e0
# ╠═2ae833d2-52de-4701-a619-8a33cf1df820
# ╠═5ca1933b-6ee7-4c6c-b8b4-53265074fda3
# ╟─60717847-047c-4e83-85d1-ee9c66aa1e0c
# ╠═b77599a0-c289-41bf-971e-22aeed4dd4e8
# ╟─4a0792a3-a6f6-4e21-8fae-80247a7984cc
# ╠═a8115315-953c-44f9-87d1-f288e7ccf8ee
# ╟─c0386481-4e1e-4107-b6ac-48cecab668bf
# ╠═805799b6-1b7e-464a-ab10-f57d496833a5
# ╠═dbaff1a5-3f7f-48df-b16b-28f23fbbb14c
# ╟─7828918d-7833-4cad-b183-81385c6cd6f9
# ╟─4672052c-649a-47c2-9697-f187fde69fe1
# ╟─9db0d69f-866d-4da3-9e96-72331d6640da
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002