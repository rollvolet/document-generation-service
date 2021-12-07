require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class ProductionTicket

    include DocumentGenerator::Helpers

    def initialize()
      @inline_css = ''
    end

    def generate(path, data)
      coder = HTMLEntities.new

      template_path = select_template
      html = File.open(template_path, 'rb') { |file| file.read }

      customer = coder.encode(generate_customer(data), :named)
      html.gsub! '<!-- {{CUSTOMER}} -->', customer

      building = coder.encode(generate_building(data), :named)
      html.gsub! '<!-- {{BUILDING}} -->', building

      contact = coder.encode(generate_contact(data), :named)
      html.gsub! '<!-- {{CONTACT}} -->', contact

      execution = generate_execution_label(data)
      html.gsub! '<!-- {{EXECUTION}} -->', execution

      order_date = generate_date_in(data)
      html.gsub! '<!-- {{DATE_IN}} -->', order_date

      date_out = generate_date_out(data)
      html.gsub! '<!-- {{DATE_OUT}} -->', date_out

      request_number = generate_request_number(data)
      html.gsub! '<!-- {{REQUEST_NUMBER}} -->', request_number

      offer_number = generate_offer_number(data)
      html.gsub! '<!-- {{OFFER_NUMBER}} -->', offer_number

      ext_reference = coder.encode(generate_ext_reference(data), :named)
      html.gsub! '<!-- {{EXT_REFERENCE}} -->', ext_reference

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      document_title = generate_request_number(data)
      page_margins = { left: 0, top: 0, bottom: 0, right: 0 }
      write_to_pdf(path, html, orientation: 'Landscape', margin: page_margins, title: document_title)
    end

    def select_template
      ENV['PRODUCTION_TICKET_TEMPLATE_NL'] || '/templates/productiebon-nl.html'
    end

    def generate_request_number(data)
      request = data['offer']['request']
      if request
        reference = "AD #{format_request_number(request['id'])}"
        visit = request['visit']
        reference += " #{visit['visitor']}" if visit and visit['visitor']
        reference
        else
          ''
      end
    end

    def generate_offer_number(data)
      data['offer']['number']
    end

    def generate_date_in(data)
      if data['orderDate']
        format_date(data['orderDate'])
      else
        ''
      end
    end

    def generate_date_out(data)
      if data['planningDate']
        "<span class='planning-date'>#{format_date(data['planningDate'])}</span>"
      elsif data['expectedDate'] or data['requiredDate']
        expected_date = if data['expectedDate'] then format_date(data['expectedDate']) else '_______' end
        required_date = if data['requiredDate'] then format_date(data['requiredDate']) else '_______' end
        "#{expected_date} - #{required_date}"
      else
        '__________________'
      end
    end

    def generate_customer(data)
      customer = data['customer']
      hon_prefix = customer['honorificPrefix']

      name = ''
      name += hon_prefix['name'] if hon_prefix and hon_prefix['name'] and customer['printInFront']
      name += " #{customer['prefix']}" if customer['prefix'] and customer['printPrefix']
      name += " #{customer['name']}" if customer['name']
      name += " #{customer['suffix']}" if customer['suffix'] and customer['printSuffix']
      name += " #{hon_prefix['name']}" if hon_prefix and hon_prefix['name'] and not customer['printInFront']

      city = if customer['postalCode'] or customer['city'] then "#{customer['postalCode']} #{customer['city']}" else nil end
      address = [
        customer['address1'],
        customer['address2'],
        customer['address3'],
        city
      ].select { |x| x }.join(' - ')

      result = "#{name}<br>#{address}"

      telephones = generate_telephones(data, 'customer', '; ')
      result += "<br>#{telephones}" if telephones.length

      result
    end

    def generate_building(data)
      building = data['building']

      if building
        hon_prefix = building['honorificPrefix']
        name = ''
        name += hon_prefix['name'] if hon_prefix and hon_prefix['name'] and building['printInFront']
        name += " #{building['prefix']}" if building['prefix'] and building['printPrefix']
        name += " #{building['name']}" if building['name']
        name += " #{building['suffix']}" if building['suffix'] and building['printSuffix']
        name += " #{hon_prefix['name']}" if hon_prefix and hon_prefix['name'] and not building['printInFront']

        city = if building['postalCode'] or building['city'] then "#{building['postalCode']} #{building['city']}" else nil end
        address = [
          building['address1'],
          building['address2'],
          building['address3'],
          city
        ].select { |x| x }.join(' - ')

        result = "#{name}<br>#{address}"

        telephones = generate_telephones(data, 'building', '; ')
        result += "<br>#{telephones}" if telephones.length

        result
      else
        hide_element('row--building')
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

        city = if contact['postalCode'] or contact['city'] then "#{contact['postalCode']} #{contact['city']}" else nil end
        address = [
          contact['address1'],
          contact['address2'],
          contact['address3'],
          city
        ].select { |x| x }.join('<br>')

        result = "#{name}<br>#{address}"

        telephones = generate_telephones(data, 'contact')
        result += "<br>#{telephones}" if telephones.length

        result
      else
        hide_element('row--contact')
      end
    end

    def generate_execution_label(data)
      execution = 'Zonder plaatsing'
      execution = 'Te plaatsen' if data['mustBeInstalled']
      execution = 'Te leveren' if data['mustBeDelivered']
      execution
    end

    def generate_telephones(data, scope, separator = '<br>')
      telephones = data[scope]['telephones']
      top_telephones = telephones.find_all { |t| t['telephoneType']['name'] != 'FAX' }.first(2)

      formatted_telephones = top_telephones.map do |tel|
        format_telephone(tel['country']['telephonePrefix'], tel['area'], tel['number'])
      end

      formatted_telephones.join(separator)
    end

  end
end
