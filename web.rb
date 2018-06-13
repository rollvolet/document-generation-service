require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'pry' if development?
require 'better_errors' if development?
require 'prawn'
require 'json'

# TODO file cleanup job?

configure :development do
  use BetterErrors::Middleware
  BetterErrors::Middleware.allow_ip! '0.0.0.0/0'
  # you need to set the application root in order to abbreviate filenames within the application:
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

post '/documents/visit-report' do
  request.body.rewind
  json_body = JSON.parse request.body.read

  id = json_body['id']
  
  Prawn::Document.generate("/tmp/#{id}-bezoekrapport.pdf", page_size: 'A4', page_layout: :portrait) do |pdf|
    # pdf.stroke_axis
    pdf.font_size 10
    pdf.font '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'

    gap = 10
    y_coordinate = 780 # top of the page
    columns = [300, 140, 80] # widths of the columns in the header
    max_height = 0 # keep track of the highest stretchy bounding box (since Prawn doesn't)

    # First header row
    
    pdf.bounding_box([0, y_coordinate], width: columns[0]) do
      lines = customer_address_lines json_body['customer']
      lines.each { |line| pdf.text line }

      if json_body['building']
        pdf.move_down 5
        pdf.text 'Gebouw:'
        lines = building_address_lines json_body['building']
        lines.each { |line| pdf.text line }
      end

      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    pdf.bounding_box([columns[0], y_coordinate], width: columns[1]) do
      if json_body['requestDate']
        date = Date.parse json_body['requestDate']
        pdf.text 'Aanvraag: ' + date.strftime("%d-%m-%Y")
      end
      if json_body['visit'] and json_body['visit']['visitDate']
        date = Date.parse json_body['visit']['visitDate']
        pdf.text 'Bezoek:     ' + date.strftime("%d-%m-%Y")

        if json_body['visit']['calendarSubject']
          period = json_body['visit']['calendarSubject'].split(json_body['customer']['name']).first.chop
          pdf.indent(55) { pdf.text period }
        end
      end

      max_height = pdf.bounds.height if max_height < pdf.bounds.height        
    end

    pdf.bounding_box([columns[0] + columns[1], y_coordinate], width:  columns[2]) do
      pdf.text "Nr:    #{json_body['id']}"
      
      language = 'Taal: '
      language += json_body['customer']['language']['code'] if json_body['customer']['language']
      pdf.text language
      
      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    # End of first header row

    y_coordinate = y_coordinate - max_height - gap
    max_height = 0
    
    # Second header row
    
    pdf.bounding_box([0, y_coordinate], width: columns[0]) do
      way_of_entry = 'Aanmelding: '
      way_of_entry += json_body['wayOfEntry']['name'] if json_body['wayOfEntry']
      pdf.text way_of_entry

      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end
    
    pdf.bounding_box([columns[0], y_coordinate], width: columns[1]) do
      visitor = 'Bezoeker: '
      visitor += json_body['visit']['visitor'] if json_body['visit']
      pdf.text visitor
      
      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    # End of second header row

    pdf.move_down 5
    pdf.stroke_horizontal_rule

    pdf.move_down gap

    y_coordinate = y_coordinate - max_height - gap - 5
    max_height = 0
    
    # Start of third header row
    
    pdf.bounding_box([0, y_coordinate], width: columns[0]) do
      pdf.text 'Email:'
      pdf.indent(10) { pdf.text 'Klant: ' + json_body['customer']['email'] } if json_body['customer']['email']
      pdf.indent(45) { pdf.text json_body['customer']['email2'] } if json_body['customer']['email2']
      pdf.indent(10) { pdf.text 'Contact: ' + json_body['contact']['email'] } if json_body['contact'] and json_body['contact']['email']      
      pdf.text "#{json_body['employee']} noteerde: #{json_body['comment'] || ''}"

      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    pdf.bounding_box([columns[0] + columns[1], y_coordinate], width: columns[2]) do
      pdf.text "\u25A2 Post" # checkboxes
      pdf.text "\u25A2 E-post"
      
      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    # End of third header row
  end

  send_file "/tmp/#{id}-bezoekrapport.pdf"
end

private

def customer_address_lines(customer)
  honorific_prefix = customer['honorificPrefix']
  name = ''
  name += honorific_prefix['name'] if honorific_prefix and customer['printInFront']
  name += " #{customer['prefix']}" if customer['printPrefix']
  name += " #{customer['name']}"
  name += " #{customer['suffix']}" if customer['printSuffix']
  name += " #{honorific_prefix['name']}" if honorific_prefix and not customer['printInFront']
  
  address = [ name ]
  address += [ customer['address1'], customer['address2'], customer['address3'] ]
  address << "#{customer['postalCode']} #{customer['city']}"
  
  address.find_all { |x| x != nil }
end

def building_address_lines(building)
  name = ''
  name += " #{building['prefix']}" if building['printPrefix']
  name += " #{building['name']}"
  name += " #{building['suffix']}" if building['printSuffix']
  
  address = [ name ]
  address += [ building['address1'], building['address2'], building['address3'] ]
  address << "#{building['postalCode']} #{building['city']}"
  
  address.find_all { |x| x != nil }
end
