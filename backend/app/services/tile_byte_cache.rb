require "digest"

class TileByteCache
  DEFAULT_TTL = 3600
  MAX_BYTES = 5 * 1024 * 1024
  NAMESPACE = "tile-bytes-v1"
  INVALIDATION_STATUSES = %w[pending submitted completed failed].freeze
  COUNTERS = %i[
    hits misses bypasses disabled_bypasses writes write_failures uncacheable_responses
    bytes_served bytes_written errors read_errors write_errors connection_errors capacity_errors
  ].freeze

  class << self
    def configured?
      ENV["TILE_CACHE_REDIS_URL"].present?
    end

    def startup_state
      configured? ? "configured (lazy connection)" : "disabled (TILE_CACHE_REDIS_URL is unset)"
    end

    def stats
      counters = stats_mutex.synchronize do
        @stats ||= Hash.new(0)
        COUNTERS.to_h { |name| [name.to_s, @stats.fetch(name, 0)] }
      end
      {
        "enabled" => configured?,
        "scope" => "process",
        "counters" => counters,
        "capacity" => capacity_stats,
        "invalidations" => invalidation_counts
      }
    end

    def key(parts = nil, **keywords)
      parts ||= keywords
      return if parts.blank?

      Digest::SHA256.hexdigest(JSON.generate(canonicalize(parts)))
    end

    def fetch(cache_key, bypass: false, expires_in: DEFAULT_TTL)
      if bypass || cache_key.blank?
        record(:bypasses)
        return yield
      end
      unless configured?
        record(:disabled_bypasses)
        return yield
      end

      cache = store
      cached = cache_read(cache, cache_key)
      if cached
        record(:hits)
        record(:bytes_served, cached[:body].bytesize) if cached[:body].is_a?(String)
        Rails.logger.info("[TileByteCache] hit")
        return cached
      end

      record(:misses)
      Rails.logger.info("[TileByteCache] miss")
      value = yield
      if cacheable?(value)
        cache_write(cache, cache_key, value, expires_in)
      else
        record(:uncacheable_responses)
      end
      value
    end

    def reset!
      @store = nil
      stats_mutex.synchronize { @stats = Hash.new(0) }
    end

    private

    def stats_mutex
      @stats_mutex ||= Mutex.new
    end

    def record(counter, amount = 1)
      stats_mutex.synchronize do
        @stats ||= Hash.new(0)
        @stats[counter] += amount
      end
    end

    def invalidation_counts
      counts = INVALIDATION_STATUSES.to_h { |status| [status, 0] }
      return counts unless defined?(TileCacheInvalidation) && TileCacheInvalidation.table_exists?

      counts.merge(TileCacheInvalidation.group(:status).count.slice(*INVALIDATION_STATUSES))
    rescue => e
      Rails.logger.error("[TileByteCache] invalidation stats unavailable: #{e.class}")
      counts
    end

    def capacity_stats
      capacity = {
        "max_tile_bytes" => MAX_BYTES,
        "max_ttl_seconds" => DEFAULT_TTL,
        "redis_available" => false,
        "redis_used_bytes" => nil,
        "redis_max_bytes" => nil,
        "redis_key_count" => nil
      }
      return capacity unless configured?

      cache = store
      return capacity unless cache.respond_to?(:stats)

      info = cache.stats
      return capacity unless info.is_a?(Hash)

      max_memory = info["maxmemory"].to_i
      databases = info.sum do |name, details|
        name.match?(/\Adb\d+\z/) ? details.to_s[/\bkeys=(\d+)/, 1].to_i : 0
      end
      capacity.merge(
        "redis_available" => true,
        "redis_used_bytes" => info["used_memory"].to_i,
        "redis_max_bytes" => (max_memory.positive? ? max_memory : nil),
        "redis_key_count" => databases
      )
    rescue => e
      record(:errors)
      record(:capacity_errors)
      Rails.logger.error("[TileByteCache] capacity stats unavailable: #{e.class}")
      capacity
    end

    def store
      @store ||= ActiveSupport::Cache::RedisCacheStore.new(
        url: ENV.fetch("TILE_CACHE_REDIS_URL"),
        namespace: NAMESPACE,
        error_handler: ->(method:, returning:, exception:) {
          record(:errors)
          record(:read_errors) if method.to_s.include?("read")
          record(:write_errors) if method.to_s.include?("write")
          Rails.logger.error("[TileByteCache] Redis #{method} failed: #{exception.class}")
        }
      )
    rescue => e
      record(:errors)
      record(:connection_errors)
      Rails.logger.error("[TileByteCache] Redis store unavailable: #{e.class}")
      NullStore.new
    end

    def cache_read(cache, key)
      cache.read(key)
    rescue => e
      record(:errors)
      record(:read_errors)
      Rails.logger.error("[TileByteCache] read failed: #{e.class}")
      nil
    end

    def cache_write(cache, key, value, expires_in)
      written = cache.write(key, value, expires_in: [expires_in.to_i, DEFAULT_TTL].min.clamp(1, DEFAULT_TTL))
      if written
        record(:writes)
        record(:bytes_written, value[:body].bytesize)
      else
        record(:write_failures)
      end
    rescue => e
      record(:errors)
      record(:write_errors)
      Rails.logger.error("[TileByteCache] write failed: #{e.class}")
    end

    def cacheable?(value)
      value.is_a?(Hash) &&
        value[:status].to_i == 200 &&
        value[:body].is_a?(String) &&
        value[:body].bytesize.between?(1, MAX_BYTES)
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.map(&:to_s).sort.to_h do |key|
          original_key = value.key?(key) ? key : key.to_sym
          [key, canonicalize(value[original_key])]
        end
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end

    Rails.application.config.after_initialize do
      Rails.logger.info("[TileByteCache] #{TileByteCache.startup_state}")
    end

    class NullStore
      def read(_key)
        nil
      end

      def write(*, **)
        false
      end
    end
  end
end
