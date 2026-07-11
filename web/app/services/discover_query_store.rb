# frozen_string_literal: true

# Persists Discover scan settings outside the session cookie (which is capped at ~4KB).
# The session holds only a short token; the full query (including bulky antimentions)
# lives in Rails.cache — the same store used for scan results.
class DiscoverQueryStore
  CACHE_PREFIX = "discover_query/v1"
  TTL = 7.days

  class << self
    def write(token, query)
      id = token.presence || generate_token
      Rails.cache.write(cache_key(id), query.deep_stringify_keys, expires_in: TTL)
      id
    end

    def fetch(token)
      return nil if token.blank?

      Rails.cache.read(cache_key(token))
    end

    def delete(token)
      return if token.blank?

      Rails.cache.delete(cache_key(token))
    end

    private

    def generate_token
      SecureRandom.hex(16)
    end

    def cache_key(token)
      "#{CACHE_PREFIX}/#{token}"
    end
  end
end
