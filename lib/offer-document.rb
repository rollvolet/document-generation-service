# coding: utf-8
require 'wicked_pdf'
require 'htmlentities'

class HTMLEntities
  class Encoder
    def basic_entity_regexp
      # Don't encode <, >, ', " and &.
      # They are part of the HTML markup and don't need to be displayed as literal characters
      # https://github.com/threedaymonk/htmlentities/blob/049ec3b63c2fcc86fc58ca6e65310482be5a0891/lib/htmlentities/encoder.rb#L41
      @basic_entity_regexp ||= /["]/
    end
  end
end

def generate_offer_document(path, data)
  coder = HTMLEntities.new

  language = select_language(data)
  template_path = select_template(data, language)
  html = File.open(template_path, 'rb') { |file| file.read }

  references = coder.encode(generate_references(data, language), :named)
  html.sub! '<!-- {{REFERENCES}} -->', references

  building = coder.encode(generate_building(data, language), :named)
  html.sub! '<!-- {{BUILDING}} -->', "<div class='building'>#{building}</div>" if building

  contactlines = coder.encode(generate_contactlines(data), :named)
  html.sub! '<!-- {{CONTACTLINES}} -->', contactlines

  addresslines = coder.encode(generate_addresslines(data), :named)
  html.sub! '<!-- {{ADDRESSLINES}} -->', addresslines

  html.sub! '<!-- {{INTRO}} -->', coder.encode(data['documentIntro'], :named) if data['documentIntro']

  offerlines = coder.encode(generate_offerlines(data), :named)
  html.sub! '<!-- {{OFFERLINES}} -->', offerlines

  html.sub! '<!-- {{CONDITIONS}} -->', coder.encode(data['documentOutro'], :named) if data['documentOutro']

  write_to_pdf(path, html)
end

def write_to_pdf(path, html)
  footer_path = '/templates/offerte-footer.html'
  footer_html = File.open(footer_path, 'rb') { |file| file.read }

  pdf = WickedPdf.new.pdf_from_string(html, {
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
                                        footer: { content: footer_html }
                                      })

  # Write HTML to a document for debugging purposes
  html_path = path.sub '.pdf', '.html'
  File.open(html_path, 'wb') { |file| file << html }
  File.open(path, 'wb') { |file| file << pdf }
end

# Language is determined by the language of the contact (if one is attached to the offer) or customer.
# Languafe of the building doesn't matter
def select_language(data)
  language = 'NED'
  if data['contact'] and data['contact']['language']
    language = data['contact']['language']['code']
  elsif data['customer'] and data['customer']['language']
    language = data['customer']['language']['code']
  end
  language
end

def select_template(data, language)
  if language == 'FRA'
    ENV['OFFER_TEMPLATE_FR'] || '/templates/offerte-fr.html'
  else
    ENV['OFFER_TEMPLATE_NL'] || '/templates/offerte-nl.html'
  end
end

# Address is always the address of the customer, even if a contact is attached to the offer
def generate_addresslines(data)
  customer = data['customer']
  hon_prefix = customer['honorificPrefix']
  
  name = ''
  name += hon_prefix['name'] if hon_prefix and hon_prefix['name'] and customer['printInFront']
  name += " #{customer['prefix']}" if customer['prefix'] and customer['printPrefix']
  name += " #{customer['name']}" if customer['name']
  name += " #{customer['suffix']}" if customer['suffix'] and customer['printSuffix']
  name += " #{hon_prefix['name']}" if hon_prefix and hon_prefix['name'] and not customer['printInFront']

  addresslines = if name then "#{name}<br/>" else "" end
  addresslines += "#{customer['address1']}<br/>" if customer['address1']
  addresslines += "#{customer['address2']}<br/>" if customer['address2']
  addresslines += "#{customer['address3']}<br/>" if customer['address3']
  addresslines += customer['postalCode'] if customer['postalCode']
  addresslines += " #{customer['city']}" if customer['city']

  addresslines
end

def generate_building(data, language)
  building = data['building']
  
  if building
    hon_prefix = building['honorificPrefix']
    # TODO Move language dependent fragments to the HTML template
    name = if language == 'FRA' then '<b>Concerne:</b>' else '<b>Betreft:</b> ' end
    name += hon_prefix['name'] if hon_prefix and hon_prefix['name'] and building['printInFront']
    name += " #{building['prefix']}" if building['prefix'] and building['printPrefix']
    name += " #{building['name']}" if building['name']
    name += " #{building['suffix']}" if building['suffix'] and building['printSuffix']
    name += " #{hon_prefix['name']}" if hon_prefix and hon_prefix['name'] and not building['printInFront']
    addresslines = "#{name}<br/>"
    addresslines += "<span>#{building['address1']}</span><br/>" if building['address1']
    addresslines += "<span>#{building['address2']}</span><br/>" if building['address2']
    addresslines += "<span>#{building['address3']}</span><br/>" if building['address3']
    addresslines += "<span>#{building['postalCode']} #{building['city']}</span>" if building['postalCode'] or building['city']
    addresslines
  else
    nil
  end
end

def generate_contactlines(data)
  contact = data['contact']
  name = "Contact: #{contact['prefix']} #{contact['name']} #{contact['suffix']}".chomp if contact

  telephones = if contact then contact['telephones'] else data['customer']['telephones'] end
  top_telephones = telephones.find_all { |t| t['telephoneType']['name'] != 'FAX' }.first(2)

  contactlines = if name then "<div class='contactline contactline--name'>#{name}</div>" else '' end
  contactlines += "<div class='contactline contactline--telephones'>"
  top_telephones.each do |tel|
    formatted_tel = format_telephone(tel['country']['telephonePrefix'], tel['area'], tel['number'])
    contactlines += "<span class='contactline contactline--telephone'>#{formatted_tel}</span>"
  end
  contactlines += "</div>"
  contactlines
end

def generate_offerlines(data)
  offerlines = data['offerlines'].map do |offerline|
    line = "<div class='offerline'>"
    line += "  <div class='col col-1'>#{offerline['description']}</div>"
    line += "  <div class='col col-2'>&euro; #{format_decimal(offerline['amount'])}</div>"
    line += "  <div class='col col-3'>#{offerline['vatRate']['rate'].to_i}%</div>"    
    line += "</div>"
    line
  end
  offerlines.join
end

def generate_references(data, language)
  # TODO Move language dependent fragments to the HTML template
  offer_date_label = if language == 'FRA' then 'Date' else 'Offertedatum' end
  own_reference_label = if language == 'FRA' then 'Notre r&eacute;f&eacute;rence' else 'Onze referentie' end
  ext_reference_label = if language == 'FRA' then 'Votre r&eacute;f&eacute;rence' else 'Uw referentie' end

  offer_date = DateTime.parse(data['offerDate']).strftime("%d/%m/%Y") if data['offerDate']
  references = "<b>#{offer_date_label}:</b> #{offer_date}<br/><br/>"

  request = data['request']
  own_reference = ''
  if request
    own_reference += "AD#{request['id']}"
    visit = request['visit']
    own_reference += "/#{visit['visitor']}" if visit and visit['visitor']
  end
  own_reference += " <span class='note'>("
  own_reference += "#{data['number']} #{data['documentVersion']}".strip
  own_reference += ")</span>"
  references += "<b>#{own_reference_label}:</b> #{own_reference}<br/>"

  references += "<b>#{ext_reference_label}:</b> #{data['reference']}<br/>" if data['reference']
  references
end

def format_decimal(number)
  if number then sprintf("%0.2f", number).gsub(/(\d)(?=\d{3}+\.)/, '\1 ').gsub(/\./, ',') else '' end
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

