# frozen_string_literal: true

require "test_helper"

# Occurrence-level exclusion counting: exclusions subtract each matched base
# occurrence at most once, deduplicated by the occurrence's text range (never by
# verse). These exercise the pure counting core directly with synthetic position
# ranges so the behavior is verified independently of any corpus or feature.
class ExclusionOverlapDedupTest < ActiveSupport::TestCase
  def counts(include_occurrences, *exclude_rows)
    DiscoveryScan.deduplicated_exclusion_counts(include_occurrences, exclude_rows)
  end

  test "two exclusion phrases covering the same base occurrence exclude it once" do
    base = [(10...11)] # one base occurrence at position 10
    result = counts(base, [(9...12)], [(10...11)]) # both exclusion ranges cover it

    assert_equal [1, 0], result, "shared occurrence is attributed to the first row only"
    assert_equal 1, result.sum, "the shared occurrence is subtracted exactly once"
  end

  test "overlapping exclusions in the same verse subtract a shared occurrence once" do
    # A verse spanning positions 100..104 with one base occurrence at 102.
    base = [(102...103)]
    result = counts(base, [(100...103)], [(102...105)])

    assert_equal 1, result.sum
  end

  test "distinct base occurrences in one verse are each excluded (dedup by occurrence, not verse)" do
    # A single verse (positions 200..205) containing two base occurrences.
    base = [(201...202), (204...205)]
    result = counts(base, [(201...202)], [(204...205)])

    assert_equal [1, 1], result
    assert_equal 2, result.sum, "different occurrences in the same verse are excluded separately"
  end

  test "non-overlapping exclusions each remove their own occurrence" do
    base = [(1...2), (50...51)]
    result = counts(base, [(1...2)], [(50...51)])

    assert_equal [1, 1], result
    assert_equal 2, result.sum
  end

  test "an exclusion covering no base occurrence removes nothing" do
    base = [(1...2)]
    result = counts(base, [(900...905)])

    assert_equal [0], result
  end

  test "mirrors the James overlap: 12 phrase matches over 10 distinct occurrences" do
    # Ten base "James" occurrences; two are each covered by two exclusion phrases,
    # so 12 phrase-level matches must subtract only 10 distinct occurrences.
    base = (0...10).map { |i| (i...(i + 1)) }
    mary   = [(2...3), (5...6), (7...8), (9...10)] # "Mary the mother of James" x4
    joses  = [(0...1), (1...2), (2...3)]           # "James and Joses" x3 (shares occ 2)
    less   = [(4...5), (5...6)]                    # "James the less" x2 (shares occ 5)
    result = counts(base, mary, joses, less)

    assert_equal 4 + 3 + 2, mary.size + joses.size + less.size, "9 raw phrase matches modelled"
    # occurrences 2 and 5 are shared; first row (mary) keeps them, others drop them.
    assert_equal [4, 2, 1], result
    assert_equal 7, result.sum, "distinct occurrences excluded once each"
  end
end
