module JsonSchemer
  module Draft202012
    ID       = "https://json-schema.org/draft/2020-12/schema"
    BASE_URI = URI.parse(ID)

    FORMATS = {
      "date-time"             => Format::DATE_TIME,
      "date"                  => Format::DATE,
      "time"                  => Format::TIME,
      "duration"              => Format::DURATION,
      "email"                 => Format::EMAIL,
      "idn-email"             => Format::IDN_EMAIL,
      "hostname"              => Format::HOSTNAME,
      "idn-hostname"          => Format::IDN_HOSTNAME,
      "ipv4"                  => Format::IPV4,
      "ipv6"                  => Format::IPV6,
      "uri"                   => Format::URI_FORMAT,
      "uri-reference"         => Format::URI_REFERENCE,
      "iri"                   => Format::IRI,
      "iri-reference"         => Format::IRI_REFERENCE,
      "uuid"                  => Format::UUID_FORMAT,
      "uri-template"          => Format::URI_TEMPLATE,
      "json-pointer"          => Format::JSON_POINTER,
      "relative-json-pointer" => Format::RELATIVE_JSON_POINTER,
      "regex"                 => Format::REGEX,
    } of String => Format::FormatValidator

    CONTENT_ENCODINGS = {
      "base64" => Content::BASE64,
    } of String => Content::ContentEncodingValidator

    CONTENT_MEDIA_TYPES = {
      "application/json" => Content::JSON_MEDIA_TYPE,
    } of String => Content::ContentMediaTypeValidator

    SCHEMA = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/schema.json") }})

    module Meta
      CORE                     = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/core.json") }})
      APPLICATOR               = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/applicator.json") }})
      UNEVALUATED              = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/unevaluated.json") }})
      VALIDATION               = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/validation.json") }})
      META_DATA_SCHEMA         = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/meta-data.json") }})
      FORMAT_ANNOTATION_SCHEMA = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/format-annotation.json") }})
      FORMAT_ASSERTION_SCHEMA  = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/format-assertion.json") }})
      CONTENT_SCHEMA           = JSONHash.from_json({{ read_file("#{__DIR__}/../../../data/jss/draft/2020-12/meta/content.json") }})

      SCHEMAS = {
        URI.parse("https://json-schema.org/draft/2020-12/meta/core")              => CORE,
        URI.parse("https://json-schema.org/draft/2020-12/meta/applicator")        => APPLICATOR,
        URI.parse("https://json-schema.org/draft/2020-12/meta/unevaluated")       => UNEVALUATED,
        URI.parse("https://json-schema.org/draft/2020-12/meta/validation")        => VALIDATION,
        URI.parse("https://json-schema.org/draft/2020-12/meta/meta-data")         => META_DATA_SCHEMA,
        URI.parse("https://json-schema.org/draft/2020-12/meta/format-annotation") => FORMAT_ANNOTATION_SCHEMA,
        URI.parse("https://json-schema.org/draft/2020-12/meta/format-assertion")  => FORMAT_ASSERTION_SCHEMA,
        URI.parse("https://json-schema.org/draft/2020-12/meta/content")           => CONTENT_SCHEMA,
      } of URI => JSONHash

      SCHEMAS_RESOLVER = ->(uri : URI) : JSONHash? {
        SCHEMAS[uri]?
      }
    end
  end
end
