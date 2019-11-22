require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class ProductionTicket

    include DocumentGenerator::Helpers

    def initialize
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

      telephones = generate_telephones(data)
      html.gsub! '<!-- {{TELEPHONES}} -->', telephones

      order_date = generate_order_date(data)
      html.gsub! '<!-- {{ORDER_DATE}} -->', order_date

      request_number = generate_request_number(data)
      html.gsub! '<!-- {{REQUEST_NUMBER}} -->', request_number

      offer_number = data['offer']['number']
      html.gsub! '<!-- {{OFFER_NUMBER}} -->', offer_number

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
        reference = "AD #{request['id']}"
        visit = request['visit']
        reference += " #{visit['visitor']}" if visit and visit['visitor']
        reference
      else
        ''
      end
    end

    def generate_order_date(data)
      if data['orderDate'] then format_date(data['orderDate']) else '' end
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

      "#{name}<br>#{address}"
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

        "#{name}<br>#{address}"
      else
        hide_element('row--building')
      end
    end

    def generate_telephones(data)
      telephones = if data['contact'] then data['contact']['telephones'] else data['customer']['telephones'] end
      top_telephones = telephones.find_all { |t| t['telephoneType']['name'] != 'FAX' }.first(2)

      formatted_telephones = top_telephones.map do |tel|
        format_telephone(tel['country']['telephonePrefix'], tel['area'], tel['number'])
      end

      formatted_telephones.join('<br>')
    end

  end
end
