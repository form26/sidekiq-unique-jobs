# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :have_key do |unique_key|
  Sidekiq.redis do |conn|
    match do |_unique_jobs|
      @exists_key  = "#{unique_key}:EXISTS"
      @value       = conn.get(@exists_key)
      @ttl         = conn.ttl(@exists_key)

      @value && with_value && for_seconds
    end

    chain :with_value do |value = nil|
      @expected_value = value
      @expected_value && @value == @expected_value
    end

    chain :for_seconds do |ttl = nil|
      @expected_ttl = ttl
      @expected_ttl && @ttl == @expected_ttl
    end

    failure_message do |_actual|
      msg = "expected Redis to have key #{@exists_key}"
      msg += " with value #{@expected_value} was (#{@value})" if @expected_value
      msg += " with value #{@expected_ttl} was (#{@ttl})" if @expected_ttl
      msg
    end
  end
end
