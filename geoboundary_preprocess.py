import geopandas as gpd
import io
from fiona.io import ZipMemoryFile

# it is a pain in the neck to process MultiPolygons in SQLite and it seems
# much easier (for our purposes) to just use Polygons.

# this is some test/developer code to explode the geoBoundaries files (using geopandas)
# and convert to GeoJSON (as it is quite easy to convert GeoJSON *Polygons* to GeoPoly)


def convert_zipped_shapefile_to_geopandas(zipped_shapefile):
    # https://gis.stackexchange.com/a/383473/37584
    zipshp = io.BytesIO(open(zipped_shapefile, "rb").read())

    with (ZipMemoryFile(zipshp)) as memfile:
        with memfile.open() as src:
            crs = src.crs
            gdf = gpd.GeoDataFrame.from_features(src, crs=crs)
    return gdf


# got these from https://www.geoboundaries.org/downloadCGAZ.html
# geoBoundariesCGAZ_ADM0.zip
# geoBoundariesCGAZ_ADM1.zip
#

# this runs pretty slowly. not sure where the bottleneck is.
# https://stackoverflow.com/a/68922148/40387
gdf = convert_zipped_shapefile_to_geopandas("geoBoundariesCGAZ_ADM0.zip")
gdf.explode().to_file(
    "geoBoundaries_CGAZ_ADM0_exploded_to_single_polygons.geojson", driver="GeoJSON"
)

gdf = convert_zipped_shapefile_to_geopandas("geoBoundariesCGAZ_ADM1.zip")
gdf.explode().to_file(
    "geoBoundaries_CGAZ_ADM1_exploded_to_single_polygons.geojson", driver="GeoJSON"
)

gdf = convert_zipped_shapefile_to_geopandas("geoBoundariesCGAZ_ADM2.zip")
gdf.explode().to_file(
    "geoBoundaries_CGAZ_ADM2_exploded_to_single_polygons.geojson", driver="GeoJSON"
)
