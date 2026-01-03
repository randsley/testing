# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Julia-based coastal flood simulation tool that uses Connected Morphological Flooding to predict inundation areas based on tidal elevation, storm surge, and sea-level rise scenarios.

## Running the Simulation

Run the main simulation script:
```bash
julia simul_flood.jl
```

The script expects a VRT file named `portugal_coast_wgs84.vrt` in the working directory. It will output a GeoTIFF file (`espinho_flood_result.tif`) showing flood extent.

## Dependencies

Required Julia packages (installed via Julia package manager):
- Rasters
- ArchGDAL
- ImageMorphology
- Statistics
- Dates
- GLMakie (optional, for visualization)

Install dependencies:
```julia
using Pkg
Pkg.add(["Rasters", "ArchGDAL", "ImageMorphology", "Statistics", "Dates", "GLMakie"])
```

## Architecture

### Core Algorithm (simul_flood.jl:12-101)

The flood simulation uses morphological reconstruction by erosion to identify hydrologically connected flood zones:

1. **Water Level Calculation**: Combines tide (ZH), surge, and SLR, then converts from Hydrographic Zero to DGT Datum (Cascais 1938) using a -2.00m offset for the Viana/Aveiro coastal zone.

2. **DEM Processing**: Loads and clips a VRT raster to the area of interest (bounding box in WGS84 coordinates). NoData values are replaced with a high wall marker (9999.0).

3. **Connected Flooding Algorithm**:
   - Creates a "seed" array initialized to maximum DEM values
   - Sets interior cells to maximum (creates a border-only seed)
   - Where DEM < threshold, seed remains high; where DEM >= threshold, seed = DEM
   - Applies morphological reconstruction (erosion) to erode the seed down to DEM level
   - Only areas connected to the border (ocean) will flood

4. **Output**: Returns a boolean raster (1=flooded, 0=dry) with spatial metadata preserved.

### Key Parameters

- **DATUM_OFFSET** (simul_flood.jl:16): 2.00m offset between DGT Datum and Hydrographic Zero for Viana/Aveiro
- **Default bounds** (simul_flood.jl:107): Espinho region (-8.70, 40.95, -8.60, 41.03)
- **Example scenario** (simul_flood.jl:113-118): 3.8m tide + 0.6m surge + 1.13m SLR

### Visualization

Optional interactive plotting with GLMakie (simul_flood.jl:137-159). Uncomment the final line to display results after simulation.
