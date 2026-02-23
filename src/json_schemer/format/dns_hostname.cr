require "../dns_resolver"
require "../format"

module JsonSchemer
  module Format
    # A format validator that checks hostnames using DNS resolution.
    #
    # It performs a syntax check first, then a DNS lookup.
    # If the DNS lookup fails due to network errors, it falls back to the syntax check result.
    # If the DNS lookup confirms the domain does not exist (NXDOMAIN), it returns false.
    #
    # Usage:
    #
    # ```
    # validator = DnsHostnameValidator.new(ttl: 10.minutes)
    # JsonSchemer.schema(..., formats: {"hostname" => validator.to_proc})
    # ```
    class DnsHostnameValidator
      @resolver : DnsResolver

      def initialize(resolver : DnsResolver)
        @resolver = resolver
      end

      def initialize(ttl : Time::Span = 60.minutes)
        @resolver = DnsResolver.new(ttl)
      end

      # Validates the hostname using DNS.
      # Matches the `Format::FormatValidator` proc signature.
      def call(instance : JSON::Any, format : String) : Bool
        # 1. Check if it's a string
        return true unless instance.as_s?
        hostname = instance.as_s

        # 2. Validate syntax first (regex/length/IDN)
        # This uses the same logic as the default "hostname" validator
        return false unless Format.valid_hostname?(hostname)

        # 3. Perform DNS lookup
        case @resolver.resolve(hostname)
        when DnsResolver::DnsResult::Found
          true
        when DnsResolver::DnsResult::NotFound
          # Domain definitely does not exist
          false
        when DnsResolver::DnsResult::Error
          # DNS lookup failed (network error, timeout, etc.)
          # Fallback to syntax validation (which already passed at step 2)
          true
        else
          true
        end
      end

      # Returns a proc that can be used as a format validator.
      def to_proc : FormatValidator
        ->call(JSON::Any, String)
      end
    end
  end
end
