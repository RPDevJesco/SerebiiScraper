require 'httparty'
require 'nokogiri'
require 'json'
require 'logger'
require 'optparse'
require_relative 'pokemon'

OUTPUT_FILE = 'pokemon.json'
BASE_URL = 'https://www.serebii.net'

# Global logger setup
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

# Command-line options setup
options = {save: true}
OptionParser.new do |opts|
  opts.banner = 'Usage: script.rb [options]'

  opts.on('-s', '--save', 'Save the output to JSON') { options[:save] = true }
  opts.on('-f', '--first FIRST', Integer, 'The ID of the first Pokémon to retrieve') { |f| options[:first] = f }
  opts.on('-l', '--last LAST', Integer, 'The ID of the last Pokémon to retrieve') { |l| options[:last] = l }
  opts.on('-v', '--verbose', 'Print the Pokémon\'s statistics to console') { options[:verbose] = true }
end.parse!

# Default values for first and last
options[:first] ||= 1
options[:last] ||= 386

def extract_core_statistics(poke_id)
  url = "#{BASE_URL}/pokedex-dp/#{poke_id.to_s.rjust(3, '0')}.shtml"
  response = HTTParty.get(url)
  doc = Nokogiri::HTML(response.body)

  # Find the relevant elements
  all_divs = doc.css('div[align="center"]')

  valid_types = ['fire', 'water', 'grass', 'bug', 'flying', 'electric', 'poison', 'ground', 'rock', 'fairy', 'steel', 'ghost', 'normal', 'fighting', 'psychic', 'ice', 'dragon', 'dark']
  type_colors = {
    "Normal" => "#A8A77A",
    "Fire" => "#EE8130",
    "Water" => "#6390F0",
    "Electric" => "#F7D02C",
    "Grass" => "#7AC74C",
    "Ice" => "#96D9D6",
    "Fighting" => "#C22E28",
    "Poison" => "#A33EA1",
    "Ground" => "#E2BF65",
    "Flying" => "#A98FF3",
    "Psychic" => "#F95587",
    "Bug" => "#A6B91A",
    "Rock" => "#B6A136",
    "Ghost" => "#735797",
    "Dragon" => "#6F35FC",
    "Dark" => "#705848",
    "Steel" => "#B8B8D0"
  }
  growth_formula_lookup = {
    "Slow" => "(5 * x**3) / 4",
    "Medium Slow" => "(6 * x**3) / 5 - 15 * x**2 + 100 * x - 140",
    "Medium Fast" => "x**3",
    "Fast" => "(4 * x**3) / 5",
  }

  # For "Name": Assuming the name is the text of the first `td` tag with class 'fooinfo'
  name_element = all_divs.at_css('.dextable .fooinfo')
  name = name_element.text.strip

  # Select elements and get types
  type_elements = all_divs.css('.dextable td.fooinfo a[href*="pokedex-dp"]').first(2)
  types = type_elements.map { |a| a['href'].split('/')[-1].split('.').first }

  # Filter out any unvalid types
  types.select! { |type| valid_types.include?(type.downcase) }
  type1, type2 = types

  # Get colors and icon links
  type1_color, type2_color = types.map { |type| type_colors[type.capitalize] }
  type_icon_links = types.map { |type| "./Images/types/icons/#{type.capitalize}.webp" }

  # Experience Growth
  experience_growth_element = doc.at_css('tr:contains("Experience Growth")').next_element.css('td.fooinfo').first
  experience_growth = experience_growth_element.text.reverse.split('stnioP', 2).first.reverse
  growth_formula = growth_formula_lookup[experience_growth]
  growth_rate = experience_growth

  # Extract Catch Rate data
  catch_rate_label = doc.xpath('//td[contains(text(),"Capture Rate")]/following::tr[1]/td[4]').text.strip

  # Return a Hash, not a single value
  {
    name: name,
    type_color: [type1_color, type2_color],
    type_link: type_icon_links,
    type1: type1,
    type2: type2,
    catch_rate: catch_rate_label,
    growth_formula: growth_formula,
    growth_rate: growth_rate,
  }
end

def extract_gen1_statistics(poke_id)
  url = "#{BASE_URL}/pokedex/#{poke_id.to_s.rjust(3, '0')}.shtml"
  response = HTTParty.get(url)
  doc = Nokogiri::HTML(response.body)

  return nil if poke_id >= 152

  # Find the relevant elements
  all_divs = doc.css('div[align="center"]')

  # Find the element containing 'Base Stats - Total'
  base_stats_label = all_divs[1].at_css('td:contains("Base Stats - Total")')
  base_stats = extract_sibling_text(base_stats_label)

  # Extract Damage Taken
  damage_taken_label = all_divs[1].at_css('td:contains("Damage Taken")')
  damage_taken = extract_damage_taken(damage_taken_label)

  # Extract Evolution data
  evo_chain_label = all_divs[1].at_css('td:contains("Evolutionary Chain")')
  evo_chain = extract_evolution_chain(evo_chain_label)

  # Extract Level Up Moves
  level_up_label = all_divs[1].at_css('td:contains("Generation I Level Up")')
  level_up_table = level_up_label ? level_up_label.ancestors('table').first : nil
  level_up_moves = extract_moves(level_up_table)

  # Extract TM & HM Attacks
  tm_hm_label = all_divs[1].at_css('td:contains("TM & HM Attacks")')
  tm_hm_table = tm_hm_label ? tm_hm_label.ancestors('table').first : nil
  tm_hm_moves = extract_moves(tm_hm_table)

  # Merge into the same table
  moves = level_up_moves
  moves.each do |move_type, move_list|
    moves[move_type] += tm_hm_moves[move_type] if tm_hm_moves[move_type]
  end

  {
    "evolutionLine" => evo_chain,
    "stats" => {
      "HP" => base_stats[0],
      "Attack" => base_stats[1],
      "Defense" => base_stats[2],
      "Special" => base_stats[3],
      "Speed" => base_stats[4],
    },
    "damageTaken" => damage_taken,
    "moves" => {
      "source"=> moves[:source],
      "version" => moves[:version],
      "name" => moves[:name]
    }
  }
end

def extract_gen2_statistics(poke_id)
  url = "#{BASE_URL}/pokedex-gs/#{poke_id.to_s.rjust(3, '0')}.shtml"
  response = HTTParty.get(url)
  doc = Nokogiri::HTML(response.body)

  return nil if poke_id >= 252

  # Find the relevant elements
  all_divs = doc.css('div[align="center"]')

  # Extract Happiness data
  base_happiness_label = all_divs[1].at_css('td:contains("Base Happiness")')
  base_happiness = extract_base_happiness(base_happiness_label)

  # Find the element containing 'Base Stats - Total'
  base_stats_label = all_divs[1].at_css('td:contains("Base Stats - Total")')
  base_stats = extract_sibling_text(base_stats_label)

  # Extract Damage Taken
  damage_taken_label = all_divs[1].at_css('td:contains("Damage Taken")')
  damage_taken = extract_damage_taken(damage_taken_label)

  # Extract Evolution data
  evo_chain_label = all_divs[1].at_css('td:contains("Evolutionary Chain")')
  evo_chain = extract_evolution_chain(evo_chain_label)

  # Extract Level Up Moves
  level_up_label = all_divs[1].at_css('td:contains("Generation II Level Up")')
  level_up_table = level_up_label ? level_up_label.ancestors('table').first : nil
  level_up_moves = extract_moves(level_up_table)

  # Extract TM & HM Attacks
  tm_hm_label = all_divs[1].at_css('td:contains("TM & HM Attacks")')
  tm_hm_table = tm_hm_label ? tm_hm_label.ancestors('table').first : nil
  tm_hm_moves = extract_moves(tm_hm_table)

  # Merge into the same table
  moves = level_up_moves
  moves.each do |move_type, move_list|
    moves[move_type] += tm_hm_moves[move_type] if tm_hm_moves[move_type]
  end

  {
    "evolutionLine" => evo_chain,
    "stats" => {
      "HP" => base_stats[0],
      "Attack" => base_stats[1],
      "Defense" => base_stats[2],
      "SpecialAttack" => base_stats[3],
      "SpecialDefense" => base_stats[4],
      "Speed" => base_stats[5],
    },
    "damageTaken" => damage_taken,
    "moves" => {
      "source"=> moves[:source],
      "version" => moves[:version],
      "name" => moves[:name]
    }
  }
end

def extract_frlg_statistics(poke_id)
  url = "#{BASE_URL}/pokedex-rs/#{poke_id.to_s.rjust(3, '0')}.shtml"
  response = HTTParty.get(url)
  doc = Nokogiri::HTML(response.body)

  # Extract Ability
  ability_label = doc.at_css('td:contains("Ability:")').text
  ability = ability_label[/\bAbility: (.+)/, 1] # Regex to capture text after 'Ability: '

  # Extract Damage Taken
  damage_taken_label = doc.at_css('td:contains("Damage Taken")')
  damage_taken = extract_damage_taken(damage_taken_label)

  # Extract Fire Red/Leaf Green Level Up
  level_up_label = doc.at_css('th:contains("Fire Red/Leaf Green Level Up")')
  level_up_table = level_up_label ? level_up_label.ancestors('table').first : nil
  level_up_moves = extract_frlg_moves(level_up_table, :level_up_moves)

  tm_hm_label = doc.at_css('th:contains("TM & HM Attacks")')
  tm_hm_table = tm_hm_label ? tm_hm_label.ancestors('table').first : nil
  tm_hm_moves = extract_frlg_moves(tm_hm_table, :level_up_moves)

  tutor_label = doc.at_css('td:contains("Fire Red/Leaf Green/Emerald Tutor Attacks")')
  tutor_table = tutor_label ? tutor_label.ancestors('table').first : nil
  tutor_moves = extract_frlg_moves(tutor_table, :tutor_moves)

  # Find the Egg Moves label
  egg_moves_label = doc.at_css('td:contains("Egg Moves")')
  # The sibling table holding the moves data is a sibling to the egg_moves_label's grandparent (the 'tr' element)
  egg_moves_table = egg_moves_label.ancestors('tr').first.next_element
  egg_moves = extract_frlg_moves(egg_moves_table, :egg_moves)

  moves = level_up_moves.merge(tutor_moves) { |key, oldval, newval| oldval + newval }
  moves = moves.merge(tm_hm_moves) { |key, oldval, newval| oldval + newval }
  moves = moves.merge(egg_moves) { |key, oldval, newval| oldval + newval }

  # Extract Base Stats
  base_stats_label = doc.at_css('td:contains("Base Stats")')
  base_stats = extract_sibling_text(base_stats_label)

  {
    "ability" => ability,
    "stats" => {
      "HP" => base_stats[0],
      "Attack" => base_stats[1],
      "Defense" => base_stats[2],
      "SpecialAttack" => base_stats[3],
      "SpecialDefense" => base_stats[4],
      "Speed" => base_stats[5],
    },
    "damageTaken" => damage_taken,
    "moves" => {
      "source"=> moves[:source],
      "version" => moves[:version],
      "name" => moves[:name]
    }
  }
end

def extract_statistics(poke_id)
  core_stats = extract_core_statistics(poke_id)
  gen1_stats = extract_gen1_statistics(poke_id)
  gen2_stats = extract_gen2_statistics(poke_id)
  frlg_stats = extract_frlg_statistics(poke_id)

  # Then in your main code, create a new Pokemon instance
  pokemon = Pokemon.new(
    name: core_stats[:name],
    national_dex_entry: format('%03d', poke_id),
    type_color: core_stats[:type_color],
    type_link: core_stats[:type_link],
    type1: core_stats[:type1],
    type2: core_stats[:type2],
    catch_rate: core_stats[:catch_rate],
    growth_formula: core_stats[:growth_formula],
    growth_rate: core_stats[:growth_rate],
    gen1: gen1_stats,
    gen2: gen2_stats,
    gen3: frlg_stats
  )
rescue => e
  $logger.error("There was an error trying to identify HTML elements on the webpage.")
  raise e
end

def extract_sibling_text(label_element)
  if label_element.nil?
    $logger.error("Label not found. Unable to extract sibling text.")
  else
    texts = []
    current_element = label_element.next_element
    while current_element && current_element.name == 'td'
      texts << current_element.text.strip
      current_element = current_element.next_element
    end

    if texts.empty?
      $logger.error("No sibling text found for label: #{label_element.text.strip}")
    end

    return texts
  end
end

def extract_type(all_divs)
  target_label = all_divs[1].at_css("td:contains(Type)")
  target_table = target_label ? target_label.ancestors('table').first : nil

  if target_table
    types = target_table.css('a').map do |anchor|
      anchor['href'].split('/').last.split('.').first
    end
    return types
  end

  nil
end

def extract_damage_taken(label_element)
  return $logger.error("#{label_element} label not found") if label_element.nil?

  table = label_element.ancestors('table').first
  return $logger.error("Could not find surrounding table for element: #{label_element}") if table.nil?

  types = table.search('tr')[1].css('a').map do |a|
    a['href'].gsub(/\/attackdex-(xy|dp)\//, "./Images/types/icons/").split('.shtml').first + ".webp"
  end
  multipliers = table.search('tr')[2].css('td').map(&:text)

  damage_taken = {
    "fourTimesWeakness": [],
    "twoTimesWeakness": [],
    "neutralWeakness": [],
    "halfDamage": [],
    "quarterDamage": [],
    "resistedDamage": []
  }

  types.zip(multipliers).each do |type, multiplier|
    type = type.gsub("psychict", "psychic") if type.include? "psychict"
    case multiplier
    when "*4"
      damage_taken[:fourTimesWeakness] << type
    when "*2"
      damage_taken[:twoTimesWeakness] << type
    when "*1"
      damage_taken[:neutralWeakness] << type
    when "*0.5"
      damage_taken[:halfDamage] << type
    when "*0.25"
      damage_taken[:quarterDamage] << type
    else
      damage_taken[:resistedDamage] << type
    end
  end

  damage_taken
end

def extract_growth_rate(label_element)
  return $logger.error("#{label_element} label not found") if label_element.nil?

  tr_element = label_element.parent
  growth_rate_cell = tr_element.next_element.at_css('td')

  texts_divided_by_br = growth_rate_cell.children.select { |c| c.text? }.map(&:text)

  points, rate = texts_divided_by_br

  growth_rate = { points: points.strip, rate: rate.strip }

  growth_rate
end

def extract_base_happiness(label_element)
  return $logger.error("#{label_element} label not found") if label_element.nil?

  tr_element = label_element.parent
  base_happiness_cell = tr_element.next_element.at_css('td:nth-child(2)') # getting second td

  base_happiness = base_happiness_cell.text.strip if base_happiness_cell

  base_happiness
end

def extract_evolution_chain(label_element)
  return $logger.error("#{label_element} label not found") if label_element.nil?

  table = label_element.ancestors('table').first
  return $logger.error("Could not find surrounding table for element: #{label_element}") if table.nil?

  evo_chain_data = table.css('td.pkmn a img').map do |img|
    # Assumes the last part of the img src URL contains the Pokemon ID or name
    img['src'].split('/').last.split('.').first
  end

  evo_chain_data
end

def extract_moves(table)
  return {} unless table

  move_rows = table.css('tr')[1..-1]  # Ignore the first row (header)

  moves = {
    "source": [],
    "version": [],
    "name": []
  }

  move_rows.each do |row|
    cells = row.css('td')

    # Check if cells[0] and cells[1] are not nil before calling text on them.
    if cells[0] && cells[1]
      source = cells[0].text.strip

      if source == '—'
        source = 'lvl 1'
      else
        source_numeric = source.to_i.to_s
        if source_numeric == source && !source.start_with?('TM') && !source.start_with?('HM')
          source = 'lvl ' + source
        end
      end

      moves[:source] << source
      moves[:version] << '2'  # Setting version as '2'
      moves[:name] << cells[1].text.strip
    end
  end

  moves
end

def extract_egg_moves(doc)
  # Find the Egg Moves label
  egg_moves_label = doc.at_css('td:contains("Egg Moves")')

  # The sibling table holding the moves data is a sibling to the egg_moves_label's grandparent (the 'tr' element)
  egg_moves_table = egg_moves_label.ancestors('tr').first.next_element

  moves = []
  description = nil

  # Iterate each row in the table
  egg_moves_table.css('tr').each do |row|
    # If the row has a "fooinfo" class, then it contains the move name and details
    if row.at_css('td.fooinfo')
      move_name = row.at_css('td.fooinfo a').text
      move_detail_cells = row.css('td.cen')
      type = move_detail_cells[0].text
      attack = move_detail_cells[1].text
      accuracy = move_detail_cells[2].text
      pp = move_detail_cells[3].text
      effect = move_detail_cells[4].text
      moves << {name: move_name, type: type, attack: attack, accuracy: accuracy, pp: pp, effect: effect, description: description}
      # Otherwise, the row contains the move description
    else
      description = row.at_css('td.fooinfo').text
    end
  end

  moves
end

def extract_frlg_moves(table, move_type)
  return {} unless table

  move_rows = table.css('tr')

  source_label = case move_type
                 when :egg_moves then 'eggMove'
                 when :tutor_moves then 'moveTutor'
                 else 'lvl'
                 end

  moves = {
    "source": [],
    "version": [],
    "name": []
  }

  move_rows.each_slice(2) do |row, _|
    cells = row.css('td')

    next unless cells[0]

    if source_label != 'lvl'
      source = source_label
      name = cells[0].text.strip
    else
      source = cells[0].text.strip
      source = 'lvl 1' if source == '—'

      unless source.start_with?('TM') || source.start_with?('HM')
        source_numeric = source.to_i.to_s
        source = 'lvl ' + source if source_numeric == source
      end
      name = cells[1].text.strip
    end

    moves[:source] << source
    moves[:version] << '2'
    moves[:name] << name
  end

  moves
end

def save_to_json(data_list)
  data_list_as_hashes = data_list.map do |pokemon|
    {
      pokemon.name => {
        'national_dex_entry' => pokemon.national_dex_entry,
        'type_color' => pokemon.type_color,
        'type_link' => pokemon.type_link,
        'type1' => pokemon.type1,
        'type2' => pokemon.type2,
        'catch_rate' => pokemon.catch_rate,
        'growth_formula' => pokemon.growth_formula,
        'growth_rate' => pokemon.growth_rate,
        'gen1' => pokemon.gen1,
        'gen2' => pokemon.gen2,
        'gen3' => pokemon.gen3
      }
    }
  end

  pokemon_hash = data_list_as_hashes.reduce({}) do |hash, data|
    pokemon_name = data.keys.first
    hash[pokemon_name] = data[pokemon_name]
    hash
  end

  File.open(OUTPUT_FILE, 'w') do |file|
    file.write(JSON.pretty_generate([pokemon_hash]))
  end
end

# Main execution
$logger.info('Extracting data from Serebii.net')
data_list = []

(options[:first]..options[:last]).each do |poke_id|
  data = extract_statistics(poke_id)
  data_list.push(data)

  if options[:verbose] || !options[:save]

  else
    $logger.info("Scraped #{data.national_dex_entry} #{data.name}")
  end
end

if options[:save]
  $logger.info("Saving to #{OUTPUT_FILE}")
  save_to_json(data_list)
else
  $logger.info('All Pokémon retrieved! To save to JSON, use the --save flag')
end
