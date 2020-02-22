require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class ProductionTicket

    include DocumentGenerator::Helpers

    def initialize(scope)
      @inline_css = ''
      @scope = scope
    end

    def isOrder?
      @scope == 'order'
    end

    def isIntervention?
      @scope == 'intervention'
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

      order_date = generate_date_in(data)
      html.gsub! '<!-- {{DATE_IN}} -->', order_date

      date_out = generate_date_out(data)
      html.gsub! '<!-- {{DATE_OUT}} -->', date_out

      request_number = generate_request_number(data)
      html.gsub! '<!-- {{REQUEST_NUMBER}} -->', request_number

      intervention_number = generate_intervention_number(data)
      html.gsub! '<!-- {{INTERVENTION_NUMBER}} -->', intervention_number

      offer_number = generate_offer_number(data)
      html.gsub! '<!-- {{OFFER_NUMBER}} -->', offer_number

      html.gsub! '<!-- {{INLINE_CSS}} -->', @inline_css

      document_title = if isOrder? then generate_request_number(data) else generate_intervention_number(data) end
      page_margins = { left: 0, top: 0, bottom: 0, right: 0 }
      write_to_pdf(path, html, orientation: 'Landscape', margin: page_margins, title: document_title)
    end

    def select_template
      ENV['PRODUCTION_TICKET_TEMPLATE_NL'] || '/templates/productiebon-nl.html'
    end

    def generate_request_number(data)
      if isOrder?
        request = data['offer']['request']
        if request
          reference = "AD #{request['id']}"
          visit = request['visit']
          reference += " #{visit['visitor']}" if visit and visit['visitor']
          reference
        else
          ''
        end
      else
        hide_element('table .row.row--request-number')
      end
    end

    def generate_intervention_number(data)
      if isIntervention?
        "IR #{data['id']}"
      else
        hide_element('table .row.row--intervention-number')
      end
    end

    def generate_offer_number(data)
      if isOrder?
        data['offer']['number']
      else
        hide_element('table .row.row--offer-number')
      end
    end

    def generate_date_in(data)
      if isOrder? and data['orderDate']
        format_date(data['orderDate'])
      elsif isIntervention? and data['date']
        format_date(data['date'])
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
