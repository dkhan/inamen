# frozen_string_literal: true

module Inamen
  # Deterministic number research facts for counts produced by Discover/Features.
  module NumberFacts
    DEFAULT_SEQUENCE_DIGITS = 1_000_000
    CHUDNOVSKY_DIGITS_PER_TERM = 14.181647462725477
    CHUDNOVSKY_C3_OVER_24 = 10_939_058_860_032_000
    SEQUENCE_OCCURRENCE_RANKS = [1, 7, 77, 777].freeze

    Factor = Struct.new(:prime, :exponent, :prime_index, keyword_init: true)
    SequenceOccurrence = Struct.new(:name, :needle, :positions_by_rank, :searched_digits, keyword_init: true) do
      def position
        position_for(1)
      end

      def position_for(rank)
        positions_by_rank.fetch(rank, nil)
      end

      def found?(rank = 1)
        !position_for(rank).nil?
      end
    end

    Facts = Struct.new(
      :number, :factors, :divisor_count, :divisor_sum, :proper_divisor_sum,
      :classification, :digital_root, :digit_sum, :base_representations,
      :seven, :figurate, :sequences,
      keyword_init: true
    )

    class << self
      def build(number, sequence_digits: DEFAULT_SEQUENCE_DIGITS)
        n = Integer(number)
        raise ArgumentError, "number must be positive" unless n.positive?

        factors = prime_factors(n).map do |prime, exponent|
          Factor.new(prime: prime, exponent: exponent, prime_index: prime_index(prime))
        end

        divisor_count = factors.reduce(1) { |total, factor| total * (factor.exponent + 1) }
        divisor_sum = factors.reduce(1) do |total, factor|
          total * ((factor.prime**(factor.exponent + 1) - 1) / (factor.prime - 1))
        end
        proper_divisor_sum = divisor_sum - n

        Facts.new(
          number: n,
          factors: factors,
          divisor_count: divisor_count,
          divisor_sum: divisor_sum,
          proper_divisor_sum: proper_divisor_sum,
          classification: classification(n, proper_divisor_sum),
          digital_root: digital_root(n),
          digit_sum: n.digits.sum,
          base_representations: base_representations(n),
          seven: seven_facts(n),
          figurate: figurate_facts(n),
          sequences: sequence_occurrences(n, sequence_digits: sequence_digits)
        )
      end

      def prime_factors(number)
        n = number
        factors = []
        power = 0
        while (n % 2).zero?
          power += 1
          n /= 2
        end
        factors << [2, power] if power.positive?

        divisor = 3
        while divisor * divisor <= n
          power = 0
          while (n % divisor).zero?
            power += 1
            n /= divisor
          end
          factors << [divisor, power] if power.positive?
          divisor += 2
        end
        factors << [n, 1] if n > 1
        factors
      end

      def prime_index(prime)
        return 1 if prime == 2

        count = 1
        candidate = 3
        while candidate <= prime
          count += 1 if prime?(candidate)
          candidate += 2
        end
        count
      end

      def prime?(number)
        return false if number < 2
        return true if number == 2
        return false if number.even?

        divisor = 3
        while divisor * divisor <= number
          return false if (number % divisor).zero?

          divisor += 2
        end
        true
      end

      def pi_digits(count)
        decimal_digits = count.to_i
        return "" unless decimal_digits.positive?

        cache_fetch(["number_facts/pi_digits/v2", decimal_digits]) do
          guard = 10
          scale_digits = decimal_digits + guard
          scale = 10**scale_digits
          terms = (scale_digits / CHUDNOVSKY_DIGITS_PER_TERM).ceil + 1
          pqt = chudnovsky_bs(0, terms)
          sqrt_scaled = integer_sqrt(10_005 * scale * scale)
          pi_scaled = (pqt[:q] * 426_880 * sqrt_scaled) / pqt[:t]
          (pi_scaled / (10**guard)).to_s[1, decimal_digits]
        end
      end

      def phi_digits(count)
        decimal_digits = count.to_i
        return "" unless decimal_digits.positive?

        cache_fetch(["number_facts/phi_digits/v1", decimal_digits]) do
          guard = 10
          scale = 10**(decimal_digits + guard)
          sqrt5_scaled = integer_sqrt(5 * scale * scale)
          phi_scaled = (scale + sqrt5_scaled) / 2
          (phi_scaled / (10**guard)).to_s[1, decimal_digits]
        end
      end

      private

      def cache_fetch(key)
        if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
          Rails.cache.fetch(key, expires_in: 30.days) { yield }
        else
          yield
        end
      end

      def chudnovsky_bs(start_index, end_index)
        if end_index - start_index == 1
          return { p: 1, q: 1, t: 13_591_409 } if start_index.zero?

          k = start_index
          p = (6 * k - 5) * (2 * k - 1) * (6 * k - 1)
          q = k * k * k * CHUDNOVSKY_C3_OVER_24
          t = p * (13_591_409 + 545_140_134 * k)
          t = -t if k.odd?
          return { p: p, q: q, t: t }
        end

        midpoint = (start_index + end_index) / 2
        left = chudnovsky_bs(start_index, midpoint)
        right = chudnovsky_bs(midpoint, end_index)

        {
          p: left[:p] * right[:p],
          q: left[:q] * right[:q],
          t: right[:q] * left[:t] + left[:p] * right[:t]
        }
      end

      def integer_sqrt(number)
        return number if number < 2

        x = 1 << ((number.bit_length + 1) / 2)
        loop do
          y = (x + number / x) / 2
          return x if y >= x

          x = y
        end
      end

      def classification(number, proper_divisor_sum)
        return "perfect" if proper_divisor_sum == number

        proper_divisor_sum > number ? "abundant" : "deficient"
      end

      def digital_root(number)
        1 + ((number - 1) % 9)
      end

      def base_representations(number)
        {
          binary: number.to_s(2),
          octal: number.to_s(8),
          hexadecimal: number.to_s(16).upcase
        }
      end

      def seven_facts(number)
        exponent = 0
        remainder = number
        while (remainder % 7).zero?
          exponent += 1
          remainder /= 7
        end

        {
          divisible: exponent.positive?,
          exponent: exponent,
          cofactor: remainder,
          quotient: number / 7,
          remainder_mod_7: number % 7,
          quotient_49: number / 49,
          remainder_mod_49: number % 49,
          quotient_343: number / 343,
          remainder_mod_343: number % 343,
          balanced_sum: balanced_seven_sum(number),
          nearest_power: nearest_power_of_seven(number)
        }
      end

      def balanced_seven_sum(number)
        return nil unless (number % 14).zero?

        half = number / 2
        "#{half} + #{half} = #{half / 7}x7 + #{half / 7}x7"
      end

      def nearest_power_of_seven(number)
        powers = [1]
        powers << powers.last * 7 while powers.last < number
        powers.min_by { |power| (power - number).abs }
      end

      def figurate_facts(number)
        {
          square: square?(number),
          cube: cube?(number),
          triangular: triangular?(number),
          fibonacci: fibonacci?(number),
          palindrome_base_10: number.to_s == number.to_s.reverse,
          nearest_square: nearest_power(number, 2),
          nearest_cube: nearest_power(number, 3)
        }
      end

      def square?(number)
        root = integer_sqrt(number)
        root * root == number
      end

      def cube?(number)
        root = number ** (1.0 / 3)
        candidates = [root.floor, root.ceil]
        candidates.any? { |candidate| candidate**3 == number }
      end

      def triangular?(number)
        square?(8 * number + 1)
      end

      def fibonacci?(number)
        square?(5 * number * number + 4) || square?(5 * number * number - 4)
      end

      def nearest_power(number, exponent)
        root = number ** (1.0 / exponent)
        candidates = [root.floor, root.ceil].uniq.map { |candidate| candidate**exponent }
        candidates.min_by { |candidate| (candidate - number).abs }
      end

      def sequence_occurrences(number, sequence_digits:)
        needle = number.to_s
        [
          sequence_occurrence("Pi", needle, pi_digits(sequence_digits), sequence_digits),
          sequence_occurrence("Phi", needle, phi_digits(sequence_digits), sequence_digits)
        ]
      end

      def sequence_occurrence(name, needle, digits, searched_digits)
        positions_by_rank = occurrence_positions_by_rank(needle, digits, SEQUENCE_OCCURRENCE_RANKS)
        SequenceOccurrence.new(
          name: name,
          needle: needle,
          positions_by_rank: positions_by_rank,
          searched_digits: searched_digits
        )
      end

      def occurrence_positions_by_rank(needle, digits, ranks)
        wanted = ranks.sort
        positions = {}
        occurrence_count = 0
        offset = 0

        while (index = digits.index(needle, offset))
          occurrence_count += 1
          positions[occurrence_count] = index + 1 if wanted.include?(occurrence_count)
          break if positions.length == wanted.length

          offset = index + 1
        end

        ranks.to_h { |rank| [rank, positions[rank]] }
      end
    end
  end
end
