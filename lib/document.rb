require_relative './htmlentities'
require_relative './helpers'
require_relative './json-api-helpers'

module DocumentGenerator
  class Document
    include DocumentGenerator::Helpers
    include DocumentGenerator::JsonApiHelpers

    def initialize id:, language: nil, user:
      @inline_css = ''
      @header = ''
      @footer = ''
      @user = user
      @language = language
      @resource_id = id
      @file_id = "#{Mu::generate_uuid}"
      @path = "/share/#{@file_id}.pdf"
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

    def upload_file
      upload_resource_uuid = Mu::generate_uuid()
      upload_resource_name = "#{@document_title.gsub(/\W/, "_")}.pdf"
      upload_resource_uri = get_resource_uri 'files', upload_resource_uuid

      file_format = 'application/pdf'
      file_extension = 'pdf'
      file_size = File.size(@path)

      file_name = "#{@file_id}.pdf"
      file_resource_uri = "share://#{file_name}"

      now = DateTime.now

      Mu::update %{
        PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
        PREFIX nfo: <http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#>
        PREFIX dct: <http://purl.org/dc/terms/>
        PREFIX dbpedia: <http://dbpedia.org/ontology/>
        PREFIX nie: <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#>
        INSERT DATA {
          #{Mu::sparql_escape_uri(upload_resource_uri)} a nfo:FileDataObject ;
            mu:uuid #{upload_resource_uuid.sparql_escape} ;
            nfo:fileName #{upload_resource_name.sparql_escape} ;
            dct:format #{file_format.sparql_escape} ;
            nfo:fileSize #{Mu::sparql_escape_int(file_size)} ;
            dbpedia:fileExtension #{file_extension.sparql_escape} ;
            nfo:fileCreated #{now.sparql_escape} ;
            dct:creator #{sparql_escape_uri(@user)} ;
            dct:type #{sparql_escape_uri(@file_type)} .
          #{Mu::sparql_escape_uri(file_resource_uri)} a nfo:FileDataObject ;
            mu:uuid #{@file_id.sparql_escape} ;
            nie:dataSource #{Mu::sparql_escape_uri(upload_resource_uri)} ;
            nfo:fileName #{file_name.sparql_escape} ;
            dct:format #{file_format.sparql_escape} ;
            nfo:fileSize #{Mu::sparql_escape_int(file_size)} ;
            dbpedia:fileExtension #{file_extension.sparql_escape} ;
            nfo:fileCreated #{now.sparql_escape} ;
            dct:creator #{sparql_escape_uri(@user)} .
        }
      }
    end
  end
end
