# frozen_string_literal: true

begin
  require "delegate"
  require "rack"
  require "sidekiq/web"
rescue LoadError
  # client-only usage
end

require_relative "web/helpers"

module SidekiqUniqueJobs
  # Utility module to help manage unique keys in redis.
  # Useful for deleting keys that for whatever reason wasn't deleted
  #
  # @author Mikael Henriksson <mikael@zoolutions.se>
  module Web
    def self.registered(app) # rubocop:disable Metrics/MethodLength
      app.helpers do
        include Web::Helpers
      end

      app.get "/unique_digests" do
        @filter         = params[:filter] || "*"
        @filter         = "*" if @filter == ""
        @count          = (params[:count] || 100).to_i
        @current_cursor = params[:cursor]
        @prev_cursor    = params[:prev_cursor]
        @total_size, @next_cursor, @unique_digests =
          SidekiqUniqueJobs::Digests.page(pattern: @filter, cursor: @current_cursor, page_size: @count)

        erb(unique_template(:unique_digests))
      end

      app.get "/unique_digests/delete_all" do
        SidekiqUniqueJobs::Digests.delete_by_pattern("*", count: SidekiqUniqueJobs::Digests.count)
        redirect_to :unique_digests
      end

      app.get "/unique_digests/:digest" do
        @digest = params[:digest]
        @unique_keys = SidekiqUniqueJobs::Util.keys("#{@digest}*", 1000)

        erb(unique_template(:unique_digest))
      end

      app.get "/unique_digests/:digest/delete" do
        SidekiqUniqueJobs::Digests.delete_by_digest(params[:digest])
        redirect_to :unique_digests
      end
    end
  end
end

if defined?(Sidekiq::Web)
  Sidekiq::Web.register SidekiqUniqueJobs::Web
  Sidekiq::Web.tabs["Unique Digests"] = "unique_digests"
  # Sidekiq::Web.settings.locales << File.join(File.dirname(__FILE__), 'locales')
end
