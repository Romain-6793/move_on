class RealEstateScoreCalculator
  def initialize(city, scope = City.all)
    @city = city
    @scope = scope
  end

  def call
    {
      price_score: price_score.round(2),
      market_score: market_score.round(2),
      final_score: final_score.round(2)
    }
  end

  private

  attr_reader :city, :scope

  def price_indicator(record)
    return 0 if record.median_price_sqm.nil? || record.avg_price_sqm.nil?

    (record.median_price_sqm * 0.7) + (record.avg_price_sqm * 0.3)
  end

  def market_indicator(record)
    return 0 if record.transactions_last_year.nil? || record.total_transactions.nil?

    (record.transactions_last_year * 0.7) + (record.total_transactions * 0.3)
  end

  def price_score
    min = scope.map { |record| price_indicator(record) }.min
    max = scope.map { |record| price_indicator(record) }.max

    return 50 if max == min

    100.0 * (max - price_indicator(city)) / (max - min)
  end

  def market_score
    min = scope.map { |record| market_indicator(record) }.min
    max = scope.map { |record| market_indicator(record) }.max

    return 50 if max == min

    100.0 * (market_indicator(city) - min) / (max - min)
  end

  def final_score
    (price_score * 0.6) + (market_score * 0.4)
  end
end
