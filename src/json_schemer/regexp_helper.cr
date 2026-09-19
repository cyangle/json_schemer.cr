module JsonSchemer
  # Helper module for regular expression operations with security handling.
  module RegexpHelper
    # Safely matches a string against a regular expression, catching backtracking and
    # JIT stack limits.
    #
    # Raises `RegexMatchLimitExceeded` if the match exceeds the PCRE backtracking limit.
    # PCRE2's JIT can exhaust its stack while matching long subjects; in that case the
    # match is retried with the JIT disabled so that valid input is not rejected.
    def self.matches?(regex : Regex, string : String) : Bool
      regex.matches?(string)
    rescue e : Regex::Error
      message = e.message || ""
      if message.includes?("JIT stack limit reached")
        match_without_jit(regex, string)
      elsif message.includes?("match limit exceeded")
        raise RegexMatchLimitExceeded.new(regex.source)
      else
        raise e
      end
    end

    private def self.match_without_jit(regex : Regex, string : String) : Bool
      regex.matches?(string, options: Regex::MatchOptions::NO_JIT)
    rescue e : Regex::Error
      if e.message.try(&.includes?("match limit exceeded"))
        raise RegexMatchLimitExceeded.new(regex.source)
      else
        raise e
      end
    end
  end
end
