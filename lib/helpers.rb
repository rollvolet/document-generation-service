module DocumentGenerator
  module Helpers
    BASE_URI = 'http://data.rollvolet.be/%{resource}/%{id}'

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

    def get_resource_uri(resource, id)
      BASE_URI % { :resource => resource, :id => id }
    end

    def generate_print_name(data)
      name = ''
      name += data[:honorific_prefix] if data[:honorific_prefix] and data[:print_suffix_in_front]
      name += " #{data[:first_name]}" if data[:first_name] and data[:print_prefix]
      name += " #{data[:last_name]}" if data[:last_name]
      name += " #{data[:suffix]}" if data[:suffix] and data[:print_suffix]
      name += " #{data[:honorific_prefix]}" if data[:honorific_prefix] and not data[:print_suffix_in_front]
      name
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

    def generate_address(record, hide_class = nil)
      if record
        addresslines = "#{generate_print_name(record)}<br>"
        if record[:address]
          if record[:address][:street]
            streetlines = record[:address][:street].gsub(/\n/, '<br>')
            addresslines += "#{streetlines}<br>"
          end
          addresslines += "#{record[:address][:postal_code]} #{record[:address][:city]}" if record[:address][:postal_code] or record[:address][:city]
        end
        addresslines
      elsif hide_class
        hide_element(hide_class)
      end
    end

    def generate_contactlines(customer: nil, contact: nil, address: nil)
      contactlines =
        if customer and customer[:vat_number]
        then "<div class='contactline contactline--vat-number'>#{format_vat_number(customer[:vat_number])}</div>"
        else ''
        end

      if contact
        print_name = generate_print_name(contact)
        name = if customer then "Contact: #{print_name}" else print_name end
        contactlines += "<div class='contactline contactline--name'>#{name}</div>"
      elsif customer and address
        contactlines += "<div class='contactline contactline--name'>#{generate_print_name(customer)}</div>"
      end

      if address
        addresslines = [
          address[:street],
          "#{address[:postal_code]} #{address[:city]}"
        ].find_all { |a| a }.map { |a| a.gsub(/\n/, '<br>') }.join('<br>')
        contactlines += "<div class='contactline contactline--address'>#{addresslines}</div>" if addresslines
      end

      if customer or contact
        contactlines += "<div class='contactline contactline--telephones'>"
        telephones = if contact then fetch_telephones(contact[:uri]) else fetch_telephones(customer[:uri]) end
        top_telephones = telephones.first(2)
        top_telephones.each do |tel|
          formatted_tel = format_telephone(tel[:prefix], tel[:value])
          note = if tel[:note] then "(#{tel[:note]})" else '' end
          contactlines += "<span class='contactline contactline--telephone'>#{formatted_tel}</span>"
        end
        contactlines += "</div>"
      end

      contactlines
    end

    def generate_email_addresses(record_uri)
      if record_uri.nil?
        formatted_emails = []
      else
        emails = fetch_emails(record_uri)
        top_emails = emails.first(2)
        formatted_emails = top_emails.collect do |email|
          address = email[:value]["mailto:".length..-1]
          note = if email[:note] then "(#{email[:note]})" else '' end
          "#{address} #{note}"
        end
      end

      formatted_emails
    end

    def generate_request_reference(request)
      request_number = format_request_number(request[:number])
      request_number += " #{request[:visitor][:initials]}" if request.dig(:visitor, :initials)
      request_number
    end

    def generate_own_reference(request: nil, intervention: nil)
      if request
        "<b>#{generate_request_reference(request)}</b>"
      elsif intervention
        "<b>#{format_intervention_number(intervention[:number])}</b>"
      else
        hide_element('references--own_reference')
      end
    end

    def generate_ext_reference(data)
      if data['reference']
        data['reference']
      elsif data[:reference]
        data[:reference]
      else
        hide_element('references--ext_reference')
        hide_element('row--ext-reference')
        hide_element('row--ext-reference .row--key')
        hide_element('row--ext-reference .row--value')
      end
    end

    def generate_visit(record_uri)
      date = ''
      time = ''

      calendar_event = fetch_calendar_event(record_uri)
      if calendar_event
        date = format_date(calendar_event[:date])

        if calendar_event[:subject] and calendar_event[:subject].include? ' | '
          time = calendar_event[:subject].split(' | ').first.strip
        end
      end

      [date, time]
    end

    def generate_request_number(data)
      format_request_number(data['id'].to_s)
    end

    def generate_request_date(data)
      if data['requestDate'] then format_date(data['requestDate']) else '' end
    end

    def generate_invoice_number(data)
      number = data[:number].to_s || ''
      if number.length > 4
        i = number.length - 4
        "#{number[0..i-1]}/#{number[i..-1]}"
      else
        number
      end
    end

    def generate_invoice_date(data)
      invoice_date = data['invoiceDate'] || data[:invoice_date]
      if invoice_date then format_date(invoice_date) else '' end
    end

    def generate_payment_due_date(invoice)
      if invoice[:due_date]
        format_date(invoice[:due_date])
      else
        hide_element('payment-notification--deadline')
        ''
      end
    end

    def generate_bank_reference_with_base(base, number)
      ref = base + number
      modulo_check = ref % 97
      padded_modulo = "%02d" % modulo_check.to_s
      padded_modulo = '97' if padded_modulo == '00'
      reference = "%012d" % (ref.to_s + padded_modulo)
      "+++#{reference[0..2]}/#{reference[3..6]}/#{reference[7..-1]}+++"
    end

    def format_request_number(number)
      if number
        formatted_number = number.to_s.reverse.chars.each_slice(3).map(&:join).join(".").reverse
        "AD #{formatted_number}"
      else
        number
      end
    end

    def format_intervention_number(number)
      if number
        formatted_number = number.to_s.reverse.chars.each_slice(3).map(&:join).join(".").reverse
        "IR #{formatted_number}"
      else
        number
      end
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

    def format_telephone(prefix, value)
      formatted_prefix = prefix.dup
      formatted_prefix[0..1] = '+' if prefix and prefix.start_with? '00'

      if (value)
        area = find_area(value);
        if (area)
          group_per_2_chars = /(?=(?:..)*$)/
          number_groups = value[area.size..].split(group_per_2_chars)
          if (number_groups.size > 1 and number_groups[0].size == 1)
            # concatenate first 2 elements if first element only contains 1 character
            number_groups[0..1] = "#{number_groups[0]}#{number_groups[1]}"
          end

          number = "#{area} #{number_groups.join(' ')}"
          if (number.start_with? '0')
            formatted_number = "(#{number[0]})#{number[1..]}"
          else
            formatted_number = number
          end
        else
          formatted_number = value;
        end
      end

      [formatted_prefix, formatted_number].find_all { |e| e }.join(' ');
    end

    def find_area(value)
      area = AREA_NUMBERS.find { |area| value.start_with?(area) }
      if (area == '04' && value.size > 2)
        # In area '04' only numbers like '2xx xx xx' and '3xx xx xx' occur.
        # That's how they can be distinguished from cell phone numbers
        if (not ['2', '3'].include?(value[2]))
          # we assume it's a cell phone number, hence area is 4 characters (eg. 0475)
          area = value.slice(0, 4);
        end
      end
      area
    end

    # all known area numbers in Belgium as found on
    # https://nl.wikipedia.org/wiki/Lijst_van_Belgische_zonenummers
    AREA_NUMBERS = [
      '02',
      '03',
      '04',
      '09',
      '010',
      '011',
      '012',
      '013',
      '014',
      '015',
      '016',
      '019',
      '050',
      '051',
      '052',
      '053',
      '054',
      '055',
      '056',
      '057',
      '058',
      '059',
      '060',
      '061',
      '063',
      '064',
      '065',
      '067',
      '069',
      '071',
      '080',
      '081',
      '082',
      '083',
      '085',
      '086',
      '087',
      '089',
    ];
  end
end
