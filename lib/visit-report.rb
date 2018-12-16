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
      html.sub! '<!-- {{DATE}} -->', request_date  
      
      request_number = generate_request_number(data)
      html.sub! '<!-- {{NUMBER}} -->', request_number

      way_of_entry = (data['wayOfEntry'] && data['wayOfEntry']['name']) || ''
      html.sub! '<!-- {{WAY_OF_ENTRY}} -->', way_of_entry

      visit = generate_visit(data)
      html.sub! '<!-- {{VISIT}} -->', visit
      
      visitor = generate_visitor(data)
      html.sub! '<!-- {{VISITOR}} -->', visitor
      
      language = generate_language(data)
      html.sub! '<!-- {{LANGUAGE}} -->', language

      customer_name = coder.encode(generate_customer_name(data), :named)
      html.sub! '<!-- {{CUSTOMER_NAME}} -->', customer_name        

      customer_address = coder.encode(generate_customer_address(data), :named)
      html.sub! '<!-- {{CUSTOMER_ADDRESS}} -->', customer_address

      building_address = coder.encode(generate_building_address(data), :named)
      html.sub! '<!-- {{BUILDING_ADDRESS}} -->', building_address

      employee = data['employee'] || ''
      html.sub! '<!-- {{EMPLOYEE}} -->', employee
      
      comment = data['comment'] || ''
      html.sub! '<!-- {{COMMENT}} -->', comment
      
      customer_email_address = generate_customer_email_address(data)
      html.sub! '<!-- {{CUSTOMER_EMAIL_ADDRESS}} -->', customer_email_address        

      contact_email_address = generate_contact_email_address(data)
      html.sub! '<!-- {{CONTACT_EMAIL_ADDRESS}} -->', contact_email_address        

      contactlines = coder.encode(generate_contactlines(data), :named)
      html.sub! '<!-- {{CONTACTLINES}} -->', contactlines

      html.sub! '<!-- {{INLINE_CSS}} -->', @inline_css      

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
      
      if data['visit'] and data['visit']['visitDate']
        visit += format_date(data['visit']['visitDate'])

        if data['visit']['calendarSubject']
          period = data['visit']['calendarSubject'].split(data['customer']['name']).first.chop
          visit += "; #{period}"
        end
      end

      visit
    end

    def generate_visitor(data)
      if data['visit'] and data['visit']['visitor'] and data['visit']['visitor'] != '(geen)'
        data['visit']['visitor']
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
      
      if building
        [ building['address1'],
          building['address2'],
          building['address3'],
          "#{building['postalCode']} #{building['city']}"
        ].find_all { |a| a }.join('<br>')
      else
        hide_element('table .col .building-address')
      end
    end

    def generate_customer_email_address(data)
      [ data['customer']['email'], data['customer']['email2'] ].find_all { |a| a }.join(', ')
    end

    def generate_contact_email_address(data)
      if data['contact'] then [ data['contact']['email'], data['contact']['email2'] ].find_all { |a| a }.join(', ') else '' end
    end

  end
end
