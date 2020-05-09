module DocumentGenerator
  module Helpers
    def write_to_pdf(path, html, options = {})
      default_options = {
        margin: {
          left: 0,
          top: 14, # top margin on each page
          bottom: 20, # height (mm) of the footer
          right: 0
        },
        disable_smart_shrinking: true,
        print_media_type: true,
        page_size: 'A4',
        orientation: 'Portrait',
        header: { content: '' },
        footer: { content: '' }
      }

      options = default_options.merge options

      pdf = WickedPdf.new.pdf_from_string(html, options)

      # Write HTML to a document for debugging purposes
      html_path = path.sub '.pdf', '.html'
      File.open(html_path, 'wb') { |file| file << html }
      File.open(path, 'wb') { |file| file << pdf }
    end

    def hide_element(css_class)
      display_element(css_class, 'none')
    end

    def display_element(css_class, display = 'block')
      @inline_css += ".#{css_class} { display: #{display} }  "
      ''
    end

    # Language is determined by the language of the contact (if there is one) or customer.
    # Language of the building doesn't matter
    def select_language(data)
      language = 'NED'
      if data['contact'] and data['contact']['language']
        language = data['contact']['language']['code']
      elsif data['customer'] and data['customer']['language']
        language = data['customer']['language']['code']
      end
      language
    end

    def select_footer(data, language)
      if language == 'FRA'
        ENV['FOOTER_TEMPLATE_FR'] || '/templates/footer-fr.html'
      else
        ENV['FOOTER_TEMPLATE_NL'] || '/templates/footer-nl.html'
      end
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
        addresslines = "#{name}<br>"
        addresslines += "#{building['address1']}<br>" if building['address1']
        addresslines += "#{building['address2']}<br>" if building['address2']
        addresslines += "#{building['address3']}<br>" if building['address3']
        addresslines += "#{building['postalCode']} #{building['city']}" if building['postalCode'] or building['city']

        addresslines
      else
        hide_element('building')
      end
    end

    # Address is always the address of the customer, even if a contact is attached
    def generate_addresslines(data)
      customer = data['customer']
      hon_prefix = customer['honorificPrefix']

      name = ''
      name += hon_prefix['name'] if hon_prefix and hon_prefix['name'] and customer['printInFront']
      name += " #{customer['prefix']}" if customer['prefix'] and customer['printPrefix']
      name += " #{customer['name']}" if customer['name']
      name += " #{customer['suffix']}" if customer['suffix'] and customer['printSuffix']
      name += " #{hon_prefix['name']}" if hon_prefix and hon_prefix['name'] and not customer['printInFront']

      addresslines = if name then "#{name}<br>" else "" end
      addresslines += "#{customer['address1']}<br>" if customer['address1']
      addresslines += "#{customer['address2']}<br>" if customer['address2']
      addresslines += "#{customer['address3']}<br>" if customer['address3']
      addresslines += customer['postalCode'] if customer['postalCode']
      addresslines += " #{customer['city']}" if customer['city']

      addresslines
    end

    def generate_contactlines(data)
      vat_number = data['customer']['vatNumber']
      contactlines = if vat_number then "<div class='contactline contactline--vat-number'>#{format_vat_number(vat_number)}</div>" else '' end

      contact = data['contact']
      if contact
        hon_prefix = contact['honorificPrefix']
        name = 'Contact: '
        name += hon_prefix['name'] if hon_prefix and hon_prefix['name'] and contact['printInFront']
        name += " #{contact['prefix']}" if contact['prefix'] and contact['printPrefix']
        name += " #{contact['name']}" if contact['name']
        name += " #{contact['suffix']}" if contact['suffix'] and contact['printSuffix']
        name += " #{hon_prefix['name']}" if hon_prefix and hon_prefix['name'] and not contact['printInFront']
      end

      telephones = if contact then contact['telephones'] else data['customer']['telephones'] end
      top_telephones = telephones.find_all { |t| t['telephoneType']['name'] != 'FAX' }.first(2)

      contactlines += if name then "<div class='contactline contactline--name'>#{name}</div>" else '' end
      contactlines += "<div class='contactline contactline--telephones'>"
      top_telephones.each do |tel|
        formatted_tel = format_telephone(tel['country']['telephonePrefix'], tel['area'], tel['number'])
        contactlines += "<span class='contactline contactline--telephone'>#{formatted_tel}</span>"
      end
      contactlines += "</div>"
      contactlines
    end

    def generate_ext_reference(data)
      if data['reference']
        data['reference']
      else
        hide_element('references--ext_reference')
        hide_element('row--ext-reference')
        hide_element('row--ext-reference .row--key')
        hide_element('row--ext-reference .row--value')
      end
    end

    def generate_invoice_number(data)
      number = data['number'].to_s || ''
      if number.length > 4
        i = number.length - 4
        "#{number[0..i-1]}/#{number[i..-1]}"
      else
        number
      end
    end

    def generate_request_number(data)
      data['id'].to_s
    end

    def generate_invoice_date(data)
      if data['invoiceDate'] then format_date(data['invoiceDate']) else '' end
    end

    def generate_request_date(data)
      if data['requestDate'] then format_date(data['requestDate']) else '' end
    end

    def generate_bank_reference_with_base(base, number)
      ref = base + number
      modulo_check = ref % 97
      padded_modulo = "%02d" % modulo_check.to_s
      padded_modulo = '97' if padded_modulo == '00'
      reference = "%012d" % (ref.to_s + padded_modulo)
      "+++#{reference[0..2]}/#{reference[3..6]}/#{reference[7..-1]}+++"
    end

    def format_decimal(number)
      if number then sprintf("%0.2f", number).gsub(/(\d)(?=\d{3}+\.)/, '\1 ').gsub(/\./, ',') else '' end
    end

    def format_vat_number(vat_number)
      if vat_number and vat_number.length >= 2
        country = vat_number[0..1]
        number = vat_number[2..-1]
        if country.upcase == "BE"
          if number.length == 9
            return "#{country} #{number[0,3]}.#{number[3,3]}.#{number[6..-1]}"
          elsif number.length > 9
            return "#{country} #{number[0,4]}.#{number[4,3]}.#{number[7..-1]}"
          end
          return "#{country} #{number}"
        end
      else
        return vat_number
      end
    end

    def format_vat_rate(rate)
      if rate == 0 || rate/rate.to_i == 1
        rate.to_i.to_s
      else
        format_decimal(rate)
      end
    end

    def format_date(date)
      DateTime.parse(date).strftime("%d/%m/%Y")
    end

    def format_date_object(date)
      date.strftime("%d/%m/%Y")
    end

    def format_telephone(prefix, area, number)
      prefix[0..1] = '+' if prefix and prefix.start_with? '00'

      area = "(#{area[0]})#{area[1..-1]}" if area and area.length > 0

      if number.length == 6
        number = "#{number[0..1]} #{number[2..3]} #{number[4..-1]}"
      elsif number.length > 6
        number = "#{number[0..2]} #{number[3..4]} #{number[5..-1]}"
      end

      "#{prefix} #{area} #{number}"
    end

  end
end
