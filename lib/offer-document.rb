require 'wicked_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class OfferDocument < Document
    def initialize(*args, **keywords)
      super(*args, **keywords)
      @file_type = 'http://data.rollvolet.be/concepts/51577f19-9d90-4abf-a0d2-187770f76fc9'
    end

    def init_template request
      request_ref = generate_request_reference request

      if @language == 'FRA'
        template_path = ENV['OFFER_TEMPLATE_FR'] || '/templates/offerte-fr.html'
        header_path = ENV['OFFER_HEADER_TEMPLATE_FR'] || '/templates/offerte-header-fr.html'
        @document_title = "Offre #{request_ref}"
      else
        template_path = ENV['OFFER_TEMPLATE_NL'] || '/templates/offerte-nl.html'
        header_path = ENV['OFFER_HEADER_TEMPLATE_NL'] || '/templates/offerte-header-nl.html'
        @document_title = "Offerte #{request_ref}"
      end

      @html = File.open(template_path, 'rb') { |file| file.read }
      @header = if header_path then File.open(header_path, 'rb') { |f| f.read } else '' end
      footer_path = select_footer(nil, @language)
      @footer = if footer_path then File.open(footer_path, 'rb') { |f| f.read } else '' end
    end

    def generate
      offer = fetch_offer(@resource_id)
      _case = fetch_case(offer[:case_uri])
      request = fetch_request(_case[:request][:id]) if _case[:request]
      customer = fetch_customer(_case[:customer][:uri]) if _case[:customer]
      contact = fetch_contact(_case[:contact][:uri]) if _case[:contact]
      building = fetch_building(_case[:building][:uri]) if _case[:building]

      init_template(request)

      fill_placeholder('DATE', format_date(offer[:date]))

      own_reference = generate_offer_reference(offer, request)
      fill_placeholder('OWN_REFERENCE', own_reference, encode: true)

      ext_reference = generate_ext_reference(_case)
      fill_placeholder('EXT_REFERENCE', ext_reference, encode: true)

      building_lines = generate_address(building, 'building')
      fill_placeholder('BUILDING', building_lines, encode: true)

      contactlines = generate_contactlines(customer: customer, contact: contact)
      fill_placeholder('CONTACTLINES', contactlines, encode: true)

      addresslines = generate_address(customer)
      fill_placeholder('ADDRESSLINES', addresslines, encode: true)

      fill_placeholder('INTRO', offer[:document_intro], encode: true) if offer[:document_intro]
      fill_placeholder('CONDITIONS', offer[:document_outro], encode: true) if offer[:document_outro]

      offerlines = generate_offerlines(offer)
      fill_placeholder('OFFERLINES', offerlines, encode: true)

      upload_file offer[:uri]
      @path
    end

    def generate_offerlines(offer)
      solutions = fetch_offerlines(offer[:uri])

      offerlines = solutions.map do |offerline|
        line = "<div class='offerline'>"
        line += "  <div class='col col-1'>#{offerline[:description]}</div>"
        line += "  <div class='col col-2'>&euro; #{format_decimal(offerline[:amount])}</div>"

        vat_note_css_class = ''
        vat_rate = "#{format_vat_rate(offerline[:vat_rate])}%"
        if offerline[:vat_code] == 'm'
          vat_rate = ''
          vat_note_css_class = if @language == 'FRA' then 'taxfree-fr' else 'taxfree-nl' end
        end
        line += "  <div class='col col-3 #{vat_note_css_class}'>#{vat_rate}</div>"
        line += "</div>"
        line
      end
      offerlines.join
    end

    def generate_offer_reference(offer, request)
      own_reference = generate_own_reference(request: request)
      version = if offer[:document_version] == 'v1' then '' else offer[:document_version] end
      own_reference += "<br><span class='note'>#{offer[:number]} #{version}</span>"
      own_reference
    end
  end
end
