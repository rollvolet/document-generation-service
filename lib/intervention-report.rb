require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class InterventionReport

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end

    def generate(path, data)
      coder = HTMLEntities.new

      template_path = select_template
      html = File.open(template_path, 'rb') { |file| file.read }

      intervention_date = generate_intervention_date(data)
      html.gsub! '<!-- {{DATE}} -->', intervention_date

      intervention_number = generate_intervention_number(data)
      html.gsub! '<!-- {{NUMBER}} -->', intervention_number

      way_of_entry = (data['wayOfEntry'] && data['wayOfEntry']['name']) || ''
      html.gsub! '<!-- {{WAY_OF_ENTRY}} -->', way_of_entry

      visit = generate_visit(data)
      html.gsub! '<!-- {{VISIT_DATE}} -->', visit[0]
      html.gsub! '<!-- {{VISIT_TIME}} -->', visit[1]

      technicians = coder.encode(generate_technicians(data), :named)
      html.gsub! '<!-- {{TECHNICIANS}} -->', technicians

      language = generate_language(data)
      html.gsub! '<!-- {{LANGUAGE}} -->', language

      customer = coder.encode(generate_customer(data), :named)
      html.gsub! '<!-- {{CUSTOMER}} -->', customer

      customer_email_address = generate_customer_email_address(data)
      html.gsub! '<!-- {{CUSTOMER_EMAIL_ADDRESS}} -->', customer_email_address

      contactlines = coder.encode(generate_contact(data), :named)
      html.gsub! '<!-- {{CONTACTLINES}} -->', contactlines

      contact_email_address = generate_contact_email_address(data)
      html.gsub! '<!-- {{CONTACT_EMAIL_ADDRESS}} -->', contact_email_address

      vat_number = generate_vat_number(data)
      html.gsub! '<!-- {{VAT_NUMBER}} -->', vat_number

      building_address = coder.encode(generate_building_address(data), :named)
      html.gsub! '<!-- {{BUILDING_ADDRESS}} -->', building_address

      employee = coder.encode(generate_employee_name(data), :named)
      html.gsub! '<!-- {{EMPLOYEE}} -->', employee

      description = coder.encode(data['description'] || '', :named)
      html.gsub! '<!-- {{DESCRIPTION}} -->', description

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      document_title = "IR#{intervention_number}"
      write_to_pdf(path, html, title: document_title)
    end

    def select_template
      ENV['INTERVENTION_REPORT_TEMPLATE_NL'] || '/templates/interventierapport-nl.html'
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

    def generate_intervention_date(data)
      if data['date'] then format_date(data['date']) else '' end
    end

    def generate_intervention_number(data)
      data['id'].to_s
    end

    def generate_visit(data)
      date = ''
      time = ''

      calendar_event = fetch_calendar_event(data['id'])
      if calendar_event
        date = format_date(calendar_event[:date])

        if calendar_event[:subject] and calendar_event[:subject].include? ' | '
          time = calendar_event[:subject].split(' | ').first.chop
        end
      end

      [date, time]
    end

    def generate_technicians(data)
      if data['technicians']
        data['technicians'].map { |t| t['firstName'] }.join(', ')
      else
        ''
      end
    end

    def generate_vat_number(data)
      if data['customer']['vatNumber']
        format_vat_number(data['customer']['vatNumber'])
      else
        hide_element('table .col .vat-number')
      end
    end

    def generate_customer(data)
      customer = data['customer']

      honorific_prefix = customer['honorificPrefix']

      name = ''
      name += honorific_prefix['name'] if honorific_prefix and customer['printInFront']
      name += " #{customer['prefix']}" if customer['prefix'] and customer['printPrefix']
      name += " #{customer['name']}" if customer['name']
      name += " #{customer['suffix']}" if customer['suffix'] and customer['printSuffix']
      name += " #{honorific_prefix['name']}" if honorific_prefix and not customer['printInFront']
      name

      address = [ customer['address1'],
        customer['address2'],
        customer['address3'],
        "#{customer['postalCode']} #{customer['city']}"
      ].find_all { |a| a }.join('<br>')

      telephones = fetch_telephones(customer['dataId'])
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

    def generate_building_address(data)
      building = data['building']

      if building
        honorific_prefix = building['honorificPrefix']

        name = ''
        name += honorific_prefix['name'] if honorific_prefix and building['printInFront']
        name += " #{building['prefix']}" if building['prefix'] and building['printPrefix']
        name += " #{building['name']}" if building['name']
        name += " #{building['suffix']}" if building['suffix'] and building['printSuffix']
        name += " #{honorific_prefix['name']}" if honorific_prefix and not building['printInFront']

        [ name,
          building['address1'],
          building['address2'],
          building['address3'],
          "#{building['postalCode']} #{building['city']}"
        ].find_all { |a| a and a != "" }.join('<br>')
      else
        hide_element('table .col .building-address')
      end
    end

    def generate_contact(data)
      contact = data['contact']
      if contact
        hon_prefix = contact['honorificPrefix']
        name = ''
        name += hon_prefix['name'] if hon_prefix and hon_prefix['name'] and contact['printInFront']
        name += " #{contact['prefix']}" if contact['prefix'] and contact['printPrefix']
        name += " #{contact['name']}" if contact['name']
        name += " #{contact['suffix']}" if contact['suffix'] and contact['printSuffix']
        name += " #{hon_prefix['name']}" if hon_prefix and hon_prefix['name'] and not contact['printInFront']

        telephones = fetch_telephones(contact['id'], 'contacts')
        top_telephones = telephones.first(2)

        contactlines = ''
        contactlines += if name then "<div class='contactline contactline--name'>#{name}</div>" else '' end
        contactlines += "<div class='contactline contactline--telephones'>"
        top_telephones.each do |tel|
          formatted_tel = format_telephone(tel[:prefix], tel[:value])
          contactlines += "<div class='contactline contactline--telephone'>#{formatted_tel}</div>"
        end
        contactlines += "</div>"
        contactlines
      else
        hide_element('table .col .contact')
      end
    end

    def generate_customer_email_address(data)
      emails = []
      if data['customer']
        emails = [ data['customer']['email'], data['customer']['email2'] ].find_all { |a| a }
      end

      if emails.length > 0 then emails.join(', ') else hide_element('email--customer') end
    end

    def generate_contact_email_address(data)
      emails = []
      if data['contact']
        emails = [ data['contact']['email'], data['contact']['email2'] ].find_all { |a| a }
      end

      if emails.length > 0 then emails.join(', ') else hide_element('email--contact') end
    end

    def generate_employee_name(data)
      if data['employee']
        data['employee']['firstName']
      else
        hide_element('employee--name')
        ''
      end
    end
  end
end
