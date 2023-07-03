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



-- use sqlean as the shell as it is 'batteries included' and has a bunch of useful stuff
-- bundled directly.

-- TODO: see if we can use fts5 rather than fts4... can't remember why I chose one over the other.

-- This extension maps in delimited files as virtual tables. This means that you can load data
-- using SQL, filtering/joining with other tables without having to persist the entire dataset
-- to the database. This pattern of filtering and transforming data 'in flight' is very useful.
---- xref https://github.com/nalgeon/sqlean/blob/main/docs/vsv.md
--.load vsv

-- see https://www.sqlite.org/spellfix1.html

.load spellfix


pragma pagesize = 32768;
PRAGMA foreign_keys = ON;

.timer ON
.echo OFF

-- the column lists for the following virtual tables was copied from the descriptions 
-- on http://download.geonames.org/export/dump/
-- we map the main names collection, the hierarchy and the feature-codes enums table
CREATE VIRTUAL TABLE geoname_all_countries_vsv USING vsv
(
    filename = "allCountries.txt",
    columns = 19,
    schema = "create table x (geonameid,name,asciiname,alternatenames,latitude,longitude,feature_class,feature_code,
    country_code,cc2,admin1_code,admin2_code,admin3_code,admin4_code,population,elevation,dem,timezone,modification_date)",
    affinity = none,
    nulls=off,
    fsep = "\t"
);


/*

country code      : iso country code, 2 characters
postal code       : varchar(20)
place name        : varchar(180)
admin name1       : 1. order subdivision (state) varchar(100)
admin code1       : 1. order subdivision (state) varchar(20)
admin name2       : 2. order subdivision (county/province) varchar(100)
admin code2       : 2. order subdivision (county/province) varchar(20)
admin name3       : 3. order subdivision (community) varchar(100)
admin code3       : 3. order subdivision (community) varchar(20)
latitude          : estimated latitude (wgs84)
longitude         : estimated longitude (wgs84)
accuracy          : accuracy of lat/lng from 1=estimated, 4=geonameid, 6=centroid of addresses or shape
*/
CREATE VIRTUAL TABLE geonames_all_countries_postal_codes_vsv USING vsv
(
    filename = "all_countries_postal_codes.txt", -- note this is our naming
    columns = 12,
    schema = "create table x (country_code,postal_code,place_name,admin_name1,admin_code1,admin_name2, admin_code2,admin_name3, admin_code3,latitude, longitude,accuracy)",
    affinity = none, -- want to get leading zeros in zipcodes, FIPS and stuff like that.
    nulls=off,
    fsep = "\t"
);


-- TODO: add (redundant) nullable FK columns for country, admin1, admin2, admin3
CREATE TABLE geoname_postal_code (
    country_code varchar(2) NOT NULL,
    postal_code varchar NOT NULL,
    place_name varchar,
    admin1_name, -- note that naming convention change wrt to the column names of the text file
    admin1_code,
    admin2_name,
    admin2_code,
    admin3_name,
    admin3_code,
    latitude FLOAT,
    longitude FLOAT,
    accuracy INTEGER
    );

INSERT INTO geoname_postal_code(
        country_code,
        postal_code,
        place_name,
        admin1_name,
        admin1_code,
        admin2_name,
        admin2_code,
        admin3_name,
        admin3_code,
        latitude,
        longitude,
        accuracy
        )
SELECT country_code,
    postal_code,
    place_name,
    admin_name1 as admin1_name,
    admin_code1 as admin1_code,
    admin_name2 as admin2_name,
    admin_code2 as admin2_code,
    admin_name3 as admin3_name,
    admin_code3 as admin3_code,
    CAST(latitude as float) as latitude,
    CAST(longitude as float) as longitude,
    CAST(accuracy as integer) as accuracy
FROM geonames_all_countries_postal_codes_vsv;


CREATE INDEX ix_postal_code ON geoname_postal_code(postal_code);
CREATE INDEX ix_country_code_geoname_postal_code ON geoname_postal_code(country_code);

CREATE VIRTUAL TABLE geoname_hierarchy_vsv USING vsv
(
    filename = "hierarchy.txt",
    columns = 3,
    schema = "create table x (parent_geoname_id, child_geoname_id, hierarchy_type)",
    affinity = integer,
    fsep = "\t"
);
CREATE VIRTUAL TABLE featureCodes_en_vsv USING vsv
(
    filename = "featureCodes_en.txt",
    columns = 3,
    schema = "create table x (feature_code, name, description)",
    affinity = none,
    fsep = "\t"
);
create table geoname_feature_code
(
    feature_class varchar NOT NULL,
    feature_code varchar primary key,
    name varchar not null,
    description varchar not null
);
insert into geoname_feature_code
    (
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


-- TODO: add nullable FK to parent, maybe for admin[1-4]
CREATE TABLE geoname_adm
(
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
    dem varchar,
    elevation float,
    modification_date DATE
);
CREATE INDEX ix_country_code ON geoname_adm(country_code);
CREATE INDEX ix_feature_code on geoname_adm(feature_code);
CREATE INDEX ix_modification_date ON geoname_adm(modification_date);
-- not sure what the PK is on this table. 
-- we do not have any FK as we don't have a full geonames table
CREATE TABLE geoname_hierarchy
(
    parent_geoname_id integer NOT NULL,
    child_geoname_id int NOT NULL,
    hierarchy_type varchar not null
);

INSERT INTO geoname_hierarchy(parent_geoname_id, child_geoname_id, hierarchy_type)
SELECT parent_geoname_id, child_geoname_id, hierarchy_type
FROM geoname_hierarchy_vsv;

INSERT INTO geoname_adm
    (
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
    dem,
    elevation,
    modification_date
    )
select geonameid as geoname_id,
    [name],
    asciiname as ascii_name,
    CAST(latitude as float) as latitude,
    CAST(longitude as float) as longitude,
    feature_class,
    feature_code,
    country_code,
    admin1_code,
    admin2_code,
    admin3_code,
    admin4_code,
    CAST(population as numeric) as population,
    dem,
    elevation,
    modification_date
FROM geoname_all_countries_vsv
where feature_class = 'A'
    and feature_code in ('ADM1', 'ADM2', 'ADM3', 'ADM4', 'PCLI', 'PCLIX');
-- optimization: zap asciiname if it is the same as name
update geoname_adm
set ascii_name = NULL
where ascii_name = name;

CREATE VIRTUAL TABLE geoname_alternate_name_vsv USING vsv
(
    filename = "alternateNamesV2.txt",
    columns = 10,
    schema = "create table x (alternateNameId, geonameid, isolanguage,alternate_name,isPreferredName,
    isShortName,isColloquial,isHistoric,[from],[to])",
    affinity = numeric,
    fsep = "\t"
);
CREATE TABLE geoname_alternate_name
(
    alternate_name_id int primary key,
    --    : the id of this alternate name, int
    geoname_id int NOT NULL,--  : geonameId referring to id in table 'geoname', int
    iso_language varchar,
    -- : iso 639 language code 2- or 3-characters; 4-characters 'post' for postal codes and 'iata','icao' and faac for airport codes, fr_1793 for French Revolution names,  abbr for abbreviation, link to a website (mostly to wikipedia), wkdt for the wikidataid, varchar(7)
    alternate_name varchar(400) NOT NULL,
    --: alternate name or name variant, varchar(400)
    is_preferred_name varchar,
    -- : '1', if this alternate name is an official/preferred name
    is_short_name varchar,
    --   : '1', if this is a short name like 'California' for 'State of California'
    is_colloquial varchar,
    --   : '1', if this alternate name is a colloquial or slang term. Example: 'Big Apple' for 'New York'.
    is_historic varchar,
    --   : '1', if this alternate name is historic and was used in the past. Example 'Bombay' for 'Mumbai'.
    from_date date,
    -- 	 : from period when the name was used
    to_date date
    -- 	 : to period when the name was used
);
INSERT INTO geoname_alternate_name
    (
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
    geonameid       as geoname_id,
    isolanguage     as iso_language,
    alternate_name,
    isPreferredName as is_preferred_name,
    isShortName     as is_short_name,
    isColloquial    as is_colloquial,
    isHistoric      as is_historic,
    [from]          as from_date,
    [to]            as to_date
FROM geoname_alternate_name_vsv as v
    JOIN geoname_adm as a ON (a.geoname_id = v.geonameid)
WHERE v.isolanguage IN (
        'en',-- English
        'post', -- 'post' for postal codes
        'abbr', -- abbreviation
        'iata', 'icao', 'faac' --  'iata','icao' and faac for airport codes
        );
CREATE INDEX ix_geoname_id on geoname_alternate_name(geoname_id);
create index ix_alternate_name on geoname_alternate_name(alternate_name);
-- spellfix
-- fts


CREATE TABLE geoname_symbol(
     geoname_id integer NOT NULL references geoname_adm(geoname_id),
     symbol varchar not null,
     symbol_type varchar not null,
     country_code varchar NULL,
     PRIMARY KEY (geoname_id, symbol, symbol_type)
    );




WITH SYMS AS (
select geoname_id,
       COALESCE(ascii_name, name) as symbol,
       feature_code as symbol_type,
       country_code as country_code
from geoname_adm
where feature_code IN ('PCLI', 'ADM1', 'ADM2', 'ADM3', 'ADM4')
UNION ALL
select geoname_id,
    CASE feature_code
        WHEN 'PCLI' THEN country_code
        WHEN 'ADM1' THEN admin1_code
        WHEN 'ADM2' THEN admin2_code
        WHEN 'ADM3' THEN admin3_code
        WHEN 'ADM4' THEN admin4_code
        ELSE NULL
        END as symbol,
    CASE feature_code
        WHEN 'PCLI' THEN 'PCLI_CODE'
        WHEN 'ADM1' THEN 'ADM1_CODE'
        WHEN 'ADM2' THEN 'ADM2_CODE'
        WHEN 'ADM3' THEN 'ADM3_CODE'
        WHEN 'ADM4' THEN 'ADM4_CODE'
        ELSE NULL
        END as symbol_type,
    country_code
    FROM geoname_adm
where feature_code IN ('PCLI', 'ADM1', 'ADM2', 'ADM3', 'ADM4')
)
INSERT INTO geoname_symbol(geoname_id,symbol, symbol_type, country_code)
SELECT geoname_id, symbol, symbol_type, country_code
FROM SYMS
WHERE SYMS.symbol is not null and SYMS.symbol <> '';


 INSERT OR IGNORE INTO geoname_symbol(geoname_id, symbol, symbol_type, country_code)
 select gan.geoname_id,
        gan.alternate_name as symbol,
        CASE gan.iso_language
            WHEN 'en'
                THEN gn.feature_code
            ELSE
                gan.iso_language
        END as symbol_type,
        gn.country_code
 FROM geoname_alternate_name as gan
 JOIN geoname_adm as gn
 ON (gan.geoname_id = gn.geoname_id)
 WHERE gan.iso_language IN (
        'en',-- English
        'post', -- 'post' for postal codes
        'abbr',
        'iata', 'icao', 'faac' --  'iata','icao' and 'faac' for airport codes
        );

CREATE INDEX ix_geoname_symbol ON geoname_symbol(symbol, symbol_type);
CREATE INDEX ix_geoname_symbol_country_code ON geoname_symbol(symbol_type, country_code);

 CREATE VIRTUAL TABLE geoname_fts  USING fts5(name, geoname_id UNINDEXED, feature_code UNINDEXED, country_code UNINDEXED);

insert into geoname_fts(geoname_id, name, feature_code, country_code)
SELECT geoname_id,
       symbol as name,
       symbol_type as feature_code,
       country_code
FROM geoname_symbol;



 select fts.geoname_id, fts.name, fts.*, g.*
 from geoname_fts as fts
 JOIN geoname_adm as g
 ON (fts.geoname_id=g.geoname_id)
 where fts.name match 'roscommon'
 and fts.country_code = 'IE';


create table geoname_symbol_type_spellfix_langid  (
    symbol_type PRIMARY KEY,
    langid int not null
);

WITH AGG AS (
    select symbol_type, COUNT(*) as n
    FROM geoname_symbol
    group by  symbol_type
    ), RNK AS (
    SELECT symbol_type,
    ROW_NUMBER() OVER (ORDER BY n DESC) as rn
    FROM AGG
    )
INSERT INTO geoname_symbol_type_spellfix_langid(symbol_type, langid)
select symbol_type, rn
FROM RNK;


CREATE VIRTUAL TABLE geoname_symbol_spellfix USING spellfix1;

INSERT INTO geoname_symbol_spellfix(word, langid)
select sym.symbol as word,
       lang.langid
FROM geoname_symbol as sym
LEFT OUTER JOIN geoname_symbol_type_spellfix_langid as lang
 ON (sym.symbol_type = lang.symbol_type);



CREATE VIRTUAL TABLE geoname_fts_vocab USING fts5vocab(geoname_fts, row);

WITH
    T
    AS
    (
        select word
        FROM geoname_fts_spellfix
        where word
     match 'roscommon'
        and top = 5
)
SELECT *
FROM geoname_fts as fts
    JOIN geoname_adm as a ON (a.geoname_id = fts.geoname_id),
    T
where fts.name
match T.word;


WITH
    T
    AS
    (
        select word
        FROM geoname_fts_spellfix
        where word
     match 'vienna' and top=5
 ),
 T1 AS
(
     SELECT *
FROM geoname_fts as fts
    JOIN geoname_adm as a
    ON (a.geoname_id = fts.geoname_id),
     T
where fts.name
match T.word and a.country_code = 'AT'
    )
SELECT *
FROM T1;

select * FROM geoname_adm where feature_code = 'ADM2' and country_code = 'US' and admin1_code = 'MA';

select gpc.*, adm1.name as admin1_name, adm1.admin1_code, adm2.name as admin2_name, adm2.admin2_code
FROM geoname_postal_code as gpc
LEFT OUTER JOIN geoname_adm as adm1
ON (gpc.country_code = adm1.country_code and adm1.feature_code = 'ADM1' and gpc.admin1_code = adm1.admin1_code) LEFT OUTER JOIN geoname_adm as adm2
ON (adm2.feature_code = 'ADM2'
and adm1.admin1_code = adm2.admin1_code
and adm2.admin2_code=gpc.admin2_code
and adm2.country_code = gpc.country_code)
 where gpc.postal_code = '02458';

VACUUM;

-- now that the geonames data is in place, it is time to bring in the spatial boundaries
-- in geopoly format from sources such as geonames premium or from geoBoundaries.
-- if we are given a hierarchical toponym, we should be able to consistently resolve each level
-- of the the hierarchy and confirm that each child is spatially contained within its parent.
