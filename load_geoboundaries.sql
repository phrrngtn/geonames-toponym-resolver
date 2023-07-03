
-- xref https://www.sqlite.org/geopoly.html#overview
-- xref https://www.geoboundaries.org/downloadCGAZ.html

-- convert the MultiPolygon to Polygon(using separate Python script) so that
-- we can use the simpler (than Spatialite) extension.

-- needs geopoly and readfile extensions. Use sqlean or build the extensions and load them
-- in at runtime or build them into a shell.

DROP TABLE IF EXISTS geopoly_boundary;

CREATE VIRTUAL TABLE geopoly_boundary USING geopoly(boundary_type,shape_group);


-- I don't know yet if there is any (non-spatial) indexing on geopoly tables
-- it may be the case that it makes more sense to load the boundaries into separate tables.

WITH T AS (
    select je.value -> '$.properties.shapeGroup'    as shape_group,
           je.value -> '$.geometry.type'            as geometry_type,
           je.value -> '$.geometry.coordinates[0]'  as b
      FROM json_each(readfile("geoBoundaries_CGAZ_ADM0_exploded_to_single_polygons.geojson"), '$.features') as je
)
INSERT INTO geopoly_boundary(boundary_type, shape_group, _shape)
    SELECT 'ADM0' as boundary_type, -- hardwired in
           shape_group,
           b as _shape
      FROM T
    Where shape_group is not null;

WITH T AS (
    select je.value -> '$.properties.shapeGroup'    as shape_group,
           je.value -> '$.geometry.type'            as geometry_type,
           je.value -> '$.geometry.coordinates[0]'  as b
      FROM json_each(readfile("geoBoundaries_CGAZ_ADM1_exploded_to_single_polygons.geojson"), '$.features') as je
)
INSERT INTO geopoly_boundary(boundary_type, shape_group, _shape)
    SELECT 'ADM1' as boundary_type,
           shape_group,
           b as _shape
      FROM T
    Where shape_group is not null;

WITH T AS (
    select je.value -> '$.properties.shapeGroup'    as shape_group,
           je.value -> '$.geometry.type'            as geometry_type,
           je.value -> '$.geometry.coordinates[0]'  as b
      FROM json_each(readfile("geoBoundaries_CGAZ_ADM2_exploded_to_single_polygons.geojson"), '$.features') as je
)
INSERT INTO geopoly_boundary(boundary_type, shape_group, _shape)
    SELECT 'ADM2' as boundary_type,
           shape_group,
           b as _shape
      FROM T
    Where shape_group is not null;