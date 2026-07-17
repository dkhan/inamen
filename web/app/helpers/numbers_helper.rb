# frozen_string_literal: true

module NumbersHelper
  def number_factorization(facts)
    return number_research_link(1) if facts.number == 1

    facts.factors.map do |factor|
      exponent = factor.exponent > 1 ? tag.sup(number_research_link(factor.exponent)) : nil
      safe_join([number_research_link(factor.prime), exponent].compact)
    end.reduce { |memo, item| safe_join([memo, " × ", item]) }
  end

  def number_prime_index_list(facts)
    return "None" if facts.factors.empty?

    safe_join(
      facts.factors.map do |factor|
        tag.li do
          safe_join([
            number_research_link(factor.prime),
            " is prime #",
            number_research_link(factor.prime_index),
            factor.exponent > 1 ? safe_join([" and appears ", number_research_link(factor.exponent), " times"]) : nil
          ].compact)
        end
      end
    )
  end

  def yes_no(value)
    value ? "yes" : "no"
  end

  def sequence_occurrence_label(sequence)
    sequence_occurrence_rank_label(sequence, 1)
  end

  def sequence_occurrence_rank_label(sequence, rank)
    position = sequence.position_for(rank)
    if position
      number_research_link(position)
    else
      "not found"
    end
  end

  def number_code_link(number, label: nil)
    tag.code(number_research_link(number, label: label))
  end

  def number_expression_link(*parts)
    tag.code(safe_join(parts))
  end
end
