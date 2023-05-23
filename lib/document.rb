require_relative './htmlentities'
require_relative './helpers'
require_relative './json-api-helpers'

module DocumentGenerator
  class Document
    include DocumentGenerator::Helpers
    include DocumentGenerator::JsonApiHelpers

    def initialize id:, language:
      @inline_css = ''
      @language = language
      @resource_id = id
      @path = "/tmp/#{id}.pdf"
      @coder = HTMLEntities.new
    end

    def fill_placeholder placeholder, value, opts = {}
      encoded_value = if opts[:encode] then @coder.encode(value, :named) else value end
      template = if opts[:template] then opts[:template] else @html end
      template.gsub! "<!-- {{#{placeholder}}} -->", encoded_value
    end

    def write_file
      fill_placeholder('INLINE_CSS', @inline_css)
      write_to_pdf(@path, @html, header: { content: @header }, footer: { content: @footer }, title: @document_title)
      @path
    end
  end
end
