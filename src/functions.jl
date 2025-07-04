using DrWatson
@quickactivate "Toy_model"

function get_fred_data(f, series_id::String, frequency::String, aggregation)
    data = get_data(f, series_id, frequency=frequency, aggregation_method=aggregation)
    data = data.data
    return data
end

# Forecast function
function forecast_VARp(A, c, Y_hist, h)
    p = length(A)         
    K = length(c)         
    forecasts = zeros(K, h)
    
    Y = copy(Y_hist)

    for i in 1:h
        y_next = c
        for j in 1:p
            y_next += A[j] * Y[j]
        end
        forecasts[:, i] = y_next

        pushfirst!(Y, y_next)
        pop!(Y)  
    end

    return forecasts
end

# Plotting function
function forecast_plotting(
    df, 
    t::String, 
    st::String, 
    var_name::String, 
    yl::String, 
    horizon,
    steady_state
    )
    fig = Figure(resolution = (950, 600), fontsize=13)
    ax = Axis(
            fig[1,1],
            title = t,
            subtitle = st,
            xlabel = "Fecha",
            ylabel = yl,
            xgridvisible = false,
            ygridvisible = false
    )

    lines!(ax, df.date, df[:, var_name], label = "Historia")
    lines!(ax, df.date[end-horizon:end], df_ploting[end-horizon:end, var_name], label = "Pronostico")
    vlines!(
            ax,
            Dates.datetime2rata(df.date[end-horizon]), 
            linestyle = :dash,
            color = :black)

    hlines!(
            steady_state,
            color = (:grey, 0.5),
            label = "Estado Estacionario"
            )

    fig[2, 1] = Legend(
        fig,
        ax, 
        framevisible = false, 
        tellwidth = false,
        tellheight = true,
        haling = :left,
         orientation = :horizontal
        )

    Label(
    fig[3,1], 
    "Ejemplo con fines ilustrativos",
    halign=:left,
    tellwidth=false,
    fontsize=13,
    )

    fig

end




