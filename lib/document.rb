require 'fileutils'
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

    def write_file path = @path
      write_to_pdf(
        path,
        @html,
        header: { content: @header },
        footer: { content: @footer },
        title: @document_title
      )
      path
    end

    def upload_file
      file_name = File.split(@path).last
      file_resource_uri = @path.gsub('/share/', 'share://')

      # Write PDF to a temporary location (such that it will not be picked up by file upload service yet)
      tmp_path = "/tmp/#{file_name}"
      write_file tmp_path

      # Insert file in triplestore
      upload_resource_uuid = Mu::generate_uuid()
      upload_resource_name = "#{@document_title.gsub(/\W/, "_")}.pdf"
      upload_resource_uri = get_resource_uri 'files', upload_resource_uuid
      file_extension = 'pdf'
      file_format = 'application/pdf'
      file_size = File.size(tmp_path)

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

      # Move PDF to final destination
      FileUtils.mv tmp_path, @path
    end

    ###
    ## Private
    ###
    def write_to_pdf(path, html, options = {})
      fill_placeholder('INLINE_CSS', @inline_css)

      default_options = {
        margin: {
          left: 0,
          top: 14, # top margin on each page
          bottom: 20, # height (mm) of the footer
          right: 0
        },
        disable_smart_shrinking: true,
        print_media_type: true,
        page_size: 'A4',
        orientation: 'Portrait',
        header: { content: '' },
        footer: { content: '' },
        delete_temporary_files: true
      }

      options = default_options.merge options

      pdf = WickedPdf.new.pdf_from_string(html, options)

      # Write HTML to a document for debugging purposes
      # html_path = path.sub '.pdf', '.html'
      # File.open(html_path, 'wb') { |file| file << html }
      File.open(path, 'wb') { |file| file << pdf }
    end

  end
end
