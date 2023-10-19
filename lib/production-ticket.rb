require 'wicked_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class ProductionTicket < Document
    def initialize(*args, **keywords)
      super(*args, **keywords)
      @file_type = 'http://data.rollvolet.be/concepts/0b49fae8-3546-4211-9c1e-64f359993c82'
    end

    def init_template request
      template_path = ENV['PRODUCTION_TICKET_TEMPLATE_NL'] || '/templates/productiebon-nl.html'
      @html = File.read(template_path)
      @document_title = generate_request_reference request if request
    end

    def generate
      case_uri = fetch_uri(@resource_id)
      _case = fetch_case(case_uri)
      request = fetch_request(_case[:request][:id]) if _case[:request]
      offer = fetch_offer(_case[:offer][:id]) if _case[:offer]
      order = fetch_order(_case[:order][:id]) if _case[:order]
      planning_event = fetch_calendar_event(_case[:order][:uri]) if _case[:order]
      customer = fetch_customer(_case[:customer][:uri]) if _case[:customer]
      contact = fetch_contact(_case[:contact][:uri]) if _case[:contact]
      building = fetch_building(_case[:building][:uri]) if _case[:building]

      init_template(request)

      fill_placeholder('CUSTOMER', generate_customer(customer), encode: true)
      fill_placeholder('BUILDING', generate_building(building), encode: true)
      fill_placeholder('CONTACT', generate_contact(contact), encode: true)

      fill_placeholder('EXECUTION', generate_delivery_method_label(_case[:delivery_method]))

      order_date = if order then format_date(order[:date]) else '' end
      fill_placeholder('DATE_IN', order_date)

      date_out = generate_date_out(order, planning_event)
      fill_placeholder('DATE_OUT', date_out)

      fill_placeholder('REQUEST_NUMBER', generate_request_reference(request)) if request
      fill_placeholder('OFFER_NUMBER', offer[:number]) if offer

      fill_placeholder('EXT_REFERENCE', generate_ext_reference(_case))

      # TODO fix relation between document and case
      page_margins = { left: 0, top: 0, bottom: 0, right: 0 }
      generate_and_upload_file case_uri, orientation: 'Landscape', margin: page_margins
      @path
    end

    def generate_date_out(order, planning_event)
      result = '__________________'

      if order
        if planning_event
          result = "<span class='planning-date'>#{format_date(planning_event[:date])}</span>"
        elsif order[:expected_date] or order[:required_date]
          expected_date = if order[:expected_date] then format_date(order[:expected_date]) else '_______' end
          required_date = if order[:required_date] then format_date(order[:required_date]) else '_______' end
          result = "#{expected_date} - #{required_date}"
        end
      end

      result
    end

    def generate_customer(customer)
      name = generate_print_name(customer, include_number: true)
      address = generate_address(customer, nil, include_name: false, address_separator: ' - ')

      result = "#{name}<br>#{address}"

      telephones = generate_telephones(customer[:uri], separator: '; ')
      result += "<br>#{telephones}" if telephones.length

      result
    end

    def generate_building(building)
      if building
        name = generate_print_name(building)
        address = generate_address(building, nil, include_name: false, address_separator: ' - ')

        result = "#{name}<br>#{address}"

        telephones = generate_telephones(building[:uri], separator: '; ')
        result += "<br>#{telephones}" if telephones.length

        result
      else
        hide_element('row--building')
      end
    end

    def generate_contact(contact)
      if contact
        name = generate_print_name(contact)
        address = generate_address(contact, nil, include_name: false)

        result = "#{name}<br>#{address}"

        telephones = generate_telephones(contact[:uri])
        result += "<br>#{telephones}" if telephones.length

        result
      else
        hide_element('row--contact')
      end
    end

    def generate_telephones(uri, separator: '<br>')
      telephones = fetch_telephones(uri)
      top_telephones = telephones.first(2)

      formatted_telephones = top_telephones.map do |tel|
        format_telephone(tel[:prefix], tel[:value])
      end

      formatted_telephones.join(separator)
    end

  end
end
