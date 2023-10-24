require 'wicked_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class InterventionReport < Document
    def initialize(*args, **keywords)
      super(*args, **keywords)
      @file_type = 'http://data.rollvolet.be/concepts/5d7f3d76-b78e-4481-ba66-89879ea1b3eb'
    end

    def init_template intervention
      template_path = ENV['INTERVENTION_REPORT_TEMPLATE_NL'] || '/templates/interventierapport-nl.html'

      @html = File.open(template_path, 'rb') { |file| file.read }

      @document_title = "IR#{intervention[:number]}"
    end

    def generate
      intervention = fetch_intervention(@resource_id)
      _case = fetch_case(intervention[:case_uri])
      customer = fetch_customer(_case[:customer][:uri]) if _case[:customer]
      contact = fetch_contact(_case[:contact][:uri]) if _case[:contact]
      building = fetch_building(_case[:building][:uri]) if _case[:building]

      init_template(intervention)

      intervention_date = format_date(intervention[:date])
      fill_placeholder('DATE', intervention_date)

      intervention_number = format_intervention_number(intervention[:number])
      fill_placeholder('NUMBER', intervention_number)

      fill_placeholder('WAY_OF_ENTRY', intervention[:way_of_entry] || '')

      visit = generate_visit(intervention[:uri])
      fill_placeholder('VISIT_DATE', visit[0])
      fill_placeholder('VISIT_TIME', visit[1])

      technician_names = intervention[:technicians].join(', ') or ''
      fill_placeholder('TECHNICIANS', technician_names, encode: true)

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

      building_address = generate_address(building, 'table .col .building-address')
      fill_placeholder('BUILDING_ADDRESS', building_address, encode: true)

      if intervention[:employee]
        fill_placeholder('EMPLOYEE', intervention[:employee], encode: true)
      else
        hide_element('employee--name')
      end

      fill_placeholder('DESCRIPTION', intervention[:description] || '', encode: true)

      generate_and_upload_file intervention[:uri]
      @path
    end
  end
end
