require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class OfferDocument

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end

    def generate(path, data)
      coder = HTMLEntities.new

      language = select_language(data)
      template_path = select_template(data, language)
      html = File.open(template_path, 'rb') { |file| file.read }

      offer_date = generate_offer_date(data)
      html.gsub! '<!-- {{DATE}} -->', offer_date

      own_reference = coder.encode(generate_own_reference(data), :named)
      html.gsub! '<!-- {{OWN_REFERENCE}} -->', own_reference

      ext_reference = coder.encode(generate_ext_reference(data), :named)
      html.gsub! '<!-- {{EXT_REFERENCE}} -->', ext_reference

      building = coder.encode(generate_building(data), :named)
      html.gsub! '<!-- {{BUILDING}} -->', building

      contactlines = coder.encode(generate_contactlines(data), :named)
      html.gsub! '<!-- {{CONTACTLINES}} -->', contactlines

      addresslines = coder.encode(generate_addresslines(data), :named)
      html.gsub! '<!-- {{ADDRESSLINES}} -->', addresslines

      html.gsub! '<!-- {{INTRO}} -->', coder.encode(data['documentIntro'], :named) if data['documentIntro']

      offerlines = coder.encode(generate_offerlines(data, language), :named)
      html.gsub! '<!-- {{OFFERLINES}} -->', offerlines

      html.gsub! '<!-- {{CONDITIONS}} -->', coder.encode(data['documentOutro'], :named) if data['documentOutro']

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      header_path = select_header(data, language)
      header_html = if header_path then File.open(header_path, 'rb') { |file| file.read } else '' end
      header_html.gsub! '<!-- {{HEADER_REFERENCE}} -->', generate_header_reference(data)

      footer_path = select_footer(data, language)
      footer_html = if footer_path then File.open(footer_path, 'rb') { |file| file.read } else '' end

      document_title = document_title(data, language)

      write_to_pdf(path, html, header: { content: header_html }, footer: { content: footer_html }, title: document_title)
    end

    def select_header(data, language)
      if language == 'FRA'
        ENV['OFFER_HEADER_TEMPLATE_FR'] || '/templates/offerte-header-fr.html'
      else
        ENV['OFFER_HEADER_TEMPLATE_NL'] || '/templates/offerte-header-nl.html'
      end
    end

    def select_template(data, language)
      if language == 'FRA'
        ENV['OFFER_TEMPLATE_FR'] || '/templates/offerte-fr.html'
      else
        ENV['OFFER_TEMPLATE_NL'] || '/templates/offerte-nl.html'
      end
    end

    def document_title(data, language)
      reference = generate_header_reference(data)
      document_type = if language == 'FRA' then 'Offre' else 'Offerte' end
      "#{document_type} #{reference}"
    end

    def generate_offer_date(data)
      if data['offerDate'] then format_date(data['offerDate']) else '' end
    end

    def generate_offerlines(data, language)
      offer_uri = get_resource_uri('offers', data['id'])

      query = " PREFIX schema: <http://schema.org/>"
      query += " PREFIX dct: <http://purl.org/dc/terms/>"
      query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
      query += " PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>"
      query += " SELECT ?description ?amount ?vatCode ?rate"
      query += " WHERE {"
      query += "   GRAPH <http://mu.semte.ch/graphs/rollvolet> {"
      query += "     ?offerline a crm:Offerline ;"
      query += "       dct:isPartOf <#{offer_uri}> ;"
      query += "       dct:description ?description ;"
      query += "       schema:amount ?amount ;"
      query += "       price:hasVatRate ?vatRate ;"
      query += "       schema:position ?position ."
      query += "   }"
      query += "   GRAPH <http://mu.semte.ch/graphs/public> {"
      query += "     ?vatRate a price:VatRate ;"
      query += "       schema:value ?rate ;"
      query += "       schema:identifier ?vatCode ."
      query += "   }"
      query += " } ORDER BY ?position"

      solutions = Mu.query(query)

      offerlines = solutions.map do |offerline|
        line = "<div class='offerline'>"
        line += "  <div class='col col-1'>#{offerline[:description]}</div>"
        line += "  <div class='col col-2'>&euro; #{format_decimal(offerline[:amount])}</div>"

        vat_note_css_class = ''
        vat_rate = "#{format_vat_rate(offerline[:rate])}%"
        if offerline[:vatCode] == 'm'
          vat_rate = ''
          vat_note_css_class = if language == 'FRA' then 'taxfree-fr' else 'taxfree-nl' end
        end
        line += "  <div class='col col-3 #{vat_note_css_class}'>#{vat_rate}</div>"
        line += "</div>"
        line
      end
      offerlines.join
    end

    def generate_own_reference(data)
      request = data['request']
      if request
        own_reference = "<b>AD #{format_request_number(request['id'])}</b>"
        visit = request['visit']
        own_reference += " <b>#{visit['visitor']}</b>" if visit and visit['visitor']
        version = if data['documentVersion'] == 'v1' then '' else data['documentVersion'] end
        own_reference += "<br><span class='note'>#{data['number']} #{version}</span>"
      else
        hide_element('references--own_reference')
      end
    end

    def generate_header_reference(data)
      request = data['request']
      if request
        reference = "AD #{format_request_number(request['id'])}"
        visit = request['visit']
        reference += " #{visit['visitor']}" if visit and visit['visitor']
        reference
      else
        ''
      end
    end
  end
end
