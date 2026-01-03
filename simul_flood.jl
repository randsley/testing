using Rasters
using ArchGDAL
using ImageMorphology
using Statistics
using Dates

"""
    run_simulation_on_vrt(vrt_path, tide_zh, surge, slr, bounds)

Runs a flood simulation based on Connected Morphological Flooding.
"""
function run_simulation_on_vrt(vrt_path::String, tide_zh::Float64, surge::Float64, slr::Float64, bounds::Tuple)
    # --- 1. PARAMETERS ---
    # DGT Datum (Cascais 1938) vs Hydrographic Zero (ZH)
    # Offset is -2.00m for Viana/Aveiro coastal zone
    DATUM_OFFSET = 2.00
    
    total_water_level = tide_zh + surge + slr
    flood_threshold = total_water_level - DATUM_OFFSET
    
    println("Simulating TWL: $(round(total_water_level, digits=2))m (ZH) -> Threshold: $(round(flood_threshold, digits=2))m (NMM)")

    # --- 2. LOAD & CLIP DATA ---
    # bounds tuple in Julia: (min_lon, min_lat, max_lon, max_lat)
    min_lon, min_lat, max_lon, max_lat = bounds

    println("Loading and clipping raster...")
    
    # Load VRT lazily
    # X corresponds to Longitude, Y to Latitude
    rast = Raster(vrt_path; lazy=true)
    
    # Clip the raster using standard Julia indexing with Selectors
    # We use 'Between' to crop the area of interest
    dem_clip = rast[X(Between(min_lon, max_lon)), Y(Between(min_lat, max_lat))]
    
    # Read into memory (materialize the array)
    # This results in a 3D array (X, Y, Band), usually Band 1
    dem_array = read(dem_clip)
    
    # If there are multiple bands, take the first one
    if hasdim(dem_array, Band)
        dem_array = view(dem_array, Band(1))
    end

    # --- 3. HANDLE NODATA ---
    # Rasters.jl handles missing values automatically, but ImageMorphology needs clean floats
    nodata_marker = 9999.0
    
    # Create a clean Float64 array for calculation
    # Replace 'missing' and extreme negative values with a high wall (9999)
    dem_calc = map(x -> (ismissing(x) || x < -100) ? nodata_marker : Float64(x), dem_array)

    # --- 4. CONNECTED FLOODING ---
    println("Calculating hydrological connectivity...")

    # Seed logic:
    # 1. Create a copy of the DEM
    seed = copy(dem_calc)
    
    # 2. Set the "interior" of the seed to the Maximum value (infinite wall)
    # Note: Julia uses 1-based indexing. 
    # Python [1:-1, 1:-1] is Julia [2:end-1, 2:end-1]
    max_val = maximum(skipmissing(dem_calc))
    seed[2:end-1, 2:end-1] .= max_val
    
    # 3. Apply Threshold Logic for Seed
    # If DEM < threshold (potential flood zone), keep Seed as MAX (so it can be eroded down)
    # If DEM >= threshold (land), Seed becomes DEM
    # This sets up the 'Reconstruction by Erosion' constraint: Marker (seed) >= Mask (dem)
    seed = map((s, d) -> d < flood_threshold ? s : d, seed, dem_calc)

    # 4. Run Morphological Reconstruction (Erosion)
    # We want to erode the 'seed' (high water) down to the 'dem_calc' level, 
    # but only where connected to the edges.
    flooded_surface = reconstruct(min, seed, dem_calc)
    
    # Create Binary Mask
    # Areas where the reconstructed surface is lower than water level
    flood_mask = flooded_surface .< flood_threshold

    # --- 5. STATISTICS ---
    # Calculate pixel area. Rasters.jl knows the step size.
    # dims(dem_array) returns (X, Y) with steps.
    x_step = step(dims(dem_array, X))
    y_step = step(dims(dem_array, Y))
    pixel_area_deg = abs(x_step * y_step)
    
    flooded_pixels = count(flood_mask)
    flooded_area = flooded_pixels * pixel_area_deg
    
    println("Flooded pixels: $(flooded_pixels)")
    println("Approximate flooded area: $(round(flooded_area, digits=6)) deg²")

    # --- 6. EXPORT ---
    # We return the Raster object with the geometry attached
    # masking the result (1 for flood, missing for dry)
    result_raster = rebuild(dem_clip, flood_mask)
    
    return result_raster
end

# --- EXAMPLE USAGE ---
if abspath(PROGRAM_FILE) == @__FILE__
    
    # Espinho Bounds (Lon Min, Lat Min, Lon Max, Lat Max)
    espinho_bounds = (-8.70, 40.95, -8.60, 41.03)

    # NOTE: Ensure 'portugal_coast_wgs84.vrt' exists or change path
    vrt_file = "portugal_coast_wgs84.vrt"
    
    if isfile(vrt_file)
        result = run_simulation_on_vrt(
            vrt_file, 
            3.8,   # Tide ZH
            0.6,   # Surge
            1.13,  # SLR
            espinho_bounds
        )
        
        # Save as GeoTIFF (Standard GIS output)
        output_file = "espinho_flood_result.tif"
        
        # Convert Bool mask to UInt8 (1=Flooded, 0=Dry) for saving
        save_raster = map(x -> x ? UInt8(1) : UInt8(0), result)
        
        write(output_file, save_raster)
        println("\nSimulation complete. Result saved to: $output_file")
        println("You can open this .tif file in QGIS, ArcGIS, or plot using GLMakie.")
        
    else
        println("Error: VRT file '$vrt_file' not found.")
    end
end

# Optional: Interactive Visualization
using GLMakie

# Function to plot
function plot_results(raster_mask)
    # Convert Raster to standard Matrix for plotting
    data = Matrix(raster_mask)
    
    # Handle coordinates
    lons = lookup(raster_mask, X)
    lats = lookup(raster_mask, Y)
    
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1], title="Flood Extent (Espinho)", xlabel="Longitude", ylabel="Latitude")
    
    # Plot heatmap (Blue for flood, transparent/white for empty)
    # We use a colormap where 0 is transparent, 1 is blue
    hm = heatmap!(ax, lons, lats, data, colormap=[:transparent, :blue])
    
    Colorbar(fig[1, 2], hm, label="Flooded")
    display(fig)
end

# plot_results(result) # Call this after running simulation