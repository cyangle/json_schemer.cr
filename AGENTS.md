# AGENTS.md - Agent Guidelines for json_schemer.cr

This is a Crystal port of the Ruby [json_schemer](https://github.com/davishmcclurg/json_schemer) library.
It implements JSON Schema validation according to Draft 2020-12 and OpenAPI 3.1 specifications.

## Build & Test Commands

```bash
# Install dependencies
shards install

# Run all tests
crystal spec

# Run a single test file
crystal spec spec/json_schemer_spec.cr

# Run tests matching a pattern/example name
crystal spec -e "validates type: string"

# Run test at a specific file:line
crystal spec --location spec/json_schemer_spec.cr:32

# Run tests with verbose output
crystal spec -v

# Run with fail-fast (stop on first failure)
crystal spec --fail-fast

# Type-check without running (faster feedback)
crystal build --no-codegen src/json_schemer.cr

# Format code
crystal tool format

# Check format without modifying
crystal tool format --check
```

## Project Structure

```
src/
  json_schemer.cr              # Main entry point, module-level API
  json_schemer/
    version.cr                 # Version constant
    schema.cr                  # Core Schema class for validation
    keyword.cr                 # Abstract base class for all keywords
    result.cr                  # Validation result structure
    output.cr                  # Output formatting module
    errors.cr                  # Error classes hierarchy
    configuration.cr           # Configuration options
    format.cr                  # Format validators (email, uri, etc.)
    content.cr                 # Content encoding/media type validators
    ecma_regexp.cr             # ECMA-262 regexp compatibility
    resources.cr               # Schema resource management
    location.cr                # JSON pointer location handling
    cached_resolver.cr         # Cached ref/regexp resolvers
    draft202012/
      vocab/                   # Vocabulary implementations
        core.cr                # $schema, $id, $ref, $anchor, $defs
        validation.cr          # type, enum, const, min/max, etc.
        applicator.cr          # allOf, anyOf, oneOf, if/then/else
        unevaluated.cr         # unevaluatedItems, unevaluatedProperties
        format_annotation.cr   # Format as annotation (default)
        format_assertion.cr    # Format as assertion
        content.cr             # contentEncoding, contentMediaType
        meta_data.cr           # title, description, default, etc.
      vocab.cr                 # Vocabulary registration
      meta.cr                  # Meta schema definitions
    openapi31/                 # OpenAPI 3.1 support
      vocab/
        base.cr                # OpenAPI 3.1 base vocabulary keywords
      vocab.cr                 # OpenAPI vocabulary registration
      meta.cr                  # OpenAPI meta schema definitions
      document.cr              # OpenAPI document validation
    openapi.cr                 # OpenAPI document handler
spec/
  spec_helper.cr               # Shared test setup
  json_schemer_spec.cr         # Main test suite
  format_spec.cr               # Format validation tests
  ref_spec.cr                  # $ref resolution tests
  hooks_spec.cr                # Validation hooks tests
  openapi_spec.cr              # OpenAPI validation tests
  pointers_spec.cr             # JSON pointer tests
  regex_spec.cr                # Regex pattern tests
  output_format_spec.cr        # Output format tests
  json_schema_test_suite_spec.cr  # JSON Schema Test Suite integration
```

## Code Style Guidelines

### Formatting
- **Indentation**: 2 spaces (no tabs)
- **Line endings**: LF (Unix-style)
- **Trailing whitespace**: Remove
- **Final newline**: Required
- Use `crystal tool format` to auto-format

### Imports/Requires
- Standard library requires first (`json`, `uri`, `big`, `socket`, `http/client`, `base64`)
- External dependencies second (`hana`, `simpleidn`)
- Internal requires in dependency order
- Group requires logically (see `src/json_schemer.cr`)

```crystal
require "json"
require "uri"
require "big"
require "socket"
require "http/client"
require "base64"

require "hana"
require "simpleidn"

require "./json_schemer/version"
require "./json_schemer/errors"
# ... etc
```

### Naming Conventions
- **Classes/Modules**: `PascalCase` (e.g., `Schema`, `Keyword`, `DynamicRef`)
- **Methods/Variables**: `snake_case` (e.g., `validate_instance`, `keyword_location`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `VOCABULARIES`, `DEFAULT_REF_RESOLVER`)
- **Type aliases**: `PascalCase` (e.g., `JSONHash`)
- **Keyword classes**: Match JSON Schema keyword name in PascalCase
  - `$ref` -> `Ref`
  - `$dynamicAnchor` -> `DynamicAnchor`
  - `additionalProperties` -> `AdditionalProperties`

### Type Annotations
- Always annotate method return types for public methods
- Use union types for nullable values: `Schema | Nil` or `Schema?`
- Use the `JSONHash` type alias for JSON object types:
  ```crystal
  alias JSONHash = Hash(String, JSON::Any)
  ```

### Error Handling
- Define custom error classes inheriting from `Error < Exception`
- Use descriptive error names: `UnknownRef`, `InvalidRefPointer`, `InvalidEcmaRegexp`
- Raise with context: `raise UnknownRef.new(uri.to_s)`
- Use `not_nil!` sparingly - prefer safe navigation or guards

Available error classes:
- `Error` - Base error class
- `UnsupportedOpenAPIVersion`
- `UnknownRef`
- `UnknownFormat`
- `UnknownVocabulary`
- `UnknownContentEncoding`
- `UnknownContentMediaType`
- `UnknownOutputFormat`
- `InvalidRefResolution`
- `InvalidRefPointer`
- `InvalidRegexpResolution`
- `InvalidFileURI`
- `InvalidEcmaRegexp`

### Keyword Implementation Pattern
All JSON Schema keywords inherit from `Keyword`:

```crystal
class MyKeyword < Keyword
  # Override parse to process the keyword value during initialization
  # Return type is a union of possible parsed values
  protected def parse : JSON::Any | Schema | Array(Schema) | Hash(String, Schema) | Hash(String, Schema | Array(String)) | Regex | Nil
    # Parse and return structured data
    value  # Default: return raw value
  end

  # Override validate to perform validation
  def validate(
    instance : JSON::Any,
    instance_location : Location::Node,
    keyword_location : Location::Node,
    context : Schema::Context
  ) : Result?
    # Perform validation, return result
    valid = # ... your validation logic
    result(instance, instance_location, keyword_location, valid)
  end

  # Override error for custom error messages
  def error(formatted_instance_location : String, details : Hash(String, JSON::Any)? = nil) : String
    "value at #{formatted_instance_location} failed validation"
  end
end
```

### Result Creation
Use the `result` method from `Output` module:

```crystal
result(instance, instance_location, keyword_location, valid,
  nested: nested_results,      # Optional: child results
  type: "keyword_name",        # Optional: for classic output
  details: {"key" => value}    # Optional: additional context
)
```

### Test Structure
Tests use Crystal's built-in `spec` framework:

```crystal
require "./spec_helper"

describe "Feature" do
  describe ".method_name" do
    it "does something specific" do
      schema = JsonSchemer.schema(JSON.parse(%q({"type": "string"})).as_h)
      schema.valid?(JSON::Any.new("hello")).should be_true
      schema.valid?(JSON::Any.new(42_i64)).should be_false
    end
  end
end
```

Helper function available from `spec_helper.cr`:
```crystal
# Extract errors array from validation result
get_errors(result : Hash(String, JSON::Any)) : Array(Hash(String, JSON::Any))
```

### Common Patterns

**Creating schemas from various inputs**:
```crystal
# From Hash
JsonSchemer.schema({"type" => JSON::Any.new("string")} of String => JSON::Any)

# From JSON string
JsonSchemer.schema(%q({"type": "string"}))

# From parsed JSON
JsonSchemer.schema(JSON.parse(%q({"type": "object"})).as_h)

# From file path (enables relative $ref resolution)
JsonSchemer.schema(Path.new("schemas/my_schema.json"))
```

**Type guards in validation**:
```crystal
def validate(instance, instance_location, keyword_location, context)
  unless instance.raw.is_a?(String)
    return result(instance, instance_location, keyword_location, true)
  end
  # String-specific validation...
end
```

**Creating subschemas**:
```crystal
protected def parse
  result = {} of String => Schema
  value.as_h.each do |key, subschema_value|
    result[key] = subschema(subschema_value, key)
  end
  result
end
```

## Dependencies
- **hana**: JSON Pointer implementation (github: cyangle/hana.cr, >= 0.1.0)
- **simpleidn**: IDN/Punycode support for hostname validation (github: cyangle/simpleidn.cr, >= 0.2.1)
- Crystal >= 1.18.2

## JSON Schema Test Suite Integration

The project includes integration tests using the official [JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite) as a git submodule.

### Location
```
JSON-Schema-Test-Suite/           # Git submodule
  tests/
    draft2020-12/                 # Draft 2020-12 tests (used by this project)
      *.json                      # Required keyword tests
      optional/
        *.json                    # Optional feature tests
        format/
          *.json                  # Format validation tests
  remotes/                        # Mock remote schemas for $ref tests
```

### Test Structure
Tests are generated at compile-time using Crystal macros. The spec file `spec/json_schema_test_suite_spec.cr` dynamically discovers and runs all test cases.

**Test categories:**
1. **Required tests** (`draft2020-12/*.json`) - Core keyword validation with `format: false`
2. **Optional tests** (`draft2020-12/optional/*.json`) - Optional features with `format: true`
3. **Format tests** (`draft2020-12/optional/format/*.json`) - Format validators with `format: true`

### Running Integration Tests
```bash
# Run all tests including JSON Schema Test Suite
crystal spec

# Run only the test suite integration tests
crystal spec spec/json_schema_test_suite_spec.cr

# Run a specific keyword test
crystal spec -e "type.json"
```

### Skipped Tests
Some tests are skipped due to Crystal/implementation limitations:

| File | Reason |
|------|--------|
| `bignum.json` | Crystal's `JSON.parse` uses `Int64`; integers > `Int64.MAX` cause overflow |
| `cross-draft.json` | References Draft 2019-09 which is not implemented |

### IDN Hostname Edge Cases
Some `idn-hostname.json` and `hostname.json` tests are skipped due to UTS#46 vs IDNA2008 differences:
- Tests involving `U+302E` (Hangul single dot tone mark)
- Tests for "Exceptions that are DISALLOWED" characters

ICU/simpleidn uses UTS#46 which maps/allows some characters that strict IDNA2008 disallows.

### Remote Schema Resolution
The test suite uses a custom `CachedRefResolver` that maps remote refs to local files:
- `http://localhost:1234/foo.json` → `JSON-Schema-Test-Suite/remotes/foo.json`

### Updating the Test Suite
```bash
# Update the git submodule to latest
git submodule update --remote JSON-Schema-Test-Suite
```

## Important Notes

1. **JSON::Any everywhere**: Instance values and schema values are `JSON::Any`
2. **JSONHash type alias**: Use `JSONHash` (alias for `Hash(String, JSON::Any)`) for schema objects
3. **BigDecimal for precision**: Use `BigDecimal` for numeric comparisons (multipleOf)
4. **Location tracking**: Use `Location` module for JSON pointer paths
5. **Lazy initialization**: Use `@field ||= ...` pattern for cached values
6. **Draft 2020-12 default**: Format validation is annotation-only by default
7. **ECMA regexp**: Use `regexp_resolver: "ecma"` for JavaScript-compatible patterns
8. **OpenAPI 3.1 support**: Use `JsonSchemer.openapi(document)` for OpenAPI document validation
