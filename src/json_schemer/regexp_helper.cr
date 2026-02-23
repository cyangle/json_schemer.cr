module JsonSchemer
  # Helper module for regular expression operations with security handling.
  module RegexpHelper
    # Safely matches a string against a regular expression, catching backtracking limits.
    #
    # Raises `RegexMatchLimitExceeded` if the match exceeds the PCRE backtracking limit.
    def self.matches?(regex : Regex, string : String) : Bool
      regex.matches?(string)
    rescue e : Regex::Error
      if e.message.try(&.includes?("match limit exceeded"))
        raise RegexMatchLimitExceeded.new(regex.source)
      else
        raise e
      end
    end
  end
end
