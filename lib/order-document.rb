require 'wicked_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class OrderDocument < Document
    def initialize(*args, **keywords)
      super(*args, **keywords)
      @file_type = 'http://data.rollvolet.be/concepts/6d080a6b-41f1-45f1-9698-7cbd3c846494'
    end

    def init_template request
      request_ref = generate_request_reference request

      if @language == 'FRA'
        template_path = ENV['ORDER_TEMPLATE_FR'] || '/templates/bestelbon-fr.html'
        header_path = ENV['ORDER_HEADER_TEMPLATE_FR'] || '/templates/bestelbon-header-fr.html'
        @document_title = "Bon de commande #{request_ref}"
      else
        template_path = ENV['ORDER_TEMPLATE_NL'] || '/templates/bestelbon-nl.html'
        header_path = ENV['ORDER_HEADER_TEMPLATE_NL'] || '/templates/bestelbon-header-nl.html'
        @document_title = "Bestelbon #{request_ref}"
      end

      @html = File.open(template_path, 'rb') { |file| file.read }
      @header = if header_path then File.open(header_path, 'rb') { |f| f.read } else '' end
      footer_path = select_footer(nil, @language)
      @footer = if footer_path then File.open(footer_path, 'rb') { |f| f.read } else '' end
    end

    def generate
      order = fetch_order(@resource_id)
      _case = fetch_case(order[:case_uri])
      planning_event = fetch_calendar_event(order[:uri])
      request = fetch_request(_case[:request][:id]) if _case[:request]
      offer = fetch_offer(_case[:offer][:id]) if _case[:offer]
      customer = fetch_customer(_case[:customer][:uri]) if _case[:customer]
      contact = fetch_contact(_case[:contact][:uri]) if _case[:contact]
      building = fetch_building(_case[:building][:uri]) if _case[:building]

      init_template(request)

      fill_placeholder('DATE', format_date(order[:date]))

      if planning_event&[:date]
        fill_placeholder('EXPECTED_DATE', format_date(planning_event[:date]))
        hide_element('required-date')
      else
        if order[:expected_date]
          fill_placeholder('EXPECTED_DATE', format_date(order[:expected_date]))
        else
          hide_element('expected-date')
        end

        if order[:required_date]
          fill_placeholder('REQUIRED_DATE', format_date(order[:required_date]))
        else
          hide_element('required-date')
        end
      end

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

      pricing = generate_pricing(order)
      fill_placeholder('ORDERLINES', pricing[:orderlines], encode: true)
      fill_placeholder('TOTAL_NET_ORDER_PRICE', format_decimal(pricing[:total_net_order_price]), encode: true)

      generate_and_upload_file order[:uri]
      @path
    end

    def generate_pricing(order)
      solutions = fetch_invoicelines(order_uri: order[:uri])
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
          vat_note_css_class = if @language == 'FRA' then 'taxfree-fr' else 'taxfree-nl' end
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
  end
end
