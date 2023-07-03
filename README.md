# geonames-toponym-resolver
Experiments with named entity recognition for hierarchical placenames (toponyms)


Given a table of symbols, n columns wide and m columns tall, assume that each of the n columns contain a geoname ascii name and that on a given row, we have a 'leaf' column 
and a 'root' column and 'path' columns e.g. in this table, c1 is a town, c2 is a state and c3 is a country. 

It is assumes that all values in column c1 have the same feature-code;  all values in c2 have the same feature-code and will either be an ancestor
or descendant of c1 ... all the way up to cn. 

The UI for this will be an Excel spreadsheet where we can augment an input table with derived/looked up values. 
Take a look at https://openrefine.org/ for inspiration

Questions:
> Scope of the task and how extensive the geonames dataset is: Are the ascii names from the input table always going to be contained in the data
> in some shape or form? And then we would be more trying to match those with the likeliest geonames feature-codes/id given the context from the entire input row?

Yes, we should use the hierarchical information 
> You mentioned that there are research papers that could be relevant. I found a few regarding toponym resolution specifically using GeoNames
> but was wondering if you had any that you think might be important to read.
> 
xref http://www.cs.umd.edu/~hjs/pubs/gis13-demo-header.pdf

> In the hierarchy.zip file, what does the third column represent? I assume it is the feature codes but didn't see a readme or an exact match
> (entries like amt, tourism, etc.) in the list of featurecodes

From the geonames docs at  https://download.geonames.org/export/dump/

> hierarchy.zip		: parentId, childId, type. The type 'ADM' stands for the admin hierarchy modeled by the admin1-4 codes. The other entries are entered with the user interface.
> The relation toponym-adm hierarchy is not included in the file, it can instead be built from the admincodes of the toponym.


geonames data
=============
Here is a simplistic way of getting the data:

```
curl -O http://download.geonames.org/export/dump/hierarchy.zip
curl -O http://download.geonames.org/export/dump/featureCodes_en.txt
curl -O http://download.geonames.org/export/dump/allCountries.zip
curl -O http://download.geonames.org/export/dump/alternateNamesV2.zip

# the zip archive has a single file, allCountries.txt, which is the same name as the main geonames file
curl --output postal_codes.zip http://download.geonames.org/export/zip/allCountries.zip
unzip -p postal_codes.zip allCountries.txt > all_countries_postal_codes.txt

unzip hierarchy.zip
unzip allCountries.zip
unzip alternateNamesV2.zip

```


sqlite
======
This uses the `vsv`, `fts4` and `spellfix` extensions. The `load_geonames` script assumes that `fts4` is builtin and the `vsv` and `spellfix` are dynamically loadable. It may be the case that the HTTP download could be done within the script (and keeping the delimited file payloads within the database itself)