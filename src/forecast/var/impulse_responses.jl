"""
```
impulse_responses(β, Σ, n_obs_shock, horizon, shock_size = 1;
    method = :cholesky, flip_shocks = false, use_intercept = true,
    frequency_band = (2π/32, 2π/6)) where {S<:Real}
```
computes the impulse responses of a VAR system represented in the form

```
yₜ = Xₜβ + ϵₜ,
```
where `Xₜ` stacks the lags of yₜ (with dimensions n_observables x n_regressors), and

```
ϵₜ ∼ 𝒩 (0, Σ).
```

### Inputs
* `β::AbstractMatrix{S}`: coefficient matrix
* `Σ::AbstractMatrix{S}`: innovations covariance matrix
* `n_obs_shock::Int`: index of the observable to be shocked
* `shock_size::S`: number of standard deviations of the shock

### Keywords
* `method::Symbol`: type of impulse response to compute. The available options are
    `:cholesky` (default), `:maximum_business_cycle_variance` or `:maxBC`, and
    `:cholesky_long_run` or `:choleskyLR`. See `?cholesky_shock`, `?maxBC_shock`,
    and `?cholesky_long_run_shock`.
* `flip_shocks::Bool`: by default, we compute the impulse responses to a negative shock.
    Set `flip_shocks = true` to obtain a positive shock.
* `use_intercept::Bool`: `impulse_responses` assumes `β` has constant term(s). If there
    are no such terms, then `use_intercept` must be set to `false`.
* `frequency_band::Tuple{S,S}`: See `?maxBC_shock`.

### Outputs
* `Y::AbstractMatrix`: Impulse response matrix with dimensions horizons x n_observables
"""
function impulse_responses(β::AbstractMatrix{S}, Σ::AbstractMatrix{S}, n_obs_shock::Int,
                           horizon::Int, shock_size::S = one(S);
                           method::Symbol = :cholesky,
                           flip_shocks::Bool = false,
                           use_intercept::Bool = true,
                           frequency_band::Tuple{S,S} =
                           (2*π/32, 2*π/6)) where {S<:Real}

    # Compute dimensions
    n = size(β, 2)
    lags = convert(Int, use_intercept ? (size(β, 1) - 1) / n : size(β, 1) / n)

    # Compute impact based on IRF type
    Y = zeros(lags + horizon, n)
    Y[lags + 1, :] = if method == :cholesky
        cholesky_shock(Σ, n, n_obs_shock, shock_size;
                       flip_shocks = flip_shocks)
    elseif method == :maximum_business_cycle_variance || method == :maxBC
        maxBC_shock(β, Σ, n, n_obs_shock, shock_size, lags, frequency_band;
                    flip_shocks = flip_shocks)
    elseif method == :choleskyLR || method == :cholesky_long_run
        cholesky_long_run_shock(β, Σ, n_obs_shock, n, lags, shock_size;
                                flip_shocks = flip_shocks)
    else
        error("IRF method $(string(method)) has not been implemented.")
    end

    # For efficiency
    if use_intercept
        β = @views β[2:end, :]
    end

    # Compute impulse response
    for t = 2:horizon
        xT = reshape(Y[lags + t - 1:-1:lags + t - lags, :]', lags * n, 1)'
        Y[lags + t, :] = xT * β
    end

    return Y[lags + 1:end, :]
end

"""
```
cholesky_shock(Σ, n, n_obs_shock, shock_size, flip_shocks = false) where {S<:Real}
```
computes a Cholesky-identified shock to the specified observable.

### Inputs
* `Σ::AbstractMatrix{S}`: innovations covariance matrix
* `n::Int`: number of observables
* `n_obs_shock::Int`: index of the observable to be shocked
* `shock_size::S`: number of standard deviations of the shock

### Keywords
* `flip_shocks::Bool`: by default, we compute the impulse responses to a negative shock.
    Set `flip_shocks = true` to obtain a positive shock.
"""
function cholesky_shock(Σ::Matrix{S}, n::Int, n_obs_shock::Int,
                        shock_size::S; flip_shocks::Bool = false) where {S<:Real}
    cholmat = cholesky((Σ + Σ') ./ 2).L
    vec_shock = zeros(n)
    vec_shock[n_obs_shock] = flip_shocks ? shock_size : -shock_size # negative by DSGE convention
    return (cholmat * vec_shock)'
end

"""
```
maxBC_shock(β, Σ, n, n_obs_shock, shock_size, lags, frequency_band,
    flip_shocks = false) where {S<:Real}
```
maximizes the business cycle variance explained by the observable
whose index is specified by `n_obs_shock` and between the
frequencies specified by `frequency_band`.

### Inputs
* `β::AbstractMatrix{S}`: coefficient matrix
* `Σ::AbstractMatrix{S}`: innovations covariance matrix
* `n::Int`: number of observables
* `n_obs_shock::Int`: index of the observable to be shocked
* `shock_size::S`: number of standard deviations of the shock
* `lags::Int`: number of lags in VAR system
* `frequency_band::Tuple{S,S}`: the frequencies between which the variance of
    the observable specified by `n_obs_shock` will be maximized.

### Keywords
* `flip_shocks::Bool`: by default, we compute the impulse responses to a negative shock.
    Set `flip_shocks = true` to obtain a positive shock.
"""
function maxBC_shock(β::Matrix{S}, Σ::Matrix{S}, n::Int, n_obs_shock::Int, shock_size::S,
                     lags::Int, frequency_band::Tuple{S,S};
                     flip_shocks::Bool = false) where {S<:Real}
    if lags * n < size(β,1)
        β = @views β[2:end, :]
    end

    cholmat = cholesky((Σ + Σ') ./ 2).L
    increment = abs(frequency_band[1] - frequency_band[2]) / 200.
    V = zeros(S, n, n) # variance
    eminusif = zeros(Complex{S}, 1, 1, lags)
    for f = frequency_band[1]:increment:round(frequency_band[2], digits=10) # not rounding sometimes leads to one fewer loop than desired
        eminusif[1, 1, :] = exp.(-im .* f .* collect(1:lags))
        sumB = dropdims(sum(reshape(β', n, n, lags) .*
                           repeat(eminusif, n, n, 1); dims = 3), dims = 3)
        invA = (Matrix{Complex{S}}(I, n, n) - sumB) \ cholmat
        V += reshape(real.(kron(conj(invA[n_obs_shock, :]), invA[n_obs_shock, :])), n, n) .*
            increment ./ abs(frequency_band[1] - frequency_band[2])
    end
    eigout = eigen(V)
    q = eigout.vectors[:, argmax(eigout.values)]
    q .*= sign(q[n_obs_shock])
    q .*= flip_shocks ? shock_size : -shock_size # negative by DSGE convention

    return (cholmat * q)'
end

"""
```
cholesky_long_run_shock(β, Σ, n, n_obs_shock, shock_size, lags, frequency_band,
    flip_shocks = false) where {S<:Real}
```
computes the long-run Cholesky-identified shock to the observable
specified by `n_obs_shock`.

Given a VAR system
```
yₜ = B₁yₜ₋₁ + ... + B₁yₜ₋ₚ + Γϵₜ,      ϵₜ ∼ 𝒩 (0, Σ),
```

the long-run covariance matrix is
```
S̃ = B̃⁻¹ Σ (B̃⁻¹)'
```

and the Cholesky identification is given by
```
ΓΓ' = Σ ⇒ Γ = B̃ * cholesky(S̃).
```

### Inputs
* `β::AbstractMatrix{S}`: coefficient matrix
* `Σ::AbstractMatrix{S}`: innovations covariance matrix
* `n::Int`: number of observables
* `n_obs_shock::Int`: index of the observable to be shocked
* `shock_size::S`: number of standard deviations of the shock
* `lags::Int`: number of lags in VAR system
* `frequency_band::Tuple{S,S}`: the frequencies between which the variance of
    the observable specified by `n_obs_shock` will be maximized.

### Keywords
* `flip_shocks::Bool`: by default, we compute the impulse responses to a negative shock.
    Set `flip_shocks = true` to obtain a positive shock.
"""
function cholesky_long_run_shock(β::Matrix{S}, Σ::Matrix{S}, n_obs_shock::Int, n::Int,
                                 lags::Int, shock_size::S;
                                 flip_shocks::Bool = false) where {S<:Real}
    if n * lags < size(β, 1)
        β = β[2:end,:] # don't need the constant
    end

    # Compute decomposition
    B̃ = Matrix{S}(I, n, n) - dropdims(sum(reshape(β', n, n, lags), dims = 3), dims = 3)
    S̃ = B̃ \ (Σ * inv(B̃)')             # LR covariance = S̃ = B̃⁻¹ * Σ * B̃⁻¹' =>
    Γ = B̃ * cholesky((S̃ + S̃') ./ 2).L # S = B̃ \ (Σ * B̃⁻¹')

    # Compute shock
    vec_shock = zeros(n)
    vec_shock[n_obs_shock] = flip_shocks ? shock_size : -shock_size # negative by DSGE convention
    return (Γ * vec_shock)'
end
