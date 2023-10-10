require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'
require_relative './sparql_queries'

module DocumentGenerator
  class OrderDocument

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

      expected_date = generate_expected_date(data)
      html.gsub! '<!-- {{EXPECTED_DATE}} -->', expected_date

      required_date = generate_required_date(data)
      html.gsub! '<!-- {{REQUIRED_DATE}} -->', required_date

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

      pricing = generate_pricing(data, language)
      html.gsub! '<!-- {{ORDERLINES}} -->', coder.encode(pricing[:orderlines], :named)
      html.gsub! '<!-- {{TOTAL_NET_ORDER_PRICE}} -->', format_decimal(pricing[:total_net_order_price])

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
        ENV['ORDER_HEADER_TEMPLATE_FR'] || '/templates/bestelbon-header-fr.html'
      else
        ENV['ORDER_HEADER_TEMPLATE_NL'] || '/templates/bestelbon-header-nl.html'
      end
    end

    def select_template(data, language)
      if language == 'FRA'
        ENV['ORDER_TEMPLATE_FR'] || '/templates/bestelbon-fr.html'
      else
        ENV['ORDER_TEMPLATE_NL'] || '/templates/bestelbon-nl.html'
      end
    end

    def document_title(data, language)
      reference = generate_header_reference(data)
      document_type = if language == 'FRA' then 'Bon de commande' else 'Bestelbon' end
      "#{document_type} #{reference}"
    end

    def generate_pricing(data, language)
      solutions = fetch_invoicelines(order_id: data['id'])
      orderlines = []
      prices = []

      solutions.each do |invoiceline|
        prices << invoiceline[:amount]

        line = "<div class='orderline'>"
        line += "  <div class='col col-1'>#{invoiceline[:description]}</div>"
        line += "  <div class='col col-2'>&euro; #{format_decimal(invoiceline[:amount])}</div>"

        vat_note_css_class = ''
        vat_rate = "#{format_vat_rate(invoiceline[:vat_rate])}%"
        if invoiceline[:vat_code] == 'm'
          vat_rate = ''
          vat_note_css_class = if language == 'FRA' then 'taxfree-fr' else 'taxfree-nl' end
        end
        line += "  <div class='col col-3 #{vat_note_css_class}'>#{vat_rate}</div>"
        line += "</div>"
        orderlines << line
      end

      total_net_order_price = prices.inject(:+) || 0  # sum of invoicelines

      {
        orderlines: orderlines.join,
        total_net_order_price: total_net_order_price
      }
    end

    def generate_expected_date(data)
      if data['expectedDate']
        format_date(data['expectedDate'])
      else
        hide_element('expected-date')
      end
    end

    def generate_required_date(data)
      if data['requiredDate']
        format_date(data['requiredDate'])
      else
        hide_element('required-date')
      end
    end

    def generate_own_reference(data)
      request = data['offer']['request']
      if request
        own_reference = "<b>#{format_request_number(request['id'])}</b>"
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
        reference = "#{format_request_number(request['id'])}"
        visit = request['visit']
        reference += " #{visit['visitor']}" if visit and visit['visitor']
        reference
      else
        ''
      end
    end
  end
end
