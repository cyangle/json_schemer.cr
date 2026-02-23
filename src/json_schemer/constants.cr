module JsonSchemer
  # Shared constants used across modules

  # Regex for encoding URI fragments per RFC 3986
  # Characters that must be percent-encoded in fragment identifiers
  FRAGMENT_ENCODE_REGEX = /[^\w?\/:@\-.~!$&'()*+,;=]/
end
