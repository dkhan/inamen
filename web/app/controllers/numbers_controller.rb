# frozen_string_literal: true

class NumbersController < ApplicationController
  def index
    value = params[:number].to_s.delete(",").strip
    if value.present?
      redirect_to number_path(value)
      return
    end

    @examples = [7, 49, 77, 153, 343, 490, 777, 980, 1029]
  end

  def show
    @number = params[:id].to_s.delete(",").strip
    unless @number.match?(/\A[1-9]\d*\z/)
      redirect_to numbers_path, alert: "Enter a positive whole number."
      return
    end

    @facts = Inamen::NumberFacts.build(@number)
  rescue ArgumentError
    redirect_to numbers_path, alert: "Enter a positive whole number."
  end

  def preview
    number = params[:id].to_s.delete(",").strip
    raise ArgumentError unless number.match?(/\A[1-9]\d*\z/)

    facts = Inamen::NumberFacts.build(number, sequence_digits: 0)
    render json: {
      number: facts.number,
      title: helpers.number_with_delimiter(facts.number),
      factorization: preview_factorization(facts),
      prime_indexes: preview_prime_indexes(facts),
      seven_forms: preview_seven_forms(facts)
    }
  rescue ArgumentError
    render json: { error: "Enter a positive whole number." }, status: :unprocessable_entity
  end

  private

  def preview_factorization(facts)
    return "1" if facts.number == 1

    facts.factors.map do |factor|
      exponent = factor.exponent > 1 ? "^#{factor.exponent}" : ""
      "#{factor.prime}#{exponent}"
    end.join(" × ")
  end

  def preview_prime_indexes(facts)
    return ["1 is neither prime nor composite"] if facts.number == 1

    facts.factors.map do |factor|
      suffix = factor.exponent > 1 ? ", exponent #{factor.exponent}" : ""
      "#{factor.prime} is prime ##{factor.prime_index}#{suffix}"
    end
  end

  def preview_seven_forms(facts)
    seven = facts.seven
    forms = []
    forms << "7 × #{seven[:quotient]} + #{seven[:remainder_mod_7]}"
    forms << "49 × #{seven[:quotient_49]} + #{seven[:remainder_mod_49]}"
    forms << "343 × #{seven[:quotient_343]} + #{seven[:remainder_mod_343]}"
    forms << "7^#{seven[:exponent]} × #{seven[:cofactor]}" if seven[:exponent].positive?
    forms << seven[:balanced_sum] if seven[:balanced_sum].present?
    forms << "Nearest 7-power: #{seven[:nearest_power]}"
    forms.uniq
  end
end
