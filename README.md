# Coastal Flood Simulation Tool

A Julia-based flood simulation tool that uses Connected Morphological Flooding to predict coastal inundation based on tide levels, storm surge, and sea-level rise scenarios.

## Overview

This tool simulates flood extent for Portuguese coastal zones using Digital Elevation Model (DEM) data. It employs morphological reconstruction by erosion to identify areas that are hydrologically connected to the ocean and would flood under specified water level conditions.

## Requirements

- Julia (1.6 or higher recommended)
- Required packages:
  - Rasters
  - ArchGDAL
  - ImageMorphology
  - Statistics
  - Dates
  - GLMakie (optional, for visualization)

## Installation

Install dependencies using Julia's package manager:

```julia
using Pkg
Pkg.add(["Rasters", "ArchGDAL", "ImageMorphology", "Statistics", "Dates", "GLMakie"])
```

## Usage

1. Ensure you have a VRT file with DEM data (e.g., `portugal_coast_wgs84.vrt`)
2. Run the simulation:

```bash
julia simul_flood.jl
```

The script uses default parameters for the Espinho region with example scenario:
- Tide: 3.8m (Hydrographic Zero)
- Storm surge: 0.6m
- Sea-level rise: 1.13m

## Output

The simulation generates a GeoTIFF file (`espinho_flood_result.tif`) that can be opened in QGIS, ArcGIS, or other GIS software. The raster contains:
- 1 = Flooded areas
- 0 = Dry areas

## Key Features

- **Datum conversion**: Automatically converts between Hydrographic Zero (ZH) and DGT Datum (Cascais 1938)
- **Connected flooding**: Only simulates flooding in areas connected to the ocean, preventing isolated inland depressions from filling
- **Customizable scenarios**: Modify tide, surge, and SLR parameters for different scenarios
- **Spatial subsetting**: Define custom bounding boxes to focus on specific coastal areas

## Documentation

See [CLAUDE.md](CLAUDE.md) for detailed architecture information and development guidance.
