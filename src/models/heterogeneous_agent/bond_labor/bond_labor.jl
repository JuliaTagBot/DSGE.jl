import DataStructures: OrderedDict

"""
```
BondLabor{T} <: AbstractModel{T}
```

### Fields

#### Parameters and Steady-States
* `parameters::Vector{AbstractParameter}`: Vector of all time-invariant model
  parameters.

* `steady_state::Vector{AbstractParameter}`: Model steady-state values, computed
  as a function of elements of `parameters`.

* `keys::OrderedDict{Symbol,Int}`: Maps human-readable names for all model
  parameters and steady-states to their indices in `parameters` and
  `steady_state`.

#### Inputs to Measurement and Equilibrium Condition Equations

The following fields are dictionaries that map human-readable names to row and
column indices in the matrix representations of of the measurement equation and
equilibrium conditions.

* `endogenous_states::OrderedDict{Symbol,Int}`: Maps each state to a column in
  the measurement and equilibrium condition matrices.

* `exogenous_shocks::OrderedDict{Symbol,Int}`: Maps each shock to a column in
  the measurement and equilibrium condition matrices.

* `expected_shocks::OrderedDict{Symbol,Int}`: Maps each expected shock to a
  column in the measurement and equilibrium condition matrices.

* `equilibrium_conditions::OrderedDict{Symbol,Int}`: Maps each equlibrium
  condition to a row in the model's equilibrium condition matrices.

* `observables::OrderedDict{Symbol,Int}`: Maps each observable to a row in the
  model's measurement equation matrices.

#### Model Specifications and Settings

* `spec::String`: The model specification identifier, \"an_schorfheide\", cached
  here for filepath computation.

* `subspec::String`: The model subspecification number, indicating that some
  parameters from the original model spec (\"ss0\") are initialized
  differently. Cached here for filepath computation.

* `settings::Dict{Symbol,Setting}`: Settings/flags that affect computation
  without changing the economic or mathematical setup of the model.

* `test_settings::Dict{Symbol,Setting}`: Settings/flags for testing mode

#### Other Fields

* `rng::MersenneTwister`: Random number generator. Can be is seeded to ensure
  reproducibility in algorithms that involve randomness (such as
  Metropolis-Hastings).

* `testing::Bool`: Indicates whether the model is in testing mode. If `true`,
  settings from `m.test_settings` are used in place of those in `m.settings`.

* `observable_mappings::OrderedDict{Symbol,Observable}`: A dictionary that
  stores data sources, series mnemonics, and transformations to/from model units.
  DSGE.jl will fetch data from the Federal Reserve Bank of
  St. Louis's FRED database; all other data must be downloaded by the
  user. See `load_data` and `Observable` for further details.

"""
type BondLabor{T} <: AbstractModel{T}
    parameters::ParameterVector{T}                         # vector of all time-invariant model parameters
    steady_state::ParameterVector{T}                       # model steady-state values

    # Temporary to get it to work. Need to
    # figure out a more flexible way to define
    # "grids" that are not necessarily quadrature
    # grids within the model
    grids::OrderedDict{Symbol,Union{Grid, Vector}}

    keys::OrderedDict{Symbol,Int}                          # human-readable names for all the model
                                                           # parameters and steady-states

    endogenous_states_unnormalized::OrderedDict{Symbol,UnitRange} # Vector of unnormalized
                                                           # ranges of indices
    endogenous_states::OrderedDict{Symbol,UnitRange}       # Vector of ranges corresponding
                                                           # to normalized (post Klein solution) indices
    exogenous_shocks::OrderedDict{Symbol,Int}              #
    expected_shocks::OrderedDict{Symbol,Int}               #
    equilibrium_conditions::OrderedDict{Symbol,UnitRange}  #
    observables::OrderedDict{Symbol,Int}                   #

    spec::String                                           # Model specification number (eg "m990")
    subspec::String                                        # Model subspecification (eg "ss0")
    settings::Dict{Symbol,Setting}                         # Settings/flags for computation
    test_settings::Dict{Symbol,Setting}                    # Settings/flags for testing mode
    rng::MersenneTwister                                   # Random number generator
    testing::Bool                                          # Whether we are in testing mode or not

    observable_mappings::OrderedDict{Symbol, Observable}
end

description(m::BondLabor) = "BondLabor, $(m.subspec)"

"""
`init_model_indices!(m::BondLabor)`

Arguments:
`m:: BondLabor`: a model object

Description:
Initializes indices for all of `m`'s states, shocks, and equilibrium conditions.
"""
function init_model_indices!(m::BondLabor)
    # Endogenous states
    endogenous_states = collect([
    # These states corresp. to the following in the original notation
    #    MUP,   ZP,    ELLP,  RP
        :μ′_t, :z′_t, :l′_t, :R′_t])

    # Exogenous shocks
    exogenous_shocks = collect([:z_sh])

    # Equilibrium conditions
    equilibrium_conditions = collect([
        :eq_euler, :eq_kolmogorov_fwd, :eq_market_clearing, :eq_TFP])

    # Observables
    observables = keys(m.observable_mappings)

    ########################################################################################
    # Setting indices of endogenous_states and equilibrium conditions manually for now
    nx = get_setting(m, :nx)
    ns = get_setting(m, :ns)
    endo = m.endogenous_states_unnormalized
    eqconds = m.equilibrium_conditions

    # State variables
    endo[:μ′_t]  = 1:nx*ns
    endo[:z′_t]  = nx*ns+1:nx*ns+1

    # Jump variables
    endo[:l′_t]  = nx*ns+2:2*nx*ns+1
    endo[:R′_t]  = 2*nx*ns+2:2*nx*ns+2

    eqconds[:eq_euler]              = 1:nx*ns
    eqconds[:eq_kolmogorov_fwd]     = nx*ns+1:2*nx*ns
    eqconds[:eq_market_clearing]    = 2*nx*ns+1:2*nx*ns+1
    eqconds[:eq_TFP]                = 2*nx*ns+2:2*nx*ns+2
    ########################################################################################

    m.endogenous_states = deepcopy(endo)
    for (i,k) in enumerate(exogenous_shocks);            m.exogenous_shocks[k]            = i end
    for (i,k) in enumerate(observables);                 m.observables[k]                 = i end
end

function BondLabor(subspec::String="ss0";
                      custom_settings::Dict{Symbol, Setting} = Dict{Symbol, Setting}(),
                      testing = false)

    # Model-specific specifications
    spec               = "BondLabor"
    subspec            = subspec
    settings           = Dict{Symbol,Setting}()
    test_settings      = Dict{Symbol,Setting}()
    rng                = MersenneTwister(0)

    # initialize empty model
    m = BondLabor{Float64}(
            # model parameters and steady state values
            Vector{AbstractParameter{Float64}}(), Vector{Float64}(),
            # grids and keys
            OrderedDict{Symbol,Grid}(), OrderedDict{Symbol,Int}(),

            # model indices
            # endogenous states unnormalized, endogenous states normalized
            OrderedDict{Symbol,UnitRange}(), OrderedDict{Symbol,UnitRange}(),
            OrderedDict{Symbol,Int}(), OrderedDict{Symbol,Int}(),
            OrderedDict{Symbol,UnitRange}(), OrderedDict{Symbol,Int}(),

            spec,
            subspec,
            settings,
            test_settings,
            rng,
            testing,
            OrderedDict{Symbol,Observable}())

    # Set settings
    model_settings!(m)
    # default_test_settings!(m)
    for custom_setting in values(custom_settings)
        m <= custom_setting
    end

    # Set observable transformations
    # init_observable_mappings!(m)

    # Initialize parameters
    init_parameters!(m)

    # Initialize grids
    init_grids!(m)

    init_model_indices!(m)

    # Temporarily comment out while working on steadystate!
    # Solve for the steady state
    # steadystate!(m)

    # So that the indices of m.endogenous_states reflect the normalization
    # normalize_state_indices!(m)

    return m
end

"""
```
init_parameters!(m::BondLabor)
```

Initializes the model's parameters, as well as empty values for the steady-state
parameters (in preparation for `steadystate!(m)` being called to initialize
those).
"""
function init_parameters!(m::BondLabor)
    # Initialize parameters
    m <= parameter(:R, 1.04, fixed = true,
                   description = "R: Steady-state gross real interest rate.", tex_label = "R")
    m <= parameter(:γ, 1.0, fixed = true,
                   description = "γ: CRRA Parameter.", tex_label = "\\gamma")
    m <= parameter(:ν, 1.0, fixed = true,
                   description = "Inverse Frisch elasticity of labor supply.", tex_label = "\\nu")
    m <= parameter(:abar, -0.5, fixed = true,
                   description = "Borrowing floor.", tex_label = "\\bar{a}")
    m <= parameter(:ρ_z, 0.95, (1e-5, 0.999), (1e-5, 0.999), SquareRoot(), BetaAlt(0.5, 0.2), fixed=false,
                   description="ρ_z: AR(1) coefficient in the technology process.",
                   tex_label="\\rho_z")
    m <= parameter(:μ_s, 0., fixed = true, description = "μ_s: Mu of log normal in income")
    m <= parameter(:σ_s, 0.5, fixed = true,
                   description = "σ_s: Sigma of log normal in income")
    # m <= parameter(:e_y, 0.1, fixed = true, description = "e_y: Measurement error on GDP",
                   # tex_label = "e_y")

    # Setting steady-state parameters
    nx = get_setting(m, :nx)
    ns = get_setting(m, :ns)

    m <= SteadyStateParameterGrid(:lstar, fill(NaN, nx*ns), description = "Steady-state expected discounted
                                  marginal utility of consumption", tex_label = "l_*")
    m <= SteadyStateParameterGrid(:cstar, fill(NaN, nx*ns), description = "Steady-state consumption",
                                  tex_label = "c_*")
    m <= SteadyStateParameterGrid(:ηstar, fill(NaN, nx*ns), description = "Steady-state
                                  level of labor supply",
                                  tex_label = "\\eta_*")
    m <= SteadyStateParameterGrid(:μstar, fill(NaN, nx*ns), description = "Steady-state cross-sectional
                                  density of cash on hand", tex_label = "\\mu_*")

    # Figure out a better description for this...
    m <= SteadyStateParameterGrid(:χstar, fill(NaN, nx*ns), description = "Steady-state
                                  solution for constrained consumption and labor supply",
                                  tex_label = "\\chi_*")

    m <= SteadyStateParameter(:βstar, NaN, description = "Steady-state discount factor",
                              tex_label = "\\beta_*")
    # m <= SteadyStateParameter(:Lstar, NaN, description = "Steady-state labor", tex_label = "L_*")
    # m <= SteadyStateParameter(:Wstar, NaN, description = "Steady-state wages", tex_label = "W_*")
    # m <= SteadyStateParameterGrid(:KFstar, fill(NaN, (nw, nw)), description = "Steady-state Kolmogorov
                                  # Forward Equation", tex_label = "KF_*")
end

"""
```
init_grids!(m::BondLabor)
```
"""
function init_grids!(m::BondLabor)
    xscale  = get_setting(m, :xscale)
    xlo     = get_setting(m, :xlo)
    xhi     = get_setting(m, :xhi)
    nx      = get_setting(m, :nx)

    ns      = get_setting(m, :ns)
    λ       = get_setting(m, :λ)

    grids = OrderedDict()

    # Cash on hand grid
    grids[:xgrid] = Grid(uniform_quadrature(xscale), xlo, xhi, nx, scale = xscale)

    # Skill grid
    lsgrid, sprob, sscale = tauchen86(m[:μ_s].value, m[:σ_s].value, ns, λ)
    swts = (sscale/ns)*ones(ns)
    sgrid = exp.(lsgrid)
    grids[:sgrid] = Grid(sgrid, swts, sscale)

    # Density of skill across skill grid
    grids[:ggrid] = sprob./swts

    # Total grid vectorized across both dimensions
    grids[:sgrid_total] = kron(sgrid, ones(nx))
    grids[:xgrid_total] = kron(ones(ns), grids[:xgrid].points)
    grids[:weights_total] = kron(swts, grids[:xgrid].weights)

    m.grids = grids
end

"""
```
steadystate!(m::BondLabor)
```

Calculates the model's steady-state values. `steadystate!(m)` must be called whenever
the parameters of `m` are updated.
"""
function steadystate!(m::BondLabor)
    return m
end

function model_settings!(m::BondLabor)
    default_settings!(m)

    # Defaults
    # Data settings for released and conditional data. Default behavior is to set vintage
    # of data to today's date.
    vint = Dates.format(now(), DSGE_DATE_FORMAT)
    m <= Setting(:data_vintage, vint, true, "vint", "Data vintage")

    saveroot = normpath(joinpath(dirname(@__FILE__), "../../../","save"))
    datapath = normpath(joinpath(dirname(@__FILE__), "../../../","save","input_data"))

    m <= Setting(:saveroot, saveroot, "Root of data directory structure")
    m <= Setting(:dataroot, datapath, "Input data directory path")

    # Anticipated shocks
    m <= Setting(:n_anticipated_shocks, 0,
                 "Number of anticipated policy shocks")
    # m <= Setting(:n_anticipated_shocks_padding, 20,
                 # "Padding for anticipated policy shocks")

    # Number of states and jumps
    # May want to generalize this functionality for other models with multiple
    # distributions
    m <= Setting(:normalize_distr_variables, true, "Whether or not to perform the
                 normalization of the μ distribution in the Klein solution step")

    m <= Setting(:state_indices, 1:2, "Which indices of m.endogenous_states correspond to state
                 variables")
    m <= Setting(:jump_indices, 3:4, "Which indices of m.endogenous_states correspond to jump
                 variables")

    # Need to think of a better way to handle indices accounting for distributional
    # variables
    m <= Setting(:n_states, 101 - get_setting(m, :normalize_distr_variables),
                 "Number of state variables, in the true sense (fully
                 backward looking) accounting for the discretization across the grid")
    m <= Setting(:n_jumps, 100,
                 "Number of jump variables (forward looking) accounting for
                the discretization across the grid")

    m <= Setting(:n_model_states, get_setting(m, :n_states) + get_setting(m, :n_jumps),
                 "Number of 'states' in the state space model. Because backward and forward
                 looking variables need to be explicitly tracked for the Klein solution
                 method, we have n_states and n_jumps")

    # Mollifier setting parameters
    m <= Setting(:In, 0.443993816237631, "Normalizing constant for the mollifier")
    m <= Setting(:elo, 0.0, "Lower bound on stochastic consumption commitments")
    m <= Setting(:ehi, 1.0, "Upper bound on stochastic consumption commitments")

    # x: Cash on Hand Grid Setup
    m <= Setting(:nx, 50, "Cash on hand distribution grid points")
    m <= Setting(:xlo, -0.5 - 1.0, "Lower bound on cash on hand")
    m <= Setting(:xhi, 4.0, "Upper Bound on cash on hand")
    m <= Setting(:xscale, get_setting(m, :xhi) - get_setting(m, :xlo), "Size of the xgrid")

    # s: Skill Distribution/ "Units of effective labor" Grid Setup
    m <= Setting(:ns, 2, "Skill distribution grid points")
    m <= Setting(:λ, 3.0, "The λ parameter in the Tauchen distribution calculation")

    # Total grid x*s
    m <= Setting(:n, get_setting(m, :nx) * get_setting(m, :ns), "Total grid size, multiplying
                 across grid dimensions.")
end

# # For normalizing the states
# function normalize_state_indices!(m::AbstractModel)
    # endo                 = m.endogenous_states
    # state_indices        = get_setting(m, :state_indices)
    # jump_indices         = get_setting(m, :jump_indices)
    # normalization_factor = get_setting(m, :normalize_distr_variables)

    # model_state_keys     = endo.keys
    # jump_keys            = endo.keys[jump_indices]

    # # This structure assumes that states are always ordered before jumps
    # # And that both states and jumps have the same number of variables
    # # to be normalized, in this case μ′_t1 and μ′_t
    # normalize_states!(endo, normalization_factor, model_state_keys)
    # normalize_jumps!(endo, normalization_factor, jump_keys)

    # # TO DO: Include assertions to ensure that the indices are all
    # # consecutive and that the right factor was subtracted from each distribution object
# end

# # Shift a UnitRange type down by an increment
# # If this UnitRange is the first_range in the group being shifted, then do not
# # subtract the increment from the start
# # e.g.
# # If you have 1:80 as your first range, then shift(1:80, -1; first_range = true)
# # should return 1:79
# # However, if you have 81:160 as range, that is not your first range, then the
# # function should return 80:159
# function shift(inds::UnitRange, increment::Int64; first_range::Bool = false)
    # if first_range
        # return UnitRange(inds.start, inds.stop + increment)
    # else
        # return UnitRange(inds.start + increment, inds.stop + increment)
    # end
# end

# function normalize_states!(endo::OrderedDict, normalization_factor::Bool,
                           # model_state_keys::Vector{Symbol})
    # for (i, model_state) in enumerate(model_state_keys)
        # inds = endo[model_state]
        # if i == 1
            # endo[model_state] = shift(inds, -normalization_factor, first_range = true)
        # else
            # endo[model_state] = shift(inds, -normalization_factor)
        # end
    # end
# end

# function normalize_jumps!(endo::OrderedDict, normalization_factor::Bool,
                          # jump_keys::Vector{Symbol})
    # for (i, jump) in enumerate(jump_keys)
        # inds = endo[jump]
        # if i == 1
            # endo[jump] = shift(inds, -normalization_factor, first_range = true)
        # else
            # endo[jump] = shift(inds, -normalization_factor)
        # end
    # end
# end
