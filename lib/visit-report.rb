require 'wicked_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class VisitReport < Document
    def initialize(*args, **keywords)
      super(*args, **keywords)
      @file_type = 'http://data.rollvolet.be/concepts/f5b9c371-a0ed-4476-90a1-3e73d5d4f09e'
    end

    def init_template request
      request_ref = generate_request_reference request
      template_path = ENV['VISIT_REPORT_TEMPLATE_NL'] || '/templates/bezoekrapport-nl.html'

      @html = File.open(template_path, 'rb') { |file| file.read }

      @document_title = "Bezoekrapport #{request_ref}"
    end

    def generate
      request = fetch_request(@resource_id)
      _case = fetch_case(request[:case_uri])
      customer = fetch_customer(_case[:customer][:uri]) if _case[:customer]
      contact = fetch_contact(_case[:contact][:uri]) if _case[:contact]
      building = fetch_building(_case[:building][:uri]) if _case[:building]

      init_template(request)

      request_date = format_date(request[:date])
      fill_placeholder('DATE', request_date)

      request_number = format_request_number(request[:number])
      request_number += " #{request[:visitor][:initials]}" if request.dig(:visitor, :initials)
      fill_placeholder('NUMBER', request_number)

      fill_placeholder('WAY_OF_ENTRY', request[:way_of_entry] || '')

      visit = generate_visit(request[:uri])
      fill_placeholder('VISIT_DATE', visit[0])
      fill_placeholder('VISIT_TIME', visit[1])

      visitor = request.dig(:visitor, :name) || ''
      fill_placeholder('VISITOR', visitor, encode: true)

      language_code = contact&.dig(:language, :code)
      language_code = customer.dig(:language, :code) unless language_code
      fill_placeholder('LANGUAGE', language_code || '')

      customer_data = generate_contactlines(customer: customer, address: customer[:address])
      fill_placeholder('CUSTOMER', customer_data, encode: true)

      customer_email_address = generate_email_addresses(customer[:uri])
      if customer_email_address.length > 0
        fill_placeholder('CUSTOMER_EMAIL_ADDRESS', customer_email_address.join(', '))
      else
        hide_element('email--customers')
      end

      if contact
        contactlines = generate_contactlines(contact: contact)
        fill_placeholder('CONTACTLINES', contactlines, encode: true)

        contact_email_address = generate_email_addresses(contact[:uri])
        if contact_email_address.length > 0
          fill_placeholder('CONTACT_EMAIL_ADDRESS', contact_email_address.join(', '))
        else
          hide_element('email--contacts')
        end
      else
        hide_element('table .col .contact')
      end

      if customer[:vat_number]
        vat_number = format_vat_number(customer[:vat_number])
        fill_placeholder('VAT_NUMBER', vat_number)
      else
        hide_element('table .col .vat-number')
      end

      building_address = generate_address(building, 'table .col .building-address', include_telephones: true)
      fill_placeholder('BUILDING_ADDRESS', building_address, encode: true)

      if request[:employee]
        fill_placeholder('EMPLOYEE', request[:employee], encode: true)
      else
        hide_element('employee--name')
      end

      fill_placeholder('DESCRIPTION', request[:description] || '', encode: true)

      history = generate_offer_history(customer[:uri], request[:case_uri])
      fill_placeholder('ORDER_HISTORY', history, encode: true)

      generate_and_upload_file request[:uri]
      @path
    end

    def generate_offer_history(customer_uri, case_uri)
      history = fetch_recent_offers(customer_uri, case_uri)

      entries = history.map do |entry|
        order_flag = if entry[:is_ordered] then 'x' else '-' end
        date = entry[:date]&.strftime("%m/%Y")
        "<div>#{order_flag} #{date} #{format_request_number(entry[:number])} #{entry[:visitor]}</div>"
      end
      entries.join
    end

  end
end
