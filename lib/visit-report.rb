require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class VisitReport

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end

    def generate(path, data)
      coder = HTMLEntities.new

      template_path = select_template
      html = File.open(template_path, 'rb') { |file| file.read }

      request_date = generate_request_date(data)
      html.gsub! '<!-- {{DATE}} -->', request_date

      request_number = generate_request_number(data)
      html.gsub! '<!-- {{NUMBER}} -->', request_number

      way_of_entry = (data['wayOfEntry'] && data['wayOfEntry']['name']) || ''
      html.gsub! '<!-- {{WAY_OF_ENTRY}} -->', way_of_entry

      visit = generate_visit(data)
      html.gsub! '<!-- {{VISIT}} -->', visit

      visitor = coder.encode(generate_visitor(data), :named)
      html.gsub! '<!-- {{VISITOR}} -->', visitor

      language = generate_language(data)
      html.gsub! '<!-- {{LANGUAGE}} -->', language

      customer_name = coder.encode(generate_customer_name(data), :named)
      html.gsub! '<!-- {{CUSTOMER_NAME}} -->', customer_name

      customer_address = coder.encode(generate_customer_address(data), :named)
      html.gsub! '<!-- {{CUSTOMER_ADDRESS}} -->', customer_address

      building_address = coder.encode(generate_building_address(data), :named)
      html.gsub! '<!-- {{BUILDING_ADDRESS}} -->', building_address

      employee = coder.encode(generate_employee_name(data), :named)
      html.gsub! '<!-- {{EMPLOYEE}} -->', employee

      comment = coder.encode(data['comment'] || '', :named)
      html.gsub! '<!-- {{COMMENT}} -->', comment

      customer_email_address = generate_customer_email_address(data)
      html.gsub! '<!-- {{CUSTOMER_EMAIL_ADDRESS}} -->', customer_email_address

      contact_email_address = generate_contact_email_address(data)
      html.gsub! '<!-- {{CONTACT_EMAIL_ADDRESS}} -->', contact_email_address

      contactlines = coder.encode(generate_contactlines(data), :named)
      html.gsub! '<!-- {{CONTACTLINES}} -->', contactlines

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      write_to_pdf(path, html)
    end

    def select_template
      ENV['VISIT_REPORT_TEMPLATE_NL'] || '/templates/bezoekrapport-nl.html'
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

    def generate_visit(data)
      visit = ''

      if data['calendarEvent'] and data['calendarEvent']['visitDate']
        visit += format_date(data['calendarEvent']['visitDate'])

        if data['calendarEvent']['calendarSubject']
          period = data['calendarEvent']['calendarSubject'].split(data['customer']['name']).first.chop
          visit += "; #{period}"
        end
      end

      visit
    end

    def generate_visitor(data)
      if data['visitor'] and data['visitor'] != '(geen)'
        data['visitor']
      else
        ''
      end
    end

    def generate_customer_name(data)
      customer = data['customer']
      honorific_prefix = customer['honorificPrefix']

      name = ''
      name += honorific_prefix['name'] if honorific_prefix and customer['printInFront']
      name += " #{customer['prefix']}" if customer['prefix'] and customer['printPrefix']
      name += " #{customer['name']}" if customer['name']
      name += " #{customer['suffix']}" if customer['suffix'] and customer['printSuffix']
      name += " #{honorific_prefix['name']}" if honorific_prefix and not customer['printInFront']
      name
    end

    def generate_customer_address(data)
      customer = data['customer']
      [ customer['address1'],
        customer['address2'],
        customer['address3'],
        "#{customer['postalCode']} #{customer['city']}"
      ].find_all { |a| a }.join('<br>')
    end

    def generate_building_address(data)
      building = data['building']

      honorific_prefix = building['honorificPrefix']

      name = ''
      name += honorific_prefix['name'] if honorific_prefix and building['printInFront']
      name += " #{building['prefix']}" if building['prefix'] and building['printPrefix']
      name += " #{building['name']}" if building['name']
      name += " #{building['suffix']}" if building['suffix'] and building['printSuffix']
      name += " #{honorific_prefix['name']}" if honorific_prefix and not building['printInFront']

      if building
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
        data['employee']
      else
        hide_element('employee--name')
        ''
      end
    end

  end
end
