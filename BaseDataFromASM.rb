require 'json'


def extract_exp_yield_from_asm(asm_file_path)
  exp_yield = nil
  File.foreach(asm_file_path) do |line|
    match = line.match(/^\s*db\s+(\d+)\s*;\s*base\s+exp\s*$/i)
    if match
      exp_yield = match[1].to_i
      break
    end
  end
  exp_yield
end

script_directory = Dir.pwd
json_file_path = File.join(script_directory, '/json_files/pokemon.json')

data = JSON.parse(File.read(json_file_path))

data.each do |pokemon_object|
  pokemon_object.each do |name, pokemon|
    asm_file_path = File.join(script_directory, "gen_2_base_stats/#{name}.asm")

    if File.exist?(asm_file_path)
      exp_yield = extract_exp_yield_from_asm(asm_file_path)

      # Create a new hash to maintain order of elements
      new_pokemon = {}

      pokemon.each do |key, value|
        new_pokemon[key] = value
        # After adding 'catch_rate', add 'expYield'
        new_pokemon['expYield'] = exp_yield if key == 'catch_rate'
      end

      # replace the old pokemon data with the new one
      pokemon_object[name] = new_pokemon
    else
      puts "No ASM file found for #{name}"
    end
  end
end

# Save the updated data back to the JSON file
File.write(json_file_path, JSON.pretty_generate(data))