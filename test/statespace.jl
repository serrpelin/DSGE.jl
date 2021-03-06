m = AnSchorfheide()
system = compute_system(m)
Φ, Ψ, F_ϵ, F_u = DSGE.compute_system_function(system)
zero_sys = DSGE.zero_system_constants(system)

@testset "Check System, Transition, Measurement, and PseduoMeasurement access functions" begin
    @test typeof(system) == System{Float64}
    @test typeof(system[:transition]) == Transition{Float64}
    @test typeof(system[:measurement]) == Measurement{Float64}
    @test typeof(system[:pseudo_measurement]) == PseudoMeasurement{Float64}
    @test typeof(system[:transition][:TTT]) == Matrix{Float64}
    @test typeof(system[:transition][:RRR]) == Matrix{Float64}
    @test typeof(system[:transition][:CCC]) == Vector{Float64}
    @test typeof(system[:measurement][:ZZ]) == Matrix{Float64}
    @test typeof(system[:measurement][:DD]) == Vector{Float64}
    @test typeof(system[:measurement][:QQ]) == Matrix{Float64}
    @test typeof(system[:measurement][:EE]) == Matrix{Float64}
    @test typeof(system[:pseudo_measurement][:ZZ_pseudo]) == Matrix{Float64}
    @test typeof(system[:pseudo_measurement][:DD_pseudo]) == Vector{Float64}
end

@testset "Check miscellaneous functions acting on System types" begin
    @test sum(zero_sys[:CCC]) == 0.
    @test sum(zero_sys[:DD]) == 0.
    @test sum(zero_sys[:DD_pseudo]) == 0.
    @test Φ(ones(size(system[:transition][:TTT],2)), zeros(size(system[:transition][:RRR],2))) ==
        system[:transition][:TTT] * ones(size(system[:transition][:TTT],2))
    @test Ψ(ones(size(system[:transition][:TTT],2))) ==
        system[:measurement][:ZZ] * ones(size(system[:transition][:TTT],2)) + system[:measurement][:DD]
    @test F_ϵ.μ == zeros(3)
    @test F_ϵ.Σ.mat == system[:measurement][:QQ]
    @test F_u.μ == zeros(3)
    @test F_u.Σ.mat == system[:measurement][:EE]
end

@testset "Using compute_system to update an existing system" begin

    # Check updating
    system1 = compute_system(m, system)
    system2 = compute_system(m, system; observables = collect(keys(m.observables))[1:end - 1],
                                  pseudo_observables = collect(keys(m.pseudo_observables))[1:end - 1],
                                  shocks = collect(keys(m.exogenous_shocks))[1:end - 1],
                                  states = collect(keys(m.endogenous_states))[1:end - 1])
    system3 = compute_system(m, system; zero_DD = true)
    system4 = compute_system(m, system; zero_DD_pseudo = true)

    @test system1[:TTT] ≈ system[:TTT]
    @test system1[:RRR] ≈ system[:RRR]
    @test system1[:CCC] ≈ system[:CCC]
    @test system1[:ZZ] ≈ system[:ZZ]
    @test system1[:DD] ≈ system[:DD]
    @test system1[:QQ] ≈ system[:QQ]
    @test system1[:EE] ≈ zeros(size(system[:ZZ], 1), size(system[:ZZ], 1))
    @test system1[:ZZ_pseudo] ≈ system[:ZZ_pseudo]
    @test system1[:DD_pseudo] ≈ system[:DD_pseudo]

    @test system2[:TTT] ≈ system[:TTT][1:end - 1, 1:end - 1]
    @test system2[:RRR] ≈ system[:RRR][1:end - 1, 1:end - 1]
    @test sum(abs.(system2[:CCC])) ≈ sum(abs.(system[:CCC][1:end - 1])) ≈ 0.
    @test system2[:ZZ] ≈ system[:ZZ][1:end - 1, 1:end - 1]
    @test system2[:DD] ≈ system[:DD][1:end - 1]
    @test system2[:QQ] ≈ system[:QQ][1:end - 1, 1:end - 1]
    @test system2[:EE] ≈ zeros(size(system[:ZZ], 1) - 1, size(system[:ZZ], 1) - 1)
    @test system2[:ZZ_pseudo] ≈ system[:ZZ_pseudo][1:end - 1, 1:end - 1]
    @test system2[:DD_pseudo] ≈ system[:DD_pseudo][1:end - 1]

    @test system3[:TTT] ≈ system[:TTT]
    @test system3[:RRR] ≈ system[:RRR]
    @test system3[:CCC] ≈ system[:CCC]
    @test system3[:ZZ] ≈ system[:ZZ]
    @test system3[:DD] ≈ zeros(length(system[:DD]))
    @test system3[:QQ] ≈ system[:QQ]
    @test system3[:EE] ≈ zeros(size(system[:ZZ], 1), size(system[:ZZ], 1))
    @test system3[:ZZ_pseudo] ≈ system[:ZZ_pseudo]
    @test system3[:DD_pseudo] ≈ system[:DD_pseudo]

    @test system4[:TTT] ≈ system[:TTT]
    @test system4[:RRR] ≈ system[:RRR]
    @test system4[:CCC] ≈ system[:CCC]
    @test system4[:ZZ] ≈ system[:ZZ]
    @test system4[:DD] ≈ system[:DD]
    @test system4[:QQ] ≈ system[:QQ]
    @test system4[:EE] ≈ zeros(size(system[:ZZ], 1), size(system[:ZZ], 1))
    @test system4[:ZZ_pseudo] ≈ system[:ZZ_pseudo]
    @test system4[:DD_pseudo] ≈ zeros(length(system[:DD_pseudo]))

    # Check errors
    @test_throws ErrorException compute_system(m, system; observables = [:blah])
    @test_throws ErrorException compute_system(m, system; states = [:blah])
    @test_throws KeyError compute_system(m, system; shocks = [:blah])
    @test_throws ErrorException compute_system(m, system; pseudo_observables = [:blah])
end

@testset "VAR approximation of state space" begin
    m = Model1002("ss10"; custom_settings =
                  Dict{Symbol,Setting}(:add_laborshare_measurement =>
                                       Setting(:add_laborshare_measurement, true)))

    system = compute_system(m)
    system = compute_system(m, system; observables = [:obs_hours, :obs_gdpdeflator,
                                                      :laborshare_t, :NominalWageGrowth],
                            shocks = collect(keys(m.exogenous_shocks)))
    yyyyd, xxyyd, xxxxd = DSGE.var_approx_state_space(system[:TTT], system[:RRR], system[:QQ],
                                                 system[:DD], system[:ZZ], system[:EE],
                                                 zeros(size(system[:ZZ], 1),
                                                       DSGE.n_shocks_exogenous(m)),
                                                 4; get_population_moments = true)
    yyyydc, xxyydc, xxxxdc = DSGE.var_approx_state_space(system[:TTT], system[:RRR], system[:QQ],
                                                         system[:DD], system[:ZZ], system[:EE],
                                                         zeros(size(system[:ZZ], 1),
                                                               DSGE.n_shocks_exogenous(m)),
                                                         4; get_population_moments = true,
                                                         use_intercept = true)
    β, Σ = DSGE.var_approx_state_space(system[:TTT], system[:RRR], system[:QQ], system[:DD],
                                  system[:ZZ], system[:EE],
                                  zeros(size(system[:ZZ], 1), DSGE.n_shocks_exogenous(m)),
                                  4; get_population_moments = false)
    βc, Σc = DSGE.var_approx_state_space(system[:TTT], system[:RRR], system[:QQ], system[:DD],
                                  system[:ZZ], system[:EE],
                                  zeros(size(system[:ZZ], 1), DSGE.n_shocks_exogenous(m)),
                                  4; get_population_moments = false, use_intercept = true)

    expmat = load("reference/exp_var_approx_state_space.jld2")
    @test @test_matrix_approx_eq yyyyd expmat["yyyyd"]
    @test @test_matrix_approx_eq xxyyd expmat["xxyyd"][2:end, :]
    @test @test_matrix_approx_eq xxxxd expmat["xxxxd"][2:end, 2:end]
    @test @test_matrix_approx_eq yyyydc expmat["yyyyd"]
    @test @test_matrix_approx_eq xxyydc expmat["xxyyd"]
    @test @test_matrix_approx_eq xxxxdc expmat["xxxxd"]

    expβ = \(expmat["xxxxd"][2:end, 2:end], expmat["xxyyd"][2:end, :])
    expΣ = expmat["yyyyd"] - expmat["xxyyd"][2:end, :]' * expβ
    expΣ += expΣ'
    expΣ ./= 2
    @test @test_matrix_approx_eq β expβ
    @test @test_matrix_approx_eq Σ expΣ

    expβc = \(expmat["xxxxd"], expmat["xxyyd"])
    expΣc = expmat["yyyyd"] - expmat["xxyyd"]' * expβc
    expΣc += expΣc'
    expΣc ./= 2
    @test @test_matrix_approx_eq βc expβc
    @test @test_matrix_approx_eq Σc expΣc

    # Check DSGEVAR automates this properly
    dsgevar = DSGEVAR(m)
    DSGE.update!(dsgevar, shocks = collect(keys(m.exogenous_shocks)),
                 observables = [:obs_hours, :obs_gdpdeflator, :laborshare_t, :NominalWageGrowth],
                 lags = 4, λ = Inf)
    yyyyd, xxyyd, xxxxd = compute_system(dsgevar; get_population_moments = true)
    yyyydc, xxyydc, xxxxdc = compute_system(dsgevar; get_population_moments = true, use_intercept = true)
    β, Σ = compute_system(dsgevar)
    βc, Σc = compute_system(dsgevar; use_intercept = true)

    @test @test_matrix_approx_eq yyyyd expmat["yyyyd"]
    @test @test_matrix_approx_eq xxyyd expmat["xxyyd"][2:end, :]
    @test @test_matrix_approx_eq xxxxd expmat["xxxxd"][2:end, 2:end]
    @test @test_matrix_approx_eq yyyydc expmat["yyyyd"]
    @test @test_matrix_approx_eq xxyydc expmat["xxyyd"]
    @test @test_matrix_approx_eq xxxxdc expmat["xxxxd"]

    expβ = \(expmat["xxxxd"][2:end, 2:end], expmat["xxyyd"][2:end, :])
    expΣ = expmat["yyyyd"] - expmat["xxyyd"][2:end, :]' * expβ
    expΣ += expΣ'
    expΣ ./= 2
    @test @test_matrix_approx_eq β expβ
    @test @test_matrix_approx_eq Σ expΣ

    expβc = \(expmat["xxxxd"], expmat["xxyyd"])
    expΣc = expmat["yyyyd"] - expmat["xxyyd"]' * expβc
    expΣc += expΣc'
    expΣc ./= 2
    @test @test_matrix_approx_eq βc expβc
    @test @test_matrix_approx_eq Σc expΣc
end

@testset "VAR using DSGE as a prior" begin
    m = Model1002("ss10"; custom_settings =
                  Dict{Symbol,Setting}(:add_laborshare_measurement =>
                                       Setting(:add_laborshare_measurement, true)))
    dsgevar = DSGEVAR(m)
    jlddata = load(joinpath(dirname(@__FILE__), "reference/test_dsgevar_lambda_irfs.jld2"))
    DSGE.update!(dsgevar, shocks = collect(keys(m.exogenous_shocks)),
                 observables = [:obs_hours, :obs_gdpdeflator, :laborshare_t, :NominalWageGrowth],
                 lags = 4, λ = Inf)
    data = jlddata["data"]
    yyyydc1, xxyydc1, xxxxdc1 = compute_system(dsgevar; get_population_moments = true, use_intercept = true)
    βc1, Σc1 = compute_system(dsgevar; use_intercept = true)

    yyyyd2, xxyyd2, xxxxd2 = compute_system(dsgevar, data; get_population_moments = true)
    β2, Σ2 = compute_system(dsgevar, data)

    # Check when λ = Inf
    @test @test_matrix_approx_eq yyyydc1 yyyyd2
    @test @test_matrix_approx_eq xxyydc1 xxyyd2
    @test @test_matrix_approx_eq xxxxdc1 xxxxd2
    @test @test_matrix_approx_eq βc1 β2
    @test @test_matrix_approx_eq Σc1 Σ2

    # Check when λ is finite
    DSGE.update!(dsgevar, λ = 1.)
Random.seed!(1793) # need to seed for this
    yyyyd, xxyyd, xxxxd = compute_system(dsgevar, data; get_population_moments = true)
    β, Σ = compute_system(dsgevar, data)

    @test @test_matrix_approx_eq jlddata["exp_data_beta"] β
    @test @test_matrix_approx_eq jlddata["exp_data_sigma"] Σ
end

@testset "VECM approximation of state space" begin
    matdata = load("reference/vecm_approx_state_space.jld2")
    nobs = Int(matdata["nvar"])
    p = Int(matdata["nlags"])
    coint = Int(matdata["coint"])
    TTT = matdata["TTT"]
    RRR = matdata["RRR"]
    ZZ = matdata["ZZ"]
    DD = vec(matdata["DD"])
    QQ = matdata["QQ"]
    EE = matdata["EE"]
    MM = matdata["MM"]
    yyyyd, xxyyd, xxxxd = DSGE.vecm_approx_state_space(TTT, RRR, QQ,
                                                       DD, ZZ, EE, MM, nobs,
                                                       p, coint; get_population_moments = true,
                                                       test_GA0 = matdata["GA0"])
    yyyydc, xxyydc, xxxxdc = DSGE.vecm_approx_state_space(TTT, RRR, QQ,
                                                          DD, ZZ, EE, MM, nobs,
                                                          p, coint; get_population_moments = true,
                                                          use_intercept = true, test_GA0 = matdata["GA0"])
    β, Σ = DSGE.vecm_approx_state_space(TTT, RRR, QQ, DD,
                                        ZZ, EE, MM, nobs, p, coint;
                                        get_population_moments = false,
                                        test_GA0 = matdata["GA0"])
    βc, Σc = DSGE.vecm_approx_state_space(TTT, RRR, QQ, DD,
                                          ZZ, EE, MM, nobs, p, coint;
                                          get_population_moments = false, use_intercept = true,
                                          test_GA0 = matdata["GA0"])

    no_int_inds = vcat(1:coint, coint + 2:size(matdata["xxyyd"], 1))
    @test @test_matrix_approx_eq yyyyd matdata["yyyyd"]
    @test @test_matrix_approx_eq xxyyd matdata["xxyyd"][no_int_inds, :]
    @test @test_matrix_approx_eq xxxxd matdata["xxxxd"][no_int_inds, no_int_inds]
    @test @test_matrix_approx_eq yyyydc matdata["yyyyd"]
    @test @test_matrix_approx_eq xxyydc matdata["xxyyd"]
    @test @test_matrix_approx_eq xxxxdc matdata["xxxxd"]

    expβ = \(matdata["xxxxd"][no_int_inds, no_int_inds], matdata["xxyyd"][no_int_inds, :])
    expΣ = matdata["yyyyd"] - matdata["xxyyd"][no_int_inds, :]' * expβ
    @test @test_matrix_approx_eq β expβ
    @test @test_matrix_approx_eq Σ expΣ

    expβc = matdata["xxxxd"] \ matdata["xxyyd"]
    expΣc = matdata["yyyyd"] - matdata["xxyyd"]' * expβc
    @test @test_matrix_approx_eq βc expβc
    @test @test_matrix_approx_eq Σc expΣc

    # Check DSGEVECM automates this properly
    # m = Model1002()
    # dsgevecm = DSGEVECM(m)
    # DSGE.update!(dsgevecm, shocks = collect(keys(m.exogenous_shocks)),
    #              observables = [:obs_hours, :obs_gdpdeflator, :laborshare_t, :NominalWageGrowth],
    #              lags = 4, λ = Inf)
    # yyyyd, xxyyd, xxxxd = compute_system(dsgevecm; get_population_moments = true)
    # yyyydc, xxyydc, xxxxdc = compute_system(dsgevecm; get_population_moments = true, use_intercept = true)
    # β, Σ = compute_system(dsgevecm)
    # βc, Σc = compute_system(dsgevecm; use_intercept = true)

    # @test @test_matrix_approx_eq yyyyd matdata["yyyyd"]
    # @test @test_matrix_approx_eq xxyyd matdata["xxyyd"][2:end, :]
    # @test @test_matrix_approx_eq xxxxd matdata["xxxxd"][2:end, 2:end]
    # @test @test_matrix_approx_eq yyyydc matdata["yyyyd"]
    # @test @test_matrix_approx_eq xxyydc matdata["xxyyd"]
    # @test @test_matrix_approx_eq xxxxdc matdata["xxxxd"]

    # expβ = \(matdata["xxxxd"][2:end, 2:end], matdata["xxyyd"][2:end, :])
    # expΣ = matdata["yyyyd"] - matdata["xxyyd"][2:end, :]' * expβ
    # expΣ += expΣ'
    # expΣ ./= 2
    # @test @test_matrix_approx_eq β expβ
    # @test @test_matrix_approx_eq Σ expΣ

    # expβc = \(matdata["xxxxd"], matdata["xxyyd"])
    # expΣc = matdata["yyyyd"] - matdata["xxyyd"]' * expβc
    # expΣc += expΣc'
    # expΣc ./= 2
    # @test @test_matrix_approx_eq βc expβc
    # @test @test_matrix_approx_eq Σc expΣc
end

@testset "Updating a system for a DSGEVECM" begin
    dsge = AnSchorfheide()
    m = DSGEVECM(dsge)
    sys = compute_system(dsge)
    Dout1 = DSGE.compute_DD_coint_add(m, sys, [:obs_gdp, :obs_cpi])
    @info "The following 2 warnings about an empty vector are expected"
    sys_dsgevecm, Dout2 = compute_system(m, sys; get_DD_coint_add = true,
                                         cointegrating_add = [:obs_gdp, :obs_cpi])
    Dout3 = DSGE.compute_DD_coint_add(m, sys, Vector{Symbol}(undef, 0))
    _, Dout4 = compute_system(m, sys; get_DD_coint_add = true)

    # Check computing DD_coint_add
    @test Dout1 == sys[:DD][1:2]
    @test Dout2 == sys[:DD][1:2]
    @test isempty(Dout3)
    @test isempty(Dout4)

    # Check the system looks right
    @test @test_matrix_approx_eq sys[:TTT] sys_dsgevecm[:TTT]
    @test @test_matrix_approx_eq sys[:RRR] sys_dsgevecm[:RRR]
    @test @test_matrix_approx_eq sys[:CCC] sys_dsgevecm[:CCC]
    @test @test_matrix_approx_eq sys[:ZZ] sys_dsgevecm[:ZZ]
    @test @test_matrix_approx_eq sys[:DD] sys_dsgevecm[:DD]
    @test @test_matrix_approx_eq sys[:QQ] sys_dsgevecm[:QQ]
    @test @test_matrix_approx_eq sys_dsgevecm[:EE] zeros(size(sys_dsgevecm[:EE]))
end




nothing
