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

    ###
    ## Writes the current state of the generator to a PDF document at the given path
    ###
    def write_file path = @path, options = {}
      options = options.merge({
        header: { content: @header },
        footer: { content: @footer },
        title: @document_title
      })
      write_to_pdf(
        path,
        @html,
        options
      )
      path
    end

    ###
    ## Writes the generated HTML to a PDF document,
    ## inserts it in the triplestore and moves it to the upload location
    ###
    def generate_and_upload_file derived_from = nil, pdf_generator_options = {}
      # Write PDF to a temporary location (such that it will not be picked up by file upload service yet)
      file_name = File.split(@path).last
      tmp_path = "/tmp/#{file_name}"
      write_file tmp_path, pdf_generator_options

      # Insert file in triplestore
      insert_file_in_triplestore tmp_path, derived_from

      # Move PDF to final destination
      FileUtils.mv tmp_path, @path
    end

    ###
    ## Inserts the file at the given path in the triplestore
    ## and moves it to the upload location
    ###
    def upload_file tmp_path, derived_from = nil
      # Insert file in triplestore
      insert_file_in_triplestore tmp_path, derived_from

      # Move PDF to final destination
      FileUtils.mv tmp_path, @path
    end


    ###
    ## PRIVATE METHODSy
    ###

    def insert_file_in_triplestore path, derived_from = nil
      file_resource_uri = @path.gsub('/share/', 'share://')

      upload_resource_uuid = Mu::generate_uuid()
      upload_resource_name = "#{@document_title.gsub(/\W/, "_")}.pdf"
      upload_resource_uri = get_resource_uri 'files', upload_resource_uuid
      file_extension = 'pdf'
      file_format = 'application/pdf'
      file_size = File.size(path)
      file_name = File.split(path).last

      now = DateTime.now

      derived_from_stmt =
        if derived_from
        then "#{Mu::sparql_escape_uri(upload_resource_uri)} prov:wasDerivedFrom #{Mu::sparql_escape_uri(derived_from)} ."
        else ''
        end

      Mu::update %{
        PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
        PREFIX nfo: <http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#>
        PREFIX dct: <http://purl.org/dc/terms/>
        PREFIX dbpedia: <http://dbpedia.org/ontology/>
        PREFIX nie: <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#>
        PREFIX prov: <http://www.w3.org/ns/prov#>
        INSERT DATA {
          #{Mu::sparql_escape_uri(upload_resource_uri)} a nfo:FileDataObject ;
            mu:uuid #{upload_resource_uuid.sparql_escape} ;
            nfo:fileName #{upload_resource_name.sparql_escape} ;
            dct:format #{file_format.sparql_escape} ;
            nfo:fileSize #{Mu::sparql_escape_int(file_size)} ;
            dbpedia:fileExtension #{file_extension.sparql_escape} ;
            nfo:fileCreated #{now.sparql_escape} ;
            dct:creator #{Mu::sparql_escape_uri(@user)} ;
            dct:type #{Mu::sparql_escape_uri(@file_type)} .
          #{derived_from_stmt}
          #{Mu::sparql_escape_uri(file_resource_uri)} a nfo:FileDataObject ;
            mu:uuid #{@file_id.sparql_escape} ;
            nie:dataSource #{Mu::sparql_escape_uri(upload_resource_uri)} ;
            nfo:fileName #{file_name.sparql_escape} ;
            dct:format #{file_format.sparql_escape} ;
            nfo:fileSize #{Mu::sparql_escape_int(file_size)} ;
            dbpedia:fileExtension #{file_extension.sparql_escape} ;
            nfo:fileCreated #{now.sparql_escape} ;
            dct:creator #{Mu::sparql_escape_uri(@user)} .
        }
      }
    end

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
      html_path = path.sub '.pdf', '.html'
      File.open(html_path, 'wb') { |file| file << html }
      File.open(path, 'wb') { |file| file << pdf }
    end

  end
end
