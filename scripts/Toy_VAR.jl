using DrWatson
@quickactivate "Toy_model"

using FredData
using AutoregressiveModels
using Dates
using DataFrames
using DataFramesMeta
using CairoMakie
using Statistics

# loading the functions we programmed
include(srcdir("functions.jl"))

# download data from Fred
f = Fred("6c299e3c19f8a105e43d2ef4202c3b29")
# GDP
GDP = get_fred_data(f, "GDPC1", "q", "avg")
# Inflation
interest_rate = get_fred_data(f, "DFF", "q", "avg")
# interest rate
pce_index = get_fred_data(f, "PCEPI", "q", "avg")

# create a DataFrame that contains the data
start_date = Date(1970, 1, 1)
end_date = GDP.date[end]

GDP = @chain GDP begin
        @where(:date .>= start_date)
        @where(:date .<= end_date)
        @select(:date, :value)
end
interest_rate = @chain interest_rate begin
        @where(:date .>= start_date )
        @where(:date .<= end_date)
        @select(:date, :value)
end
pce_index = @chain pce_index begin
        @where(:date .>= start_date)
        @where(:date .<= end_date)
        @select(:date, :value)
end

df = DataFrame(
    date = collect(start_date:Month(3):end_date),
    real_GDP = GDP.value,
    i = interest_rate.value,
    cpi = pce_index.value
)

# get logs of GDP and inflation
df.GDP = log.(df.real_GDP)
df.inflation = log.(df.cpi)

# obtain the yearl on year growth rate of GDP and inflation
df.d4_ln_gdp = [fill(NaN, 4); (df.GDP[5:end] .- df.GDP[1:end-4])*100]
df.d4_ln_cpi = [fill(NaN, 4); (df.inflation[5:end] .- df.inflation[1:end-4])*100]

# eliminate rows with NaN values
df = filter(row -> all(x -> !(x isa Number && isnan(x)), row), df)

# Creating a VAR model
names = [:d4_ln_gdp, :d4_ln_cpi, :i]
VAR_est = fit(VARProcess, df, names, 4, choleskyresid=true, adjust_dofr=false)

VAR_est

# Unconditional forecast
# We collect the last four values
y_hist = [
        [df.d4_ln_gdp[end], df.d4_ln_cpi[end], df.i[end]],
        [df.d4_ln_gdp[end-1], df.d4_ln_cpi[end-1], df.i[end-1]],
        [df.d4_ln_gdp[end-2], df.d4_ln_cpi[end]-2, df.i[end-2]],
        [df.d4_ln_gdp[end-3], df.d4_ln_cpi[end-3], df.i[end-3]]
]

# gettin the coefficients
VAR_coefs = coef(VAR_est)
VAR_coefs = VAR_coefs'

# Paparing the matrices
c = VAR_coefs[1:3, 1]
A1 = VAR_coefs[1:3, 2:4]
A2 = VAR_coefs[1:3, 5:7]
A3 = VAR_coefs[1:3, 8:10]
A4 = VAR_coefs[1:3, 11:13]

A = [A1, A2, A3, A4]

# Setting the horizon length
h = 12

# We use the function we programmed to make forecasts.
forecast_result = forecast_VARp(A, c, y_hist, h)

# adding the results
df_ploting = DataFrame(
        date = vcat(df.date, [df.date[end] + Month(3 * i) for i in 1:h]),
        d4_ln_gdp = [df.d4_ln_gdp; forecast_result[1,:]],
        d4_ln_cpi = [df.d4_ln_cpi; forecast_result[2,:]],
        i = [df.i; forecast_result[3,:]],
)

# crop the results from 2005 to the end of the forecast
df_ploting = @where(df_ploting, :date .>= Date(2005,1,1))

# Plottin the results
# We created a function that plotting the results
fig = forecast_plotting(
        df_ploting, 
        "Crecimiento de los Estados Unidos",
        "Ejemplo Toy Model VAR(4)",
        "d4_ln_gdp",
        "Crecimiento",
        h,
        mean(df.d4_ln_gdp)
        )

save(plotsdir(plotsdir(), "GDP.png"), fig, px_per_unit=2.0)

fig = forecast_plotting(
        df_ploting, 
        "Inflación PCE de Estados Unidos",
        "Ejemplo Toy Model VAR(4)",
        "d4_ln_cpi",
        "tasa de variación",
        h,
        mean(df.d4_ln_cpi)
        )

save(plotsdir(plotsdir(), "PCE.png"), fig, px_per_unit=2.0)
        
fig = forecast_plotting(
        df_ploting, 
        "Tasa de fondos federales",
        "Ejemplo Toy Model VAR(4)",
        "i",
        "tasa",
        h,
        mean(df.i)
        )

save(plotsdir(plotsdir(), "i.png"), fig, px_per_unit=2.0)


