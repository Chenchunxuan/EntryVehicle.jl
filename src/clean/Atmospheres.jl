#Units are L=km M=kg T=hours
#Taken from EntryGuidance.jl Zac

#TO DO: Add MarsGRAM type of atmosphere

abstract type AbstractAtmosphere{T} end

struct ExponentialAtmosphere{T} <: AbstractAtmosphere{T}
    r0::T #reference radius (L)
    H::T #scale height (L)
    ρ0::T #surface density (M/L^3)
end

function EarthExponentialAtmosphere()
    #https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
    ExponentialAtmosphere{Float64}(6378.1, 8.5, 1.217e9)
end

function MarsExponentialAtmosphere()
    #https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html
    ExponentialAtmosphere{Float64}(3396.2, 11.1, 2.0e7)
end

function atmospheric_density(r::AbstractVector{T}, a::ExponentialAtmosphere{T}) where {T}
    R = norm(r)
    atmospheric_density(R,a)
end

function atmospheric_density(r::T, a::ExponentialAtmosphere{T}) where {T}
    ρ = a.ρ0*exp(-(r-a.r0)/a.H)
end
