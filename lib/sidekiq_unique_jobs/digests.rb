# frozen_string_literal: true

module SidekiqUniqueJobs
  #
  # Class Changelogs provides access to the changelog entries
  #
  # @author Mikael Henriksson <mikael@zoolutions.se>
  #
  class Digests < Redis::SortedSet
    #
    # @return [Integer] the number of matches to return by default
    DEFAULT_COUNT = 1_000
    #
    # @return [String] the default pattern to use for matching
    SCAN_PATTERN  = "*"

    def initialize
      super(DIGESTS)
    end

    #
    # Adds a digest
    #
    # @param [String] digest the digest to add
    #
    def add(digest)
      redis { |conn| conn.zadd(key, now_f, digest) }
    end

    #
    # Deletes unique digest either by a digest or pattern
    #
    # @overload call_script(digest: "abcdefab")
    #   Call script with digest
    #   @param [String] digest: a digest to delete
    # @overload call_script(pattern: "*", count: 1_000)
    #   Call script with pattern
    #   @param [String] pattern: "*" a pattern to match
    #   @param [String] count: DEFAULT_COUNT the number of keys to delete
    #
    # @raise [ArgumentError] when given neither pattern nor digest
    #
    # @return [Array<String>] with unique digests
    #
    def del(digest: nil, pattern: nil, count: DEFAULT_COUNT)
      return delete_by_pattern(pattern, count: count) if pattern
      return delete_by_digest(digest) if digest

      raise ArgumentError, "##{__method__} requires either a :digest or a :pattern"
    end

    #
    # The entries in this sorted set
    #
    # @param [String] pattern SCAN_PATTERN the match pattern to search for
    # @param [Integer] count DEFAULT_COUNT the number of entries to return
    #
    # @return [Array<String>] an array of digests matching the given pattern
    #
    def entries(pattern: SCAN_PATTERN, count: DEFAULT_COUNT)
      options = {}
      options[:match] = pattern
      options[:count] = count if count

      result = redis { |conn| conn.zscan_each(key, options).to_a }

      result.each_with_object({}) do |entry, hash|
        hash[entry[0]] = entry[1]
      end
    end

    #
    # Returns a paginated
    #
    # @param [Integer] cursor the cursor for this iteration
    # @param [String] pattern SCAN_PATTERN the match pattern to search for
    # @param [Integer] page_size 100 the size per page
    #
    # @return [Array<Integer, Integer, Array<Lock>>] total_size, next_cursor, locks
    #
    def page(cursor: 0, pattern: SCAN_PATTERN, page_size: 100)
      redis do |conn|
        total_size, digests = conn.multi do
          conn.zcard(key)
          conn.zscan(key, cursor, match: pattern, count: page_size)
        end

        [
          total_size,
          digests[0], # next_cursor
          digests[1].map { |digest, score| Lock.new(digest, time: score) }, # entries
        ]
      end
    end

    private

    # Deletes unique digests by pattern
    #
    # @param [String] pattern a key pattern to match with
    # @param [Integer] count the maximum number
    # @return [Array<String>] with unique digests
    def delete_by_pattern(pattern, count: DEFAULT_COUNT)
      result, elapsed = timed do
        digests = entries(pattern: pattern, count: count).keys
        SidekiqUniqueJobs::BatchDelete.new(digests).call
      end

      log_info("#{__method__}(#{pattern}, count: #{count}) completed in #{elapsed}ms")

      result
    end

    # Delete unique digests by digest
    #   Also deletes the :AVAILABLE, :EXPIRED etc keys
    #
    # @param [String] digest a unique digest to delete
    def delete_by_digest(digest)
      result, elapsed = timed do
        call_script(:delete_by_digest, [digest, key])
      end

      log_info("#{__method__}(#{digest}) completed in #{elapsed}ms")

      result
    end
  end
end
