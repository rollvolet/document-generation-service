require 'wicked_pdf'
require 'combine_pdf'
require_relative './htmlentities'
require_relative './helpers'
require_relative './sparql_queries'

module DocumentGenerator
  class DeliveryNote

    include DocumentGenerator::Helpers

    def generate(path, data)
      id = data['id']
      path_supplier = "/tmp/#{id}-delivery-note-supplier.pdf"
      path_customer = "/tmp/#{id}-delivery-note-customer.pdf"

      language = select_language(data)

      @inline_css = ''
      generate_delivery_note(path_supplier, data, language, 'supplier')
      @inline_css = ''
      generate_delivery_note(path_customer, data, language, 'customer')

      merged_pdf = CombinePDF.new
      merged_pdf << CombinePDF.load(path_supplier)
      merged_pdf << CombinePDF.load(path_customer)

      document_title = document_title(data, language)
      merged_pdf.info[:Title] = document_title # See https://github.com/boazsegev/combine_pdf/issues/150
      merged_pdf.save path

      File.delete(path_supplier)
      File.delete(path_customer)
    end

    def generate_delivery_note(path, data, language, scope)
      coder = HTMLEntities.new

      template_path = select_template(data, language)
      html = File.open(template_path, 'rb') { |file| file.read }

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

      display_element("scope--#{scope}")
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
      solutions = fetch_invoicelines(order_id: data['id'])
      deliverylines = solutions.map do |invoiceline|
        line = "<div class='deliveryline'>"
        line += "  <div class='col col-1'>#{invoiceline[:description]}</div>"
        line += "</div>"
        line
      end
      deliverylines.join
    end

    def generate_own_reference(data)
      request = data['offer']['request']
      if request
        own_reference = "<b>AD #{format_request_number(request['id'])}</b>"
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
