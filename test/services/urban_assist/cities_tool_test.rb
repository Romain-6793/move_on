# frozen_string_literal: true

require "test_helper"

module UrbanAssist
  class CitiesToolTest < ActiveSupport::TestCase
    setup do
      @insee = "TST#{SecureRandom.hex(3)}"
      City.create!(
        insee: @insee,
        nom_com: "VILLETESTIA",
        dep: "75",
        nom_dep: "Paris",
        nom_reg: "Île-de-France",
        median_price_sqm: 5000.0,
        transactions_last_year: 100,
        price_evolution_1y: 2.5,
        population: 50_000
      )
    end

    test "execute national retourne des données" do
      tool = CitiesTool.new
      out = tool.execute(zone_type: "national", zone_name: nil, sort_by: nil, min_population: nil)
      assert out["data"].is_a?(Array)
      assert_operator out["data"].size, :>=, 1
      sample = out["data"].first
      assert sample.key?("id")
      assert sample.key?("median_price_sqm")
    end

    test "execute commune trouve par nom" do
      tool = CitiesTool.new
      out = tool.execute(zone_type: "commune", zone_name: "VILLETESTIA", sort_by: nil, min_population: nil)
      assert_equal 1, out["data"].size
      assert_equal "VILLETESTIA", out["data"].first.fetch("name")
    end
  end
end
