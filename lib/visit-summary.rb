require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'
require_relative './sparql_queries'

module DocumentGenerator
  class VisitSummary

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end

    def generate(path, data)
      coder = HTMLEntities.new

      template_path = ENV['VISIT_SUMMARY_TEMPLATE_NL'] || '/templates/bezoek-samenvatting-nl.html'
      html = File.open(template_path, 'rb') { |file| file.read }

      entry_template_path = ENV['VISIT_SUMMARY_ENTRY_TEMPLATE_NL'] || '/templates/bezoek-samenvatting-entry-nl.html'
      entry_html = File.open(entry_template_path, 'rb') { |file| file.read }

      entries = data.map do |entry|
        request = entry['request']
        visitor_initials = entry['visitorInitials']
        history = entry['history']

        entry = "#{entry_html}" # make a copy of the entry template

        request_number = generate_request_number(request)
        request_number += " #{visitor_initials}" if visitor_initials
        entry.gsub! '<!-- {{NUMBER}} -->', request_number

        customer = request['customer']
        customer_name = coder.encode(generate_customer_entity_name(customer), :named)
        entry.gsub! '<!-- {{CUSTOMER_NAME}} -->', customer_name
        customer_address = coder.encode(generate_customer_entity_address(customer), :named)
        entry.gsub! '<!-- {{CUSTOMER_ADDRESS}} -->', customer_address
        customer_telephones = coder.encode(generate_customer_entity_telephones(customer), :named)
        entry.gsub! '<!-- {{CUSTOMER_TELEPHONES}} -->', customer_telephones
        customer_email = coder.encode(generate_customer_entity_email_addresses(customer), :named)
        entry.gsub! '<!-- {{CUSTOMER_EMAIL_ADDRESSES}} -->', customer_email

        building = request['building']
        if building
          building_name = coder.encode(generate_customer_entity_name(building), :named)
          entry.gsub! '<!-- {{BUILDING_NAME}} -->', building_name
          building_address = coder.encode(generate_customer_entity_address(building), :named)
          entry.gsub! '<!-- {{BUILDING_ADDRESS}} -->', building_address
          building_telephones = coder.encode(generate_customer_entity_telephones(building, 'buildings'), :named)
          entry.gsub! '<!-- {{BUILDING_TELEPHONES}} -->', building_telephones
          building_email = coder.encode(generate_customer_entity_email_addresses(building), :named)
          entry.gsub! '<!-- {{BUILDING_EMAIL_ADDRESSES}} -->', building_email
        end

        contact = request['contact']
        if contact
          contact_name = coder.encode(generate_customer_entity_name(contact), :named)
          entry.gsub! '<!-- {{CONTACT_NAME}} -->', contact_name
          contact_address = coder.encode(generate_customer_entity_address(contact), :named)
          entry.gsub! '<!-- {{CONTACT_ADDRESS}} -->', contact_address
          contact_telephones = coder.encode(generate_customer_entity_telephones(contact, 'contacts'), :named)
          entry.gsub! '<!-- {{CONTACT_TELEPHONES}} -->', contact_telephones
          contact_email = coder.encode(generate_customer_entity_email_addresses(contact), :named)
          entry.gsub! '<!-- {{CONTACT_EMAIL_ADDRESSES}} -->', contact_email
        end

        request_date = generate_request_date(request)
        entry.gsub! '<!-- {{REQUEST_DATE}} -->', request_date

        way_of_entry = (request['wayOfEntry'] && request['wayOfEntry']['name']) || ''
        entry.gsub! '<!-- {{WAY_OF_ENTRY}} -->', way_of_entry

        language = generate_language(request)
        entry.gsub! '<!-- {{LANGUAGE}} -->', language

        # TODO generate visit with data from triplestore
        visit = generate_visit(request)
        entry.gsub! '<!-- {{VISIT_DATE}} -->', visit[0]
        entry.gsub! '<!-- {{VISIT_TIME}} -->', visit[1]

        history = coder.encode(generate_order_history(history), :named)
        entry.gsub! '<!-- {{ORDER_HISTORY}} -->', history

        description = coder.encode(request['description'] || '', :named)
        entry.gsub! '<!-- {{DESCRIPTION}} -->', description

        entry
      end

      html.gsub! '<!-- {{VISIT_ENTRIES}} -->', entries.join()
      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      document_title = "Bezoekrapport"
      write_to_pdf(path, html, title: document_title)
    end

    def generate_language(data)
      if data['contact'] and data['contact']['language']
        data['contact']['language']['code']
      elsif data['customer']['language']
        data['customer']['language']['code']
      else
        ''
      end
    end

    def generate_customer_entity_name(customer)
      honorific_prefix = customer['honorificPrefix']

      name = ''
      name += honorific_prefix['name'] if honorific_prefix and customer['printInFront']
      name += " #{customer['prefix']}" if customer['prefix'] and customer['printPrefix']
      name += " #{customer['name']}" if customer['name']
      name += " #{customer['suffix']}" if customer['suffix'] and customer['printSuffix']
      name += " #{honorific_prefix['name']}" if honorific_prefix and not customer['printInFront']
      name
    end

    def generate_customer_entity_address(customer)
      address = [
        customer['address1'],
        customer['address2'],
        customer['address3'],
        "#{customer['postalCode']} #{customer['city']}"
      ].find_all { |a| a }.join('<br>')
    end

    def generate_customer_entity_telephones(customer, scope = 'customers')
      customer_id = if scope == 'customers' then customer['number'] else customer['id'] end
      telephones = fetch_telephones(customer_id, scope)
      top_telephones = telephones.first(2)
      formatted_telephones = top_telephones.collect do |tel|
        formatted_tel = format_telephone(tel[:prefix], tel[:value])
        note = if tel[:note] then "(#{tel[:note]})" else '' end
        "#{formatted_tel} #{note}"
      end
      formatted_telephones.join('<br>')
    end

    def generate_customer_entity_email_addresses(customer)
      customer_id = if scope == 'customers' then customer['number'] else customer['id'] end
      emails = fetch_emails(customer_id, scope)
      top_emails = emails.first(2)
      formatted_emails = top_emails.collect do |email|
        address = email[:value]["mailto:".length..-1]
        note = if email[:note] then "(#{email[:note]})" else '' end
        "#{address} #{note}"
      end
      formatted_emails.join('<br>')
    end

    def generate_order_history(history)
      entries = history.map do |entry|
        order_flag = if entry['isOrdered'] then 'x' else '-' end
        date = DateTime.parse(entry['offer']['offerDate']).strftime("%m/%Y")
        "<div>#{order_flag} #{date} #{format_request_number(entry['offer']['requestNumber'])} #{entry['visitor']}</div>"
      end
      entries.join
    end

    def generate_visit(data)
      date = ''
      time = ''

      calendar_event = fetch_calendar_event(data['id'], scope = 'requests')
      if calendar_event
        date = format_date(calendar_event[:date])

        if calendar_event[:subject] and calendar_event[:subject].include? ' | '
          time = calendar_event[:subject].split(' | ').first.strip
        end
      end

      [date, time]
    end
  end
end
