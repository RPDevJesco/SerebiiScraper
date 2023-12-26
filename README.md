Run ScrapeSerebii.rb

The default amount of pokemon that will be added to the JSON is from 001 all the way to 386. With this count, you are likely to get a timeout. So I'd recommend going from 1 to 151, 152 to 251 or 252 to 386. That will cover each generation's list of pokemon.

FixJSONData.rb will fix the JSON for the stats so it will be numerical values instead of a string value.


Pokemon.rb is a helper class, it provides the blueprint for the Pokemon JSON file structure.

gen_2_base_stats contains the base stat data for pokemon number 1 through 251.

BaseDataFromASM.rb is designed to be run in order to pull data from the ASM files in the list and add it to each pokemon indivdually.
