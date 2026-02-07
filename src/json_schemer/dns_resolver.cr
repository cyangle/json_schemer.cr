require "socket"
require "mutex"
require "./lru_cache"

module JsonSchemer
  # A thread-safe DNS resolver with caching, thundering herd protection, stale-while-revalidate, and LRU eviction.
  #
  # Used for validating hostnames by checking for the existence of DNS records.
  # Uses striped locking to allow concurrent lookups for different hostnames
  # while synchronizing lookups for the same hostname.
  #
  # NOTE: By default, this uses Crystal's `Socket::Addrinfo`, which performs blocking
  # DNS lookups. In high-concurrency applications, this can block worker threads.
  # For non-blocking DNS resolution, it is highly recommended to use the
  # [spider-gazelle/dns](https://github.com/spider-gazelle/dns) shard, which
  # monkey-patches `Socket::Addrinfo` to be non-blocking.
  class DnsResolver
    # Result of a DNS lookup
    # - result: :found or :not_found (or :error in transient state)
    # - expires_at: When the entry is considered "expired" and should be refreshed (soft TTL)
    # - stale_at: When the entry is considered "dead" and cannot be used as fallback (hard TTL)
    private record CacheEntry,
      result : Symbol,
      expires_at : Time::Instant,
      stale_at : Time::Instant

    @cache : LRUCache(String, CacheEntry)
    @cache_mutex : Mutex

    # Striped locks for synchronizing DNS lookups per hostname
    STRIPE_SIZE = 64
    @locks : Array(Mutex)

    @ttl : Time::Span
    @not_found_ttl : Time::Span
    @stale_ttl : Time::Span
    getter timeout : Time::Span
    @max_cache_size : Int32

    # Creates a new DNS resolver.
    #
    # *ttl*: Time-to-live for successful lookups (default: 60 minutes). Soft TTL.
    # *not_found_ttl*: Time-to-live for NXDOMAIN results (default: 24 hours). Soft TTL.
    # *stale_ttl*: How long to keep using stale data if refresh fails/timeouts (default: 24 hours). Hard TTL.
    # *timeout*: Network timeout for DNS lookups (default: 10 seconds).
    # *max_cache_size*: Maximum number of entries to keep in the cache (default: 1000).
    def initialize(
      @ttl : Time::Span = 60.minutes,
      @not_found_ttl : Time::Span = 24.hours,
      @stale_ttl : Time::Span = 24.hours,
      @timeout : Time::Span = 10.seconds,
      @max_cache_size : Int32 = 1000,
    )
      @cache = LRUCache(String, CacheEntry).new(@max_cache_size)
      @cache_mutex = Mutex.new
      @locks = Array.new(STRIPE_SIZE) { Mutex.new }
    end

    # Resolves the hostname and returns the status:
    # - `:found`: Hostname exists.
    # - `:not_found`: Hostname does not exist.
    # - `:error`: DNS lookup failed (network error, timeout, etc.) and no stale fallback available.
    def resolve(hostname : String) : Symbol
      now = Time.instant

      # 1. Fast path: Check cache (global lock, very fast)
      if entry = get_cache(hostname)
        # If entry is fresh (not expired), return immediately
        return entry.result if entry.expires_at > now
      end

      # 2. Slow path: Synchronized lookup with thundering herd protection
      lock_for(hostname).synchronize do
        # 3. Double-check cache inside lock
        if entry = get_cache(hostname)
          return entry.result if entry.expires_at > now
        end

        # 4. Perform network lookup with timeout
        # If lookup fails or times out, we'll try to fallback to stale entry
        lookup_result = perform_lookup_with_timeout(hostname)

        case lookup_result
        when :timeout, :error
          # Network failure or timeout. Try to fallback to stale data.
          if (entry = get_cache(hostname)) && entry.stale_at > now
            # Return stale data. We do NOT update the cache, so next call will retry.
            return entry.result
          end
          # No usable stale data -> return error
          :error
        else
          # Successful lookup (found or not_found)
          # Determine soft TTL based on result
          result_ttl = (lookup_result == :not_found) ? @not_found_ttl : @ttl

          # Update cache with new result, soft TTL, and hard stale TTL
          set_cache(
            hostname,
            lookup_result,
            now + result_ttl,
            now + result_ttl + @stale_ttl
          )
          lookup_result
        end
      end
    end

    # Clear the entire cache
    def clear_cache
      @cache_mutex.synchronize do
        @cache.clear
      end
    end

    private def lock_for(hostname : String) : Mutex
      # Simple hash sharding to select a mutex
      index = (hostname.hash % STRIPE_SIZE).abs
      @locks[index]
    end

    private def get_cache(hostname : String) : CacheEntry?
      @cache_mutex.synchronize { @cache.get(hostname) }
    end

    private def set_cache(hostname : String, result : Symbol, expires_at : Time::Instant, stale_at : Time::Instant)
      @cache_mutex.synchronize do
        @cache.set(hostname, CacheEntry.new(result, expires_at, stale_at))
      end
    end

    private def delete_cache(hostname : String)
      @cache_mutex.synchronize { @cache.delete(hostname) }
    end

    # Performs lookup with a strict timeout using a fiber
    # Returns :found, :not_found, :error, or :timeout
    protected def perform_lookup_with_timeout(hostname : String) : Symbol
      # Use a buffered channel to prevent fiber leak if timeout happens
      channel = Channel(Symbol).new(1)

      spawn do
        # This runs in a separate fiber
        channel.send(perform_lookup(hostname))
      end

      select
      when result = channel.receive
        result
      when timeout(@timeout)
        :timeout
      end
    end

    protected def perform_lookup(hostname : String) : Symbol
      begin
        # Note: This is a blocking operation unless `spider-gazelle/dns` is required
        # with its monkey-patching enabled (`require "dns/ext/addrinfo"`).
        addresses = Socket::Addrinfo.resolve(
          hostname,
          nil,
          family: Socket::Family::UNSPEC,
          type: Socket::Type::STREAM
        )
        addresses.empty? ? :not_found : :found
      rescue ex : Socket::Error
        # Check for NXDOMAIN or "No address found"
        msg = ex.message || ""
        if msg.includes?("No address found") || msg.includes?("Name or service not known") || ex.os_error == -2
          :not_found
        else
          :error
        end
      rescue
        :error
      end
    end
  end
end
