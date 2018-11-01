require 'wicked_pdf'
require_relative './htmlentities'
require_relative './helpers'

module DocumentGenerator
  class OfferDocument

    include DocumentGenerator::Helpers

    def initialize
      @inline_css = ''
    end
    
    def generate(path, data)
      coder = HTMLEntities.new

      language = select_language(data)
      template_path = select_template(data, language)
      html = File.open(template_path, 'rb') { |file| file.read }

      offer_date = generate_offer_date(data)
      html.sub! '<!-- {{DATE}} -->', offer_date  

      own_reference = coder.encode(generate_own_reference(data), :named)
      html.sub! '<!-- {{OWN_REFERENCE}} -->', own_reference  

      ext_reference = coder.encode(generate_ext_reference(data), :named)
      html.sub! '<!-- {{EXT_REFERENCE}} -->', ext_reference

      building = coder.encode(generate_building(data), :named)
      html.sub! '<!-- {{BUILDING}} -->', building

      contactlines = coder.encode(generate_contactlines(data), :named)
      html.sub! '<!-- {{CONTACTLINES}} -->', contactlines

      addresslines = coder.encode(generate_addresslines(data), :named)
      html.sub! '<!-- {{ADDRESSLINES}} -->', addresslines

      html.sub! '<!-- {{INTRO}} -->', coder.encode(data['documentIntro'], :named) if data['documentIntro']

      offerlines = coder.encode(generate_offerlines(data), :named)
      html.sub! '<!-- {{OFFERLINES}} -->', offerlines

      html.sub! '<!-- {{CONDITIONS}} -->', coder.encode(data['documentOutro'], :named) if data['documentOutro']

      html.sub! '<!-- {{INLINE_CSS}} -->', @inline_css      

      write_to_pdf(path, html, '/templates/offerte-footer.html')
    end

    def select_template(data, language)
      if language == 'FRA'
        ENV['OFFER_TEMPLATE_FR'] || '/templates/offerte-fr.html'
      else
        ENV['OFFER_TEMPLATE_NL'] || '/templates/offerte-nl.html'
      end
    end

    def generate_offer_date(data)
      if data['offerDate'] then format_date(data['offerDate']) else '' end
    end    
    
    def generate_offerlines(data)
      offerlines = data['offerlines'].map do |offerline|
        line = "<div class='offerline'>"
        line += "  <div class='col col-1'>#{offerline['description']}</div>"
        line += "  <div class='col col-2'>&euro; #{format_decimal(offerline['amount'])}</div>"
        line += "  <div class='col col-3'>#{format_vat_rate(offerline['vatRate']['rate'])}%</div>"    
        line += "</div>"
        line
      end
      offerlines.join
    end

    def generate_own_reference(data)
      request = data['request']
      if request
        own_reference = "<b>AD #{request['id']}</b>"
        visit = request['visit']
        own_reference += " <b>#{visit['visitor']}</b>" if visit and visit['visitor']
        own_reference += "<br><span class='note'>#{data['number']} #{data['documentVersion']}</span>"
      else
        hide_element('references--own_reference')
      end
    end

  end
end
