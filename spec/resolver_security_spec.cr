require "./spec_helper"

describe "Resolver Security" do
  describe "FILE_URI_REF_RESOLVER" do
    it "prevents path traversal outside of base" do
      uri = URI.parse("file:///etc/passwd%2f..%2f..%2fetc%2fshadow")
      expect_raises(JsonSchemer::InvalidFileURI, /path traversal detected/) do
        JsonSchemer::FILE_URI_REF_RESOLVER.call(uri)
      end
    end

    it "prevents encoded dot-dot path traversal" do
      uri = URI.parse("file:///schemas/%2e%2e/%2e%2e/etc/passwd")
      expect_raises(JsonSchemer::InvalidFileURI, /path traversal detected/) do
        JsonSchemer::FILE_URI_REF_RESOLVER.call(uri)
      end
    end

    it "allows normal file paths" do
      uri = URI.parse("file:///tmp/does_not_exist_file.json")
      expect_raises(File::NotFoundError) do
        JsonSchemer::FILE_URI_REF_RESOLVER.call(uri)
      end
    end

    it "allows filenames containing double dots that are not path segments" do
      uri = URI.parse("file:///tmp/my..schema.json")
      expect_raises(File::NotFoundError) do
        JsonSchemer::FILE_URI_REF_RESOLVER.call(uri)
      end
    end
  end
end
