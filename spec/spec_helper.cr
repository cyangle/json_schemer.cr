require "spec"
require "../src/json_schemer"

# Helper to get errors array from validation result
def get_errors(result : Hash(String, JSON::Any)) : Array(Hash(String, JSON::Any))
  if errors = result["errors"]?
    errors.as_a.map { |e| e.as_h.transform_values { |v| v } }
  else
    [] of Hash(String, JSON::Any)
  end
end
