require 'wicked_pdf'
require_relative './sparql_queries'
require_relative './document'

module DocumentGenerator
  class VisitReport < Document

    def init_template request
      template_path = ENV['VISIT_REPORT_TEMPLATE_NL'] || '/templates/bezoekrapport-nl.html'

      @html = File.open(template_path, 'rb') { |file| file.read }

      @document_title = "AD#{request[:number]}"
    end

    def generate
      request = fetch_request(@resource_id)
      customer = fetch_customer_by_case(request[:case_uri])
      contact = fetch_contact_by_case(request[:case_uri])
      building = fetch_building_by_case(request[:case_uri])

      init_template(request)

      request_date = format_date(request[:date])
      fill_placeholder('DATE', request_date)

      request_number = format_request_number(request[:number])
      request_number += " #{request[:visitor][:initials]}" if request.dig(:visitor, :initials)
      fill_placeholder('NUMBER', request_number)

      fill_placeholder('WAY_OF_ENTRY', request[:way_of_entry] || '')

      visit = generate_visit(@resource_id)
      fill_placeholder('VISIT_DATE', visit[0])
      fill_placeholder('VISIT_TIME', visit[1])

      visitor = request.dig(:visitor, :name) || ''
      fill_placeholder('VISITOR', visitor, encode: true)

      language_code = contact&.dig(:language, :code)
      language_code = customer.dig(:language, :code) unless language_code
      fill_placeholder('LANGUAGE', language_code || '')

      customer_data = generate_customer(customer)
      fill_placeholder('CUSTOMER', customer_data, encode: true)

      customer_email_address = generate_email_addresses(customer[:uri])
      if customer_email_address.length > 0
        fill_placeholder('CUSTOMER_EMAIL_ADDRESS', customer_email_address.join(', '))
      else
        hide_element('email--customers')
      end

      if contact
        contactlines = generate_contact(contact)
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

      if building
        building_address = generate_building_address(building)
        fill_placeholder('BUILDING_ADDRESS', building_address, encode: true)
      else
        hide_element('table .col .building-address')
      end

      if request[:employee]
        fill_placeholder('EMPLOYEE', request[:employee], encode: true)
      else
        hide_element('employee--name')
      end

      fill_placeholder('DESCRIPTION', request[:description] || '', encode: true)

      history = generate_offer_history(customer[:uri], request[:case_uri])
      fill_placeholder('ORDER_HISTORY', history, encode: true)

      write_file
    end

    def generate_visit(request_id)
      date = ''
      time = ''

      calendar_event = fetch_calendar_event(request_id, scope = 'requests')
      if calendar_event
        date = format_date(calendar_event[:date])

        if calendar_event[:subject] and calendar_event[:subject].include? ' | '
          time = calendar_event[:subject].split(' | ').first.strip
        end
      end

      [date, time]
    end

    def generate_customer(customer)
      name = ''
      name += customer[:honorific_prefix] if customer[:honorific_prefix] and customer[:print_suffix_in_front]
      name += " #{customer[:first_name]}" if customer[:first_name] and customer[:print_prefix]
      name += " #{customer[:last_name]}" if customer[:last_name]
      name += " #{customer[:suffix]}" if customer[:suffix] and customer[:print_suffix]
      name += " #{customer[:honorific_prefix]}" if customer[:honorific_prefix] and not customer[:print_suffix_in_front]
      name

      address = [
        customer[:address][:street],
        "#{customer[:address][:postal_code]} #{customer[:address][:city]}"
      ].find_all { |a| a }.join('<br>')

      telephones = fetch_telephones(customer[:uri])
      top_telephones = telephones.first(2)

      contactlines = "<div class='contactline contactline--name'>#{name}</div>"
      contactlines += "<div class='contactline contactline--address'>#{address}</div>"
      contactlines += "<div class='contactline contactline--telephones'>"
      top_telephones.each do |tel|
        formatted_tel = format_telephone(tel[:prefix], tel[:value])
        note = if tel[:note] then "(#{tel[:note]})" else '' end
        contactlines += "<div class='contactline contactline--telephone'>#{formatted_tel} #{note}</div>"
      end
      contactlines += "</div>"
      contactlines
    end

    def generate_building_address(building)
      name = ''
      name += building[:honorific_prefix] if building[:honorific_prefix] and building[:print_suffix_in_front]
      name += " #{building[:first_name]}" if building[:first_name] and building[:print_prefix]
      name += " #{building[:last_name]}" if building[:last_name]
      name += " #{building[:suffix]}" if building[:suffix] and building[:print_suffix]
      name += " #{building[:honorific_prefix]}" if building[:honorific_prefix] and not building[:print_suffix_in_front]
      name

      [
        name,
        building[:address][:street],
        "#{building[:address][:postal_code]} #{building[:address][:city]}"
      ].find_all { |a| a and a != "" }.join('<br>')
    end

    def generate_contact(contact)
      name = ''
      name += contact[:honorific_prefix] if contact[:honorific_prefix] and contact[:print_suffix_in_front]
      name += " #{contact[:first_name]}" if contact[:first_name] and contact[:print_prefix]
      name += " #{contact[:last_name]}" if contact[:last_name]
      name += " #{contact[:suffix]}" if contact[:suffix] and contact[:print_suffix]
      name += " #{contact[:honorific_prefix]}" if contact[:honorific_prefix] and not contact[:print_suffix_in_front]
      name

      telephones = fetch_telephones(contact[:uri])
      top_telephones = telephones.first(2)

      contactlines = ''
      contactlines += if name then "<div class='contactline contactline--name'>#{name}</div>" else '' end
      contactlines += "<div class='contactline contactline--telephones'>"
      top_telephones.each do |tel|
        formatted_tel = format_telephone(tel[:prefix], tel[:value])
        note = if tel[:note] then "(#{tel[:note]})" else '' end
        contactlines += "<div class='contactline contactline--telephone'>#{formatted_tel}#{note}</div>"
      end
      contactlines += "</div>"
      contactlines
    end

    def generate_email_addresses(customer_uri)
      if customer_uri.nil?
        formatted_emails = []
      else
        emails = fetch_emails(customer_uri)
        top_emails = emails.first(2)
        formatted_emails = top_emails.collect do |email|
          address = email[:value]["mailto:".length..-1]
          note = if email[:note] then "(#{email[:note]})" else '' end
          "#{address} #{note}"
        end
      end

      formatted_emails
    end

    def generate_offer_history(customer_uri, case_uri)
      history = fetch_recent_offers(customer_uri, case_uri)

      entries = history.map do |entry|
        order_flag = if entry[:is_ordered] then 'x' else '-' end
        date = entry[:date]&.strftime("%m/%Y")
        "<div>#{order_flag} #{date} AD #{format_request_number(entry[:number])} #{entry[:visitor]}</div>"
      end
      entries.join
    end

  end
end
