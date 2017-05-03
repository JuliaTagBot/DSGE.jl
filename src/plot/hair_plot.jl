using DSGE, Iterators, Plots

function hair_plot(var::Symbol, df::DataFrame,
                   histories::Vector{MeansBands}, forecasts::Vector{MeansBands};
                   output_file::AbstractString = "",
                   hist_label::AbstractString = "Realized",
                   forecast_label::AbstractString = "Forecasts",
                   forecast_palette::Symbol = Symbol(),
                   forecast_color::Colorant = RGBA(1., 0., 0., 1.))

    initial_values = map(history -> history.means[end, var], histories)
    hair_plot(var, df, initial_values, forecasts,
              output_file = output_file, hist_label = hist_label, forecast_label = forecast_label,
              forecast_palette = forecast_palette, forecast_color =forecast_color)
end

function hair_plot(var::Symbol, df::DataFrame,
                   initial_values::Vector{Float64}, forecasts::Vector{MeansBands};
                   output_file::AbstractString = "",
                   hist_label::AbstractString = "Realized",
                   forecast_label::AbstractString = "Forecasts",
                   forecast_palette::Symbol = Symbol(),
                   forecast_color::Colorant = RGBA(1., 0., 0., 1.))
    # Dates
    dates      = map(quarter_date_to_number, df[:date])
    start_date = ceil(dates[1] / 5) * 5
    end_date   = dates[end]
    date_ticks = start_date:5:end_date

    # Initialize GR backend
    gr()
    p = Plots.plot(xtick = date_ticks)

    # Plot realized (transformed) series
    plot!(p, dates, df[var], label = hist_label, linewidth = 2, linecolor = :black)

    # Plot each forecast
    for (initial_value, forecast) in zip(initial_values, forecasts)
        date_0 = DSGE.iterate_quarters(forecast.means[1, :date], -1)
        dates = vcat([date_0], forecast.means[:date])
        dates = map(quarter_date_to_number, dates)

        series = vcat([initial_value], forecast.means[var])

        label = forecast == forecasts[1] ? forecast_label : ""
        if forecast_palette == Symbol()
            plot!(p, dates, series, label = label, linewidth = 1, linecolor = forecast_color)
        else
            plot!(p, dates, series, label = label, linewidth = 1, palette = forecast_palette)
        end
    end

    # Save if `output_file` provided
    if !isempty(output_file)
        output_dir = dirname(output_file)
        !isdir(output_dir) && mkdir(output_dir)
        Plots.savefig(output_file)
        println("Saved $output_file")
    end

    return p
end