require "srp/api"
require "active_support"
require "active_support/isolated_execution_state" # See https://github.com/rails/rails/issues/43851
require "active_support/core_ext/numeric/time"
require_relative "../redis_cache"

module GitHub
  class Client
    include Srp::Api::Client

    CACHE_TTL = 10.seconds

    def initialize(token: nil, cache: nil, redis_pool: nil)
      @token = token || ENV.fetch("GITHUB_TOKEN")
      @cache = cache || RedisCache.new(redis_pool: redis_pool)
    end

    def runs(group:, repo:, workflow:)
      uri = URI("https://api.github.com/repos/#{group}/#{repo}/actions/workflows/#{workflow}/runs")

      cached_data = cache.read(uri.to_s)
      fresh?(cached_data) ? cached_data["runs"] : fetch_runs(uri, cached_data)
    end

    private

    attr_reader :token, :cache

    def fresh?(cached_data)
      if (cache_until = cached_data&.fetch("until", nil))
        Time.current < Time.parse(cache_until)
      end
    end

    def fetch_runs(uri, cached_data)
      runs = cached_data&.fetch("runs", nil)
      etag = cached_data&.fetch("etag", nil)
      response = request(:get, uri, headers: {"If-None-Match": etag})

      if status_changed?(response)
        runs = JSON.parse(response)
        etag = response.headers["ETag"]
      end

      cache_until = (Time.current + CACHE_TTL).iso8601
      cache.write(uri.to_s, {etag: etag, runs: runs, until: cache_until})

      runs
    end

    def request(method, uri, headers: {})
      response = HTTP
        .headers({accept: "application/json"}.merge(headers))
        .basic_auth(user: nil, pass: token)
        .request(method, uri)

      check_for_errors!(response, method, uri)
      response
    end

    def status_changed?(response)
      response.code != 304
    end
  end
end
