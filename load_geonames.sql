/*
 geonameid         : integer id of record in geonames database
 name              : name of geographical point (utf8) varchar(200)
 asciiname         : name of geographical point in plain ascii characters, varchar(200)
 alternatenames    : alternatenames, comma separated, ascii names automatically transliterated, convenience attribute from alternatename table, varchar(10000)
 latitude          : latitude in decimal degrees (wgs84)
 longitude         : longitude in decimal degrees (wgs84)
 feature class     : see http://www.geonames.org/export/codes.html, char(1)
 feature code      : see http://www.geonames.org/export/codes.html, varchar(10)
 country code      : ISO-3166 2-letter country code, 2 characters
 cc2               : alternate country codes, comma separated, ISO-3166 2-letter country code, 200 characters
 admin1 code       : fipscode (subject to change to iso code), see exceptions below, see file admin1Codes.txt for display names of this code; varchar(20)
 admin2 code       : code for the second administrative division, a county in the US, see file admin2Codes.txt; varchar(80) 
 admin3 code       : code for third level administrative division, varchar(20)
 admin4 code       : code for fourth level administrative division, varchar(20)
 population        : bigint (8 byte int) 
 elevation         : in meters, integer
 dem               : digital elevation model, srtm3 or gtopo30, average elevation of 3''x3'' (ca 90mx90m) or 30''x30'' (ca 900mx900m) area in meters, integer. srtm processed by cgiar/ciat.
 timezone          : the iana timezone id (see file timeZone.txt) varchar(40)
 modification date : date of last modification in yyyy-MM-dd format
 */





-- This extension maps in delimited files as virtual tables. This means that you can load data
-- using SQL, filtering/joining with other tables without having to persist the entire dataset
-- to the database. This pattern of filtering and transforming data 'in flight' is very useful.
---- xref https://github.com/nalgeon/sqlean/blob/main/docs/vsv.md
.load vsv

-- see https://www.sqlite.org/spellfix1.html
.load spellfix

pragma pagesize = 32768;
PRAGMA foreign_keys = ON;

.timer ON
.echo OFF 

-- the column lists for the following virtual tables was copied from the descriptions 
-- on http://download.geonames.org/export/dump/
-- we map the main names collection, the hierarchy and the feature-codes enums table
CREATE VIRTUAL TABLE all_countries_vsv USING vsv(
    filename = "allCountries.txt",
    columns = 19,
    schema = "create table x (geonameid,name,asciiname,alternatenames,latitude,longitude,feature_class,feature_code,
    country_code,cc2,admin1_code,admin2_code,admin3_code,admin4_code,population,elevation,dem,timezone,modification_date)",
    affinity = numeric,
    fsep = "\t"
);
CREATE VIRTUAL TABLE hierarchy_vsv USING vsv(
    filename = "hierarchy.txt",
    columns = 3,
    schema = "create table x (parent_geoname_id, child_geoname_id, hierarchy_type)",
    affinity = integer,
    fsep = "\t"
);
CREATE VIRTUAL TABLE featureCodes_en_vsv USING vsv(
    filename = "featureCodes_en.txt",
    columns = 3,
    schema = "create table x (feature_code, name, description)",
    affinity = numeric,
    fsep = "\t"
);
create table geoname_feature_code (
    feature_class varchar NOT NULL,
    feature_code varchar primary key,
    name varchar not null,
    description varchar not null
);
insert into geoname_feature_code(
        feature_class,
        feature_code,
        [name],
        [description]
    )
select SUBSTRING(feature_code, 1, 1) as feature_class,
    SUBSTRING(feature_code, 3, LENGTH(feature_code) -2) as feature_code,
    [name],
    [description]
FROM featureCodes_en_vsv
where feature_code <> 'null';
CREATE TABLE geoname_adm (
    geoname_id integer primary key,
    name geoname not null,
    ascii_name geoname null,
    -- NOTE: for space optimization
    latitude float,
    longitude float,
    feature_class varchar,
    feature_code varchar REFERENCES geoname_feature_code(feature_code),
    country_code varchar,
    admin1_code varchar,
    admin2_code varchar,
    admin3_code varchar,
    admin4_code varchar,
    population integer,
    modification_date DATE
);
CREATE INDEX ix_country_code ON geoname_adm(country_code);
CREATE INDEX ix_feature_code on geoname_adm(feature_code);
CREATE INDEX ix_modification_date ON geoname_adm(modification_date);
-- not sure what the PK is on this table. 
-- we do not have any FK as we don't have a full geonames table
CREATE TABLE geoname_hierarchy(
    parent_geoname_id integer NOT NULL,
    child_geoname_id int NOT NULL,
    hierarchy_type varchar not null
);
INSERT INTO geoname_adm(
        geoname_id,
        [name],
        ascii_name,
        latitude,
        longitude,
        feature_class,
        feature_code,
        country_code,
        admin1_code,
        admin2_code,
        admin3_code,
        admin4_code,
        population,
        modification_date
    )
select geonameid as geoname_id,
    [name],
    asciiname as ascii_name,
    latitude,
    longitude,
    feature_class,
    feature_code,
    country_code,
    admin1_code,
    admin2_code,
    admin3_code,
    admin4_code,
    population,
    modification_date
FROM all_countries_vsv
where feature_class = 'A'
    and feature_code in ('ADM1', 'ADM2', 'ADM3', 'ADM4', 'PCLI', 'PCLIX');
-- optimization: zap asciiname if it is the same as name
update geoname_adm
set ascii_name = NULL
where ascii_name = name;

CREATE VIRTUAL TABLE geoname_alternate_name_vsv USING vsv(
    filename = "alternateNamesV2.txt",
    columns = 10,
    schema = "create table x (alternateNameId, geonameid, isolanguage,alternate_name,isPreferredName,
    isShortName,isColloquial,isHistoric,[from],[to])",
    affinity = numeric,
    fsep = "\t"
);
CREATE TABLE geoname_alternate_name(
    alternate_name_id int primary key,    --    : the id of this alternate name, int
    geoname_id int NOT NULL,--  : geonameId referring to id in table 'geoname', int
    iso_language varchar,    -- : iso 639 language code 2- or 3-characters; 4-characters 'post' for postal codes and 'iata','icao' and faac for airport codes, fr_1793 for French Revolution names,  abbr for abbreviation, link to a website (mostly to wikipedia), wkdt for the wikidataid, varchar(7)
    alternate_name varchar(400) NOT NULL,    --: alternate name or name variant, varchar(400)
    is_preferred_name varchar,    -- : '1', if this alternate name is an official/preferred name
    is_short_name varchar,  --   : '1', if this is a short name like 'California' for 'State of California'
    is_colloquial varchar,  --   : '1', if this alternate name is a colloquial or slang term. Example: 'Big Apple' for 'New York'.
    is_historic varchar,    --   : '1', if this alternate name is historic and was used in the past. Example 'Bombay' for 'Mumbai'.
    from_date date,         -- 	 : from period when the name was used
    to_date date            -- 	 : to period when the name was used
);
INSERT INTO geoname_alternate_name(
        alternate_name_id,
        geoname_id,
        iso_language,
        alternate_name,
        is_preferred_name,
        is_short_name,
        is_colloquial,
        is_historic,
        from_date,
        to_date
    )
select alternateNameId as alternate_name_id,
    geonameid as geoname_id,
    isolanguage as iso_language,
    alternate_name,
    isPreferredName as is_preferred_name,
    isShortName as is_short_name,
    isColloquial as is_colloquial,
    isHistoric as is_historic,
    [from] as from_date,
    [to] as to_date
FROM geoname_alternate_name_vsv as v
    JOIN geoname_adm as a ON (a.geoname_id = v.geonameid)
WHERE v.isolanguage IN ('en', 'post');
create index ix_geoname_id on geoname_alternate_name(geoname_id);
create index ix_alternate_name on geoname_alternate_name(alternate_name);
-- spellfix
-- fts
/*
 
 CREATE VIRTUAL TABLE geoname_fts 
 USING fts5(name, content='geoname_adm', content_rowid='geonameid');
 
 insert into geoname_fts(rowid, name) SELECT geonameid, name FROM geoname_adm;
 
 select fts.rowid, fts.name, fts.*, g.* 
 from geoname_fts as fts 
 JOIN geoname_adm as g 
 ON (fts.rowid=g.geonameid)
 where fts.name match 'roscommon' 
 and g.country_code = 'IE';
 */
/*
 select nums.n, d.* 
 FROM nums 
 CROSS JOIN 
 geoname_adm_dictionary as d
 ON (nums.n< 3) 
 WHERE  d.word match 'washington' 
 and d.langid=nums.n;
 */
create virtual table geoname_fts4 using fts4(geoname_id int, name text, country_code text);
insert into geoname_fts4(geoname_id, name, country_code)
SELECT geoname_id,
    name,
    country_code
FROM geoname_adm;

insert into geoname_fts4(geoname_id, name, country_code)
SELECT a.geoname_id,
    gan.alternate_name,
    a.country_code
FROM geoname_alternate_name as gan
    JOIN geoname_adm as a ON (gan.geoname_id = a.geoname_id);

select *
FROM geoname_fts4 as fts
    JOIN geoname_adm as a
     ON (fts.geoname_id = a.geoname_id)
where fts.name match 'sligo'
    and a.country_code = 'IE';


CREATE VIRTUAL TABLE geoname_fts4_terms USING fts4aux(geoname_fts4);
CREATE VIRTUAL TABLE geoname_fts4_spellfix USING spellfix1;
insert into geoname_fts4_spellfix(word)
select term
from geoname_fts4_terms
where col = '*';

WITH T AS (
    select word
    FROM geoname_fts4_spellfix
    where word match 'roscommon'
        and top = 5
)
SELECT *
FROM geoname_fts4 as fts
    JOIN geoname_adm as a ON (a.geoname_id = fts.geoname_id),
    T
where fts.name match T.word;


WITH T AS (select word FROM geoname_fts4_spellfix
 where word match 'vienna' and top=5
 ), 
 T1 AS (
     SELECT *
      FROM geoname_fts4 as fts
      JOIN geoname_adm as a
      ON (a.geoname_id = fts.geoname_id
      ), T 
    where fts.name match T.word and fts.country_code = 'AT'
    )
SELECT * FROM T1;
VACUUM;

-- now that the geonames data is in place, it is time to bring in the spatial boundaries
-- in geopoly format from sources such as geonames premium or from geoBoundaries.
-- if we are given a hierarchical toponym, we should be able to consistently resolve each level
-- of the the hierarchy and confirm that each child is spatially contained within its parent.
/*
 select  name,
 country_code,
 admin1_code,
 admin2_code,
 latitude,
 longitude 
 from geoname_adm 
 where feature_code = 'ADM2' 
 and country_code IN ('IE', 'GB');
 */