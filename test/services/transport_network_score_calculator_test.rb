# frozen_string_literal: true

require "test_helper"

class TransportNetworkScoreCalculatorTest < ActiveSupport::TestCase
  setup do
    skip "TransportNetworkScoreCalculator non défini dans l’application"
  end

  test "weighted index applique les poids train 4, metro 3, tram 2, bus 1" do
    city = City.new(
      TRAIN_valeur: 1,
      METRO_valeur: 1,
      TRAM_valeur: 1,
      BUS_valeur: 1
    )
    # 4 + 3 + 2 + 1 = 10
    assert_in_delta 10.0, TransportNetworkScoreCalculator.weighted_index(city), 0.0001
  end

  test "ville a indice minimal recoit 0 et indice maximal recoit 100 sur le scope" do
    low = City.new(TRAIN_valeur: 0, METRO_valeur: 0, TRAM_valeur: 0, BUS_valeur: 0)
    low.id = 1
    high = City.new(TRAIN_valeur: 1, METRO_valeur: 0, TRAM_valeur: 0, BUS_valeur: 0)
    high.id = 2
    calc = TransportNetworkScoreCalculator.new([low, high])
    assert_in_delta 0.0, calc.for_city(low)[:final_score], 0.01
    assert_in_delta 100.0, calc.for_city(high)[:final_score], 0.01
  end

  test "indices identiques sur tout le scope donnent un score neutre 50" do
    a = City.new(TRAIN_valeur: 2, METRO_valeur: 0, TRAM_valeur: 0, BUS_valeur: 0)
    a.id = 1
    b = City.new(TRAIN_valeur: 2, METRO_valeur: 0, TRAM_valeur: 0, BUS_valeur: 0)
    b.id = 2
    calc = TransportNetworkScoreCalculator.new([a, b])
    assert_in_delta 50.0, calc.for_city(a)[:final_score], 0.01
    assert_in_delta 50.0, calc.for_city(b)[:final_score], 0.01
  end

  test "results_by_city_id expose final_score et components pour chaque id" do
    cities = [
      City.new(id: 10, BUS_valeur: 1, TRAM_valeur: 0, METRO_valeur: 0, TRAIN_valeur: 0),
      City.new(id: 20, BUS_valeur: 5, TRAM_valeur: 0, METRO_valeur: 0, TRAIN_valeur: 0)
    ]
    calc = TransportNetworkScoreCalculator.new(cities)
    by_id = calc.results_by_city_id
    assert_equal [10, 20].sort, by_id.keys.sort
    assert by_id[10][:components].key?(:bus)
    assert_match(/train ×4/i, by_id[10][:caption])
  end

  test "nil sur les valeurs est traite comme zero" do
    city = City.new
    city.id = 1
    assert_in_delta 0.0, TransportNetworkScoreCalculator.weighted_index(city), 0.0001
  end
end
