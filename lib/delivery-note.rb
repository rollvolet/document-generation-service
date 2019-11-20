require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class DeliveryNote

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end

    def generate(path, data)
      coder = HTMLEntities.new

      language = select_language(data)
      template_path = select_template(data, language)
      html = File.open(template_path, 'rb') { |file| file.read }

      date = format_date_object(DateTime.now)
      html.gsub! '<!-- {{DATE}} -->', date

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

      deliverylines = coder.encode(generate_deliverylines(data, language), :named)
      html.gsub! '<!-- {{DELIVERYLINES}} -->', deliverylines

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      header_path = select_header(data, language)
      header_html = if header_path then File.open(header_path, 'rb') { |file| file.read } else '' end
      header_html.gsub! '<!-- {{HEADER_REFERENCE}} -->', generate_header_reference(data)

      footer_path = select_footer(data, language)
      footer_html = if footer_path then File.open(footer_path, 'rb') { |file| file.read } else '' end

      document_title = document_title(data, language)

      write_to_pdf(path, html, header_html, footer_html, document_title)
    end

    def select_header(data, language)
      if language == 'FRA'
        ENV['DELIVERY_NOTE_HEADER_TEMPLATE_FR'] || '/templates/leveringsbon-header-fr.html'
      else
        ENV['DELIVERY_NOTE_HEADER_TEMPLATE_NL'] || '/templates/leveringsbon-header-nl.html'
      end
    end

    def select_template(data, language)
      if language == 'FRA'
        ENV['DELIVERY_NOTE_TEMPLATE_FR'] || '/templates/leveringsbon-fr.html'
      else
        ENV['DELIVERY_NOTE_TEMPLATE_NL'] || '/templates/leveringsbon-nl.html'
      end
    end

    def document_title(data, language)
      reference = generate_header_reference(data)
      document_type = if language == 'FRA' then 'Bon de livraison' else 'Leveringsbon' end
      "#{document_type} #{reference}"
    end

    def generate_deliverylines(data, language)
      # Offerlines have already been filtered on 'isOrdered' by the backend API
      deliverylines = data['offer']['offerlines'].map do |offerline|
        line = "<div class='offerline'>"
        line += "  <div class='col col-1'>#{offerline['description']}</div>"
        line += "</div>"
        line
      end
      deliverylines.join
    end

    def generate_own_reference(data)
      request = data['offer']['request']
      if request
        own_reference = "<b>AD #{request['id']}</b>"
        visit = request['visit']
        own_reference += " <b>#{visit['visitor']}</b>" if visit and visit['visitor']
        own_reference += "<br><span class='note'>#{data['offerNumber']}</span>"
      else
        hide_element('references--own_reference')
      end
    end

    def generate_header_reference(data)
      request = data['offer']['request']
      if request
        reference = "AD #{request['id']}"
        visit = request['visit']
        reference += " #{visit['visitor']}" if visit and visit['visitor']
        reference
      else
        ''
      end
    end
  end
end
