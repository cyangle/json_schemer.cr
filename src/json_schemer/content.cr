module JsonSchemer
  # Content encoding and media type handling
  module Content
    # Content encoding validator type
    alias ContentEncodingValidator = Proc(String, Tuple(Bool, String?))

    # Content media type validator type
    alias ContentMediaTypeValidator = Proc(String, Tuple(Bool, JSON::Any?))

    # Base64 content encoding
    BASE64 = ->(instance : String) {
      begin
        decoded = Base64.decode_string(instance)
        {true, decoded}
      rescue
        {false, nil}
      end
    }

    # JSON content media type
    JSON_MEDIA_TYPE = ->(instance : String) {
      begin
        parsed = JSON.parse(instance)
        {true, parsed}
      rescue
        {false, nil}
      end
    }
  end
end
