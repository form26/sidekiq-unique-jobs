# frozen_string_literal: true

module SidekiqUniqueJobs
  module Redis
    #
    # Class SortedSet provides convenient access to redis sorted sets
    #
    # @author Mikael Henriksson <mikael@zoolutions.se>
    #
    class SortedSet < Entity
      #
      # Return entries for this sorted set
      #
      # @param [true,false] with_scores true return
      #
      # @return [Array<Object>] when given with_scores: false
      # @return [Hash] when given with_scores: true
      #
      def entries(with_scores: true)
        entrys = redis { |conn| conn.zrange(key, 0, -1, with_scores: with_scores) }
        return entrys unless with_scores

        entrys.each_with_object({}) { |pair, hash| hash[pair[0]] = pair[1] }
      end

      #
      # Return the zrak of the member
      #
      # @param [String] member the member to pull rank on
      #
      # @return [Integer]
      #
      def rank(member)
        redis { |conn| conn.zrank(key, member) }
      end

      #
      # Return score for a member
      #
      # @param [String] member the member for which score
      #
      # @return [Integer, Float]
      #
      def score(member)
        redis { |conn| conn.zscore(key, member) }
      end

      #
      # Returns the count for this sorted set
      #
      #
      # @return [Integer] the number of entries
      #
      def count
        redis { |conn| conn.zcard(key) }
      end
    end
  end
end
