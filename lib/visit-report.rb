require 'prawn'

def generate_visit_report(path, data)
  Prawn::Document.generate(path, page_size: 'A4', page_layout: :portrait) do |pdf|
    # pdf.stroke_axis
    pdf.font_size 10
    pdf.font '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'

    gap = 10
    y_coordinate = 780 # top of the page
    columns = [300, 140, 80] # widths of the columns in the header
    max_height = 0 # keep track of the highest stretchy bounding box (since Prawn doesn't)

    # First header row

    pdf.bounding_box([0, y_coordinate], width: columns[0]) do
      lines = customer_address_lines data['customer']
      lines.each { |line| pdf.text line }

      if data['building']
        pdf.move_down 5
        pdf.text 'Gebouw:'
        lines = building_address_lines data['building']
        lines.each { |line| pdf.text line }
      end

      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    pdf.bounding_box([columns[0], y_coordinate], width: columns[1]) do
      if data['requestDate']
        date = Date.parse data['requestDate']
        pdf.text 'Aanvraag: ' + date.strftime("%d-%m-%Y")
      end
      if data['visit'] and data['visit']['visitDate']
        date = Date.parse data['visit']['visitDate']
        pdf.text 'Bezoek:     ' + date.strftime("%d-%m-%Y")

        if data['visit']['calendarSubject']
          period = data['visit']['calendarSubject'].split(data['customer']['name']).first.chop
          pdf.indent(55) { pdf.text period }
        end
      end

      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    pdf.bounding_box([columns[0] + columns[1], y_coordinate], width:  columns[2]) do
      pdf.text "Nr:    #{data['id']}"
      
      language = 'Taal: '
      language += data['customer']['language']['code'] if data['customer']['language']
      pdf.text language
      
      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    # End of first header row

    y_coordinate = y_coordinate - max_height - gap
    max_height = 0
    
    # Second header row
    
    pdf.bounding_box([0, y_coordinate], width: columns[0]) do
      way_of_entry = 'Aanmelding: '
      way_of_entry += data['wayOfEntry']['name'] if data['wayOfEntry']
      pdf.text way_of_entry

      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end
    
    pdf.bounding_box([columns[0], y_coordinate], width: columns[1]) do
      visitor = 'Bezoeker: '
      visitor += data['visit']['visitor'] if data['visit']
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
      pdf.indent(10) { pdf.text 'Klant: ' + data['customer']['email'] } if data['customer']['email']
      pdf.indent(45) { pdf.text data['customer']['email2'] } if data['customer']['email2']
      pdf.indent(10) { pdf.text 'Contact: ' + data['contact']['email'] } if data['contact'] and data['contact']['email']      
      pdf.text "#{data['employee']} noteerde: #{data['comment'] || ''}"

      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    pdf.bounding_box([columns[0] + columns[1], y_coordinate], width: columns[2]) do
      pdf.text "\u25A2 Post" # checkboxes
      pdf.text "\u25A2 E-post"
      
      max_height = pdf.bounds.height if max_height < pdf.bounds.height
    end

    # End of third header row
  end
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
