
-- xref https://www.sqlite.org/geopoly.html#overview
-- xref https://www.geoboundaries.org/downloadCGAZ.html

-- convert the MultiPolygon to Polygon(using separate Python script) so that
-- we can use the simpler (than Spatialite) extension.

-- needs geopoly and readfile extensions. Use sqlean or build the extensions and load them
-- in at runtime or build them into a shell.

DROP TABLE IF EXISTS geopoly_boundary_adm0;
DROP TABLE IF EXISTS geopoly_boundary_adm1;
DROP TABLE IF EXISTS geopoly_boundary_adm2;


CREATE VIRTUAL TABLE geopoly_boundary_adm0 USING geopoly(boundary_type,adm0);
CREATE VIRTUAL TABLE geopoly_boundary_adm1 USING geopoly(boundary_type, adm0, adm1);
CREATE VIRTUAL TABLE geopoly_boundary_adm2 USING geopoly(boundary_type, adm0, adm1, adm2);

-- I don't know yet if there is any (non-spatial) indexing on geopoly tables
-- it may be the case that it makes more sense to load the boundaries into separate tables.
-- Update: yes, it seems that having separate tables leads to much better performance.

WITH T AS (
    select je.value ->> '$.properties.shapeGroup'    as shape_group,
           je.value ->> '$.geometry.shapeType'       as boundary_type,
           je.value -> '$.geometry.coordinates[0]'  as b
      FROM json_each(readfile("geoBoundaries_CGAZ_ADM0_exploded_to_single_polygons.geojson"), '$.features') as je
)
INSERT INTO geopoly_boundary_adm0(boundary_type, adm0, _shape)
    SELECT boundary_type,
           shape_group as adm0,
           b as _shape
      FROM T
    Where shape_group is not null;

WITH T AS (
    select je.value ->> '$.properties.shapeGroup'    as shape_group,
           je.value ->> '$.properties.shapeName'     as shape_name,
           je.value ->> '$.geometry.type'            as boundary_type,
           je.value -> '$.geometry.coordinates[0]'  as b
      FROM json_each(readfile("geoBoundaries_CGAZ_ADM1_exploded_to_single_polygons.geojson"), '$.features') as je
)
INSERT INTO geopoly_boundary_adm1(boundary_type, adm0, adm1, _shape)
    SELECT boundary_type,
           shape_group as adm0,
           shape_name as adm1,
           b as _shape
      FROM T
    Where shape_group is not null;

WITH T AS (
    select je.value ->> '$.properties.shapeGroup'    as shape_group,
           je.value ->> '$.properties.shapeName'     as shape_name,
           je.value ->> '$.geometry.type'            as boundary_type,
           je.value -> '$.geometry.coordinates[0]'  as b
      FROM json_each(readfile("geoBoundaries_CGAZ_ADM2_exploded_to_single_polygons.geojson"), '$.features') as je
)
INSERT INTO geopoly_boundary_adm2(boundary_type, adm0, adm1, adm2, _shape)
    SELECT boundary_type,
           shape_group as adm0,
           NULL        as adm1,
           shape_name  as adm2,
           b as _shape
      FROM T
    Where shape_group is not null;
