require 'json'

script_directory = Dir.pwd
json_file_path = File.join(script_directory, 'pokemon.json')
# Read the JSON file
data = JSON.parse(File.read(json_file_path))

# Iterate through each pokemon
data.each do |pokemon_object|
  pokemon_object.each do |name, pokemon|
    if pokemon['gen1'].has_key?('stats')
      stats = pokemon['gen1']['stats']
      stats['HP'] = stats['HP'].to_i
      stats['Attack'] = stats['Attack'].to_i
      stats['Defense'] = stats['Defense'].to_i
      stats['Special'] = stats['Special'].to_i
      stats['Speed'] = stats['Speed'].to_i
    end
    if pokemon['gen2'].has_key?('stats')
      stats = pokemon['gen2']['stats']
      stats['HP'] = stats['HP'].to_i
      stats['Attack'] = stats['Attack'].to_i
      stats['Defense'] = stats['Defense'].to_i
      stats['SpecialAttack'] = stats['SpecialAttack'].to_i
      stats['SpecialDefense'] = stats['SpecialDefense'].to_i
      stats['Speed'] = stats['Speed'].to_i
    end
    if pokemon['gen3'].has_key?('stats')
      stats = pokemon['gen3']['stats']
      stats['HP'] = stats['HP'].to_i
      stats['Attack'] = stats['Attack'].to_i
      stats['Defense'] = stats['Defense'].to_i
      stats['SpecialAttack'] = stats['SpecialAttack'].to_i
      stats['SpecialDefense'] = stats['SpecialDefense'].to_i
      stats['Speed'] = stats['Speed'].to_i
    end
  end
end

# Save the updated data back to the JSON file
File.write(json_file_path, JSON.pretty_generate(data))