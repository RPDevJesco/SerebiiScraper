class Pokemon
  attr_accessor :name, :national_dex_entry, :type_color, :type_link, :type1, :type2, :catch_rate, :growth_formula, :growth_rate, :gen1, :gen2, :gen3

  def initialize(name:, national_dex_entry:, type_color:, type_link:, type1:, type2:, catch_rate:, growth_formula:, growth_rate:, gen1:, gen2:, gen3:)
    @name = name
    @national_dex_entry = national_dex_entry
    @type_color = type_color
    @type_link = type_link
    @type1 = type1
    @type2 = type2
    @catch_rate = catch_rate
    @growth_formula = growth_formula
    @growth_rate = growth_rate
    @gen1 = gen1
    @gen2 = gen2
    @gen3 = gen3
  end
end