# Intersect catchment with SOILGRIDS soil classes
# Counts the occurence of each soil class in each HRU in the model setup with rasterstats.

# modules
import os
from pathlib import Path
from shutil import copyfile
from datetime import datetime
import geopandas as gpd
import pandas as pd
import numpy as np
from exactextract import exact_extract


# --- Control file handling
# Easy access to control file folder
controlFolder = Path('../../0_control_files')

# Store the name of the 'active' file in a variable
controlFile = 'control_active.txt'

# Function to extract a given setting from the control file
def read_from_control( file, setting ):
    
    # Open 'control_active.txt' and ...
    with open(file) as contents:
        for line in contents:
            
            # ... find the line with the requested setting
            if setting in line and not line.startswith('#'):
                break
    
    # Extract the setting's value
    substring = line.split('|',1)[1]      # Remove the setting's name (split into 2 based on '|', keep only 2nd part)
    substring = substring.split('#',1)[0] # Remove comments, does nothing if no '#' is found
    substring = substring.strip()         # Remove leading and trailing whitespace, tabs, newlines
       
    # Return this value    
    return substring
    
# Function to specify a default path
def make_default_path(suffix):
    
    # Get the root path
    rootPath = Path( read_from_control(controlFolder/controlFile,'root_path') )
    
    # Get the domain folder
    domainName = read_from_control(controlFolder/controlFile,'domain_name')
    domainFolder = 'domain_' + domainName
    
    # Specify the forcing path
    defaultPath = rootPath / domainFolder / suffix
    
    return defaultPath
    
    
# --- Find location of shapefile and soil class .tif
# Catchment shapefile path & name
catchment_path = read_from_control(controlFolder/controlFile,'catchment_shp_path')
catchment_name = read_from_control(controlFolder/controlFile,'catchment_shp_name')

# Specify default path if needed
if catchment_path == 'default':
    catchment_path = make_default_path('shapefiles/catchment') # outputs a Path()
else:
    catchment_path = Path(catchment_path) # make sure a user-specified path is a Path()
    
# Forcing shapefile path & name
soil_path = read_from_control(controlFolder/controlFile,'parameter_soil_domain_path')
soil_name = read_from_control(controlFolder/controlFile,'parameter_soil_tif_name')

# Specify default path if needed
if soil_path == 'default':
    soil_path = make_default_path('parameters/soilclass/2_soil_classes_domain') # outputs a Path()
else:
    soil_path = Path(soil_path) # make sure a user-specified path is a Path()
    
    
# --- Find where the intersection needs to go
# Intersected shapefile path and name
intersect_path = read_from_control(controlFolder/controlFile,'intersect_soil_path')
intersect_name = read_from_control(controlFolder/controlFile,'intersect_soil_name')

# Specify default path if needed
if intersect_path == 'default':
    intersect_path = make_default_path('shapefiles/catchment_intersection/with_soilgrids') # outputs a Path()
else:
    intersect_path = Path(intersect_path) # make sure a user-specified path is a Path()
    
# Make the folder if it doesn't exist
intersect_path.mkdir(parents=True, exist_ok=True)


# --- Rasterstats analysis
# Load the shapefile
gdf = gpd.read_file(catchment_path / catchment_name)
raster_path = soil_path / soil_name

# Perform exactextract with fractional coverage per class
stats = exact_extract(
    str(raster_path),
    gdf,
    ["unique", "frac"],
    output='pandas'
)

# Build a list of row-wise dicts: {soil_class: fraction}
rows = []
for i, (classes, fractions) in stats.iterrows():
    row_dict = {k: v for k, v in zip(classes, fractions)}
    rows.append(row_dict)

# Convert to DataFrame
df_stats = pd.DataFrame(rows)

# Replace NaN with 0, ensure float type
df_stats = df_stats.fillna(0).astype(float)

# Sort columns numerically
sorted_columns = sorted(df_stats.columns, key=lambda x: int(x))
df_stats = df_stats[sorted_columns]

# Round to 4 digit
df_stats = df_stats.round(4)

# Rename columns to USGS soil class format
df_stats.columns = [f'USGS_{int(col)}' for col in df_stats.columns]

# Merge with original GeoDataFrame
result = gdf.join(df_stats)

# Save the result
result.to_file(intersect_path / intersect_name)


# --- Code provenance
# Generates a basic log file in the domain folder and copies the control file and itself there.

# Set the log path and file name
logPath = intersect_path
log_suffix = '_catchment_soilgrids_intersect_log.txt'

# Create a log folder
logFolder = '_workflow_log'
Path( logPath / logFolder ).mkdir(parents=True, exist_ok=True)

# Copy this script
thisFile = '2_find_HRU_soil_classes.py'
copyfile(thisFile, logPath / logFolder / thisFile);

# Get current date and time
now = datetime.now()

# Create a log file 
logFile = now.strftime('%Y%m%d') + log_suffix
with open( logPath / logFolder / logFile, 'w') as file:
    
    lines = ['Log generated by ' + thisFile + ' on ' + now.strftime('%Y/%m/%d %H:%M:%S') + '\n',
             'Counted the occurrence of soil classes within each HRU.']
    for txt in lines:
        file.write(txt)  