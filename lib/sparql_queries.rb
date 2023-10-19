def fetch_uri(id)
  query = "SELECT ?uri WHERE { ?uri <http://mu.semte.ch/vocabularies/core/uuid> #{id.sparql_escape} . } LIMIT 1"
  solution = Mu::query(query).first[:uri].value
end

def fetch_case(case_uri)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX frapo: <http://purl.org/cerif/frapo/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX dossier: <https://data.vlaanderen.be/ns/dossier#>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX nco: <http://www.semanticdesktop.org/ontologies/2007/03/22/nco#>
    PREFIX gebouw: <https://data.vlaanderen.be/ns/gebouw#>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    PREFIX p2poDocument: <https://purl.org/p2p-o/document#>
    SELECT ?identifier ?reference ?comment ?delivery_method
           ?customer_uri ?customer_id ?contact_uri ?contact_id ?building_uri ?building_id
           ?intervention_uri ?intervention_id ?request_uri ?request_id ?offer_uri ?offer_id
           ?order_uri ?order_id ?invoice_uri ?invoice_id
    WHERE {
      #{Mu::sparql_escape_uri(case_uri)} a dossier:Dossier ;
        dct:identifier ?identifier .
      OPTIONAL { #{Mu::sparql_escape_uri(case_uri)} frapo:hasReferenceNumber ?reference . }
      OPTIONAL { #{Mu::sparql_escape_uri(case_uri)} skos:comment ?comment . }
      OPTIONAL { #{Mu::sparql_escape_uri(case_uri)} schema:deliveryMethod ?delivery_method . }
      #{Mu::sparql_escape_uri(case_uri)} schema:customer ?customer_uri .
      ?customer_uri a vcard:VCard ;
        mu:uuid ?customer_id .
      OPTIONAL {
        #{Mu::sparql_escape_uri(case_uri)} crm:contact ?contact_uri .
        ?contact_uri a nco:Contact ;
          mu:uuid ?contact_id .
      }
      OPTIONAL {
        #{Mu::sparql_escape_uri(case_uri)} crm:building ?building_uri .
        ?building_uri a gebouw:Gebouw ;
          mu:uuid ?building_id .
      }
      OPTIONAL {
        #{Mu::sparql_escape_uri(case_uri)} ext:intervention ?intervention_uri .
        ?intervention_uri a crm:Intervention ;
          mu:uuid ?intervention_id .
      }
      OPTIONAL {
        #{Mu::sparql_escape_uri(case_uri)} ext:request ?request_uri .
        ?request_uri a crm:Request ;
          mu:uuid ?request_id .
      }
      OPTIONAL {
        #{Mu::sparql_escape_uri(case_uri)} ext:offer ?offer_uri .
        ?offer_uri a schema:Offer ;
          mu:uuid ?offer_id .
      }
      OPTIONAL {
        #{Mu::sparql_escape_uri(case_uri)} ext:order ?order_uri .
        ?order_uri a p2poDocument:PurchaseOrder ;
          mu:uuid ?order_id .
      }
      OPTIONAL {
        #{Mu::sparql_escape_uri(case_uri)} ext:invoice ?invoice_uri .
        ?invoice_uri a p2poInvoice:E-FinalInvoice ;
          mu:uuid ?invoice_id .
      }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  _case = {
    identifier: solution[:identifier].value,
    reference: solution[:reference]&.value,
    comment: solution[:comment]&.value,
    delivery_method: solution[:delivery_method]&.value
  }
  [:customer, :contact, :building, :intervention, :request, :offer, :order, :invoice].each do |key|
    id_key = "#{key}_id".to_sym
    uri_key = "#{key}_uri".to_sym
    if solution[id_key] or solution[uri_key]
      _case[key] = {
        uri: solution[uri_key]&.value,
        id: solution[id_key]&.value
      }
    end
  end

  _case
end

def fetch_customer(customer_uri)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    SELECT ?uri ?type ?number ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?vat_number ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country
    WHERE {
      BIND (#{Mu::sparql_escape_uri(customer_uri)} as ?uri) .
      ?uri a vcard:VCard ;
        dct:type ?type ;
        vcard:hasUID ?number .
      OPTIONAL { ?uri vcard:hasHonorificPrefix ?hon_prefix . }
      OPTIONAL { ?uri vcard:hasGivenName ?first_name . }
      OPTIONAL { ?uri vcard:hasFamilyName ?last_name . }
      OPTIONAL { ?uri vcard:hasHonorificSuffix ?suffix . }
      OPTIONAL { ?uri crm:printPrefix ?print_prefix . }
      OPTIONAL { ?uri crm:printSuffix ?print_suffix . }
      OPTIONAL { ?uri crm:printSuffixInFront ?print_suffix_in_front . }
      OPTIONAL { ?uri schema:vatID ?vat_number . }
      OPTIONAL {
        ?uri vcard:hasLanguage ?language .
        ?language schema:name ?language_name ;
          schema:identifier ?language_code .
      }
      OPTIONAL {
        ?uri vcard:hasAddress ?address .
        OPTIONAL { ?address vcard:hasStreetAddress ?street . }
        OPTIONAL { ?address vcard:hasPostalCode ?postal_code . }
        OPTIONAL { ?address vcard:hasLocality ?city . }
        OPTIONAL { ?address vcard:hasCountryName/schema:name ?country . }
      }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  if solution
    if solution[:language]
      language = {
        uri: solution[:language]&.value,
        name: solution[:language_name]&.value,
        code: solution[:language_code]&.value
      }
    end
    if solution[:address]
      address = {
        uri: solution[:address]&.value,
        street: solution[:street]&.value,
        postal_code: solution[:postal_code]&.value,
        city: solution[:city]&.value,
        country: solution[:country]&.value
      }
    end
    {
      uri: solution[:uri].value,
      type: solution[:type].value,
      number: solution[:number].value,
      honorific_prefix: solution[:hon_prefix]&.value,
      first_name: solution[:first_name]&.value,
      last_name: solution[:last_name]&.value,
      suffix: solution[:suffix]&.value,
      print_prefix: solution[:print_prefix]&.value.to_b,
      print_suffix: solution[:print_suffix]&.value.to_b,
      print_suffix_in_front: solution[:print_suffix_in_front]&.value.to_b,
      vat_number: solution[:vat_number]&.value,
      language: language,
      address: address
    }
  else
    nil
  end
end

def fetch_contact(contact_uri)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX nco: <http://www.semanticdesktop.org/ontologies/2007/03/22/nco#>
    SELECT ?uri ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country
    WHERE {
      BIND (#{Mu::sparql_escape_uri(contact_uri)} as ?uri) .
      ?uri a nco:Contact .
      OPTIONAL { ?uri vcard:hasHonorificPrefix ?hon_prefix . }
      OPTIONAL { ?uri vcard:hasGivenName ?first_name . }
      OPTIONAL { ?uri vcard:hasFamilyName ?last_name . }
      OPTIONAL { ?uri vcard:hasHonorificSuffix ?suffix . }
      OPTIONAL { ?uri crm:printPrefix ?print_prefix . }
      OPTIONAL { ?uri crm:printSuffix ?print_suffix . }
      OPTIONAL { ?uri crm:printSuffixInFront ?print_suffix_in_front . }
      OPTIONAL {
        ?uri vcard:hasLanguage ?language .
        ?language schema:name ?language_name ;
          schema:identifier ?language_code .
      }
      OPTIONAL {
        ?uri vcard:hasAddress ?address .
        OPTIONAL { ?address vcard:hasStreetAddress ?street . }
        OPTIONAL { ?address vcard:hasPostalCode ?postal_code . }
        OPTIONAL { ?address vcard:hasLocality ?city . }
        OPTIONAL { ?address vcard:hasCountryName/schema:name ?country . }
      }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  if solution
    if solution[:language]
      language = {
        uri: solution[:language]&.value,
        name: solution[:language_name]&.value,
        code: solution[:language_code]&.value
      }
    end
    if solution[:address]
      address = {
        uri: solution[:address]&.value,
        street: solution[:street]&.value,
        postal_code: solution[:postal_code]&.value,
        city: solution[:city]&.value,
        country: solution[:country]&.value
      }
    end
    {
      uri: solution[:uri].value,
      honorific_prefix: solution[:hon_prefix]&.value,
      first_name: solution[:first_name]&.value,
      last_name: solution[:last_name]&.value,
      suffix: solution[:suffix]&.value,
      print_prefix: solution[:print_prefix]&.value.to_b,
      print_suffix: solution[:print_suffix]&.value.to_b,
      print_suffix_in_front: solution[:print_suffix_in_front]&.value.to_b,
      language: language,
      address: address
    }
  else
    nil
  end
end

def fetch_building(building_uri)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX gebouw: <https://data.vlaanderen.be/ns/gebouw#>
    SELECT ?uri ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country
    WHERE {
      BIND (#{Mu::sparql_escape_uri(building_uri)} as ?uri) .
      ?uri a gebouw:Gebouw .
      OPTIONAL { ?uri vcard:hasHonorificPrefix ?hon_prefix . }
      OPTIONAL { ?uri vcard:hasGivenName ?first_name . }
      OPTIONAL { ?uri vcard:hasFamilyName ?last_name . }
      OPTIONAL { ?uri vcard:hasHonorificSuffix ?suffix . }
      OPTIONAL { ?uri crm:printPrefix ?print_prefix . }
      OPTIONAL { ?uri crm:printSuffix ?print_suffix . }
      OPTIONAL { ?uri crm:printSuffixInFront ?print_suffix_in_front . }
      OPTIONAL {
        ?uri vcard:hasLanguage ?language .
        ?language schema:name ?language_name ;
          schema:identifier ?language_code .
      }
      OPTIONAL {
        ?uri vcard:hasAddress ?address .
        OPTIONAL { ?address vcard:hasStreetAddress ?street . }
        OPTIONAL { ?address vcard:hasPostalCode ?postal_code . }
        OPTIONAL { ?address vcard:hasLocality ?city . }
        OPTIONAL { ?address vcard:hasCountryName/schema:name ?country . }
      }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  if solution
    if solution[:language]
      language = {
        uri: solution[:language]&.value,
        name: solution[:language_name]&.value,
        code: solution[:language_code]&.value
      }
    end
    if solution[:address]
      address = {
        uri: solution[:address]&.value,
        street: solution[:street]&.value,
        postal_code: solution[:postal_code]&.value,
        city: solution[:city]&.value,
        country: solution[:country]&.value
      }
    end
    {
      uri: solution[:uri].value,
      honorific_prefix: solution[:hon_prefix]&.value,
      first_name: solution[:first_name]&.value,
      last_name: solution[:last_name]&.value,
      suffix: solution[:suffix]&.value,
      print_prefix: solution[:print_prefix]&.value.to_b,
      print_suffix: solution[:print_suffix]&.value.to_b,
      print_suffix_in_front: solution[:print_suffix_in_front]&.value.to_b,
      language: language,
      address: address
    }
  else
    nil
  end
end

def fetch_request(id)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX frapo: <http://purl.org/cerif/frapo/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    SELECT ?uri ?date ?number ?visitor ?visitor_name ?visitor_initials ?employee ?way_of_entry ?case ?description
    WHERE {
      ?uri a crm:Request ;
        mu:uuid #{id.sparql_escape} ;
        dct:issued ?date ;
        schema:identifier ?number .
      ?case ext:request ?uri .
      OPTIONAL {
        ?uri crm:visitor ?visitor .
        ?visitor foaf:firstName ?visitor_name ;
          frapo:initial ?visitor_initials .
      }
      OPTIONAL { ?uri crm:employee/foaf:firstName ?employee . }
      OPTIONAL { ?uri crm:wayOfEntry/skos:prefLabel ?way_of_entry . }
      OPTIONAL { ?uri dct:description ?description . }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  if solution
    if solution[:visitor]
      visitor = {
        uri: solution[:visitor].value,
        name: solution[:visitor_name]&.value,
        initials: solution[:visitor_initials]&.value
      }
    end
    {
      uri: solution[:uri].value,
      id: id,
      date: solution[:date].value,
      number: solution[:number].value,
      visitor: visitor,
      employee: solution[:employee]&.value,
      way_of_entry: solution[:way_of_entry]&.value,
      description: solution[:description]&.value,
      case_uri: solution[:case].value
    }
  else
    nil
  end
end

def fetch_intervention(id)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
    SELECT ?uri ?date ?number ?employee ?way_of_entry ?case ?description ?comment
    WHERE {
      ?uri a crm:Intervention ;
        mu:uuid #{id.sparql_escape} ;
        dct:issued ?date ;
        schema:identifier ?number .
      ?case ext:intervention ?uri .
      OPTIONAL { ?uri crm:employee/foaf:firstName ?employee . }
      OPTIONAL { ?uri crm:wayOfEntry/skos:prefLabel ?way_of_entry . }
      OPTIONAL { ?uri dct:description ?description . }
      OPTIONAL { ?uri skos:comment ?comment . }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  technicians = Mu::query(%{
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    SELECT ?technician
    WHERE {
      ?uri a crm:Intervention ;
        mu:uuid #{id.sparql_escape} ;
        crm:plannedTechnicians/foaf:firstName ?technician .
    }
  }).map { |solution| solution[:technician].value }

  if solution
    {
      uri: solution[:uri].value,
      id: id,
      date: solution[:date].value,
      number: solution[:number].value,
      employee: solution[:employee]&.value,
      way_of_entry: solution[:way_of_entry]&.value,
      description: solution[:description]&.value,
      comment: solution[:comment]&.value,
      technicians: technicians,
      case_uri: solution[:case].value
    }
  else
    nil
  end
end

def fetch_offer(id)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX owl: <http://www.w3.org/2002/07/owl#>

    SELECT ?uri ?date ?number ?case ?document_version ?document_intro ?document_outro
    WHERE {
      ?uri a schema:Offer ;
        mu:uuid #{id.sparql_escape} ;
        dct:issued ?date ;
        schema:identifier ?number .
      ?case ext:offer ?uri .
      OPTIONAL { ?uri owl:versionInfo ?document_version . }
      OPTIONAL { ?uri crm:documentIntro ?document_intro . }
      OPTIONAL { ?uri crm:documentOutro ?document_outro . }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  if solution
    {
      uri: solution[:uri].value,
      id: id,
      date: solution[:date].value,
      number: solution[:number].value,
      document_version: solution[:document_version]&.value,
      document_intro: solution[:document_intro]&.value,
      document_outro: solution[:document_outro]&.value,
      case_uri: solution[:case].value
    }
  else
    nil
  end
end

def fetch_order(id)
  query = %{
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX p2poDocument: <https://purl.org/p2p-o/document#>
    PREFIX tmo: <http://www.semanticdesktop.org/ontologies/2008/05/20/tmo#>

    SELECT ?uri ?date ?case ?expected_date ?required_date
    WHERE {
      ?uri a p2poDocument:PurchaseOrder ;
        mu:uuid #{id.sparql_escape} ;
        dct:issued ?date .
      ?case ext:order ?uri .
      OPTIONAL { ?uri tmo:targetTime ?expected_date . }
      OPTIONAL { ?uri tmo:dueDate ?required_date . }
    } LIMIT 1
  }
  solution = Mu::query(query).first

  if solution
    {
      uri: solution[:uri].value,
      id: id,
      date: solution[:date].value,
      expected_date: solution[:expected_date]&.value,
      required_date: solution[:required_date]&.value,
      case_uri: solution[:case].value
    }
  else
    nil
  end
end

def fetch_invoice(invoice_id)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX dossier: <https://data.vlaanderen.be/ns/dossier#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>
    PREFIX p2poPrice: <https://purl.org/p2p-o/price#>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    PREFIX p2poDocument: <https://purl.org/p2p-o/document#>
    PREFIX frapo: <http://purl.org/cerif/frapo/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    SELECT ?invoice ?date ?type ?number ?amount ?rate ?vatCode ?dueDate ?paymentDate ?paidDeposits ?outro ?reference ?case
    WHERE {
      ?invoice a p2poDocument:E-Invoice ;
        mu:uuid #{invoice_id.sparql_escape} ;
        p2poInvoice:dateOfIssue ?date ;
        p2poInvoice:invoiceNumber ?number ;
        p2poInvoice:hasTotalLineNetAmount ?amount .
      OPTIONAL { ?invoice dct:type ?type . }
      OPTIONAL { ?invoice p2poInvoice:paymentDueDate ?dueDate . }
      OPTIONAL { ?invoice crm:paymentDate ?paymentDate . }
      OPTIONAL { ?invoice crm:paidDeposits ?paidDeposits . }
      OPTIONAL { ?invoice p2poInvoice:paymentTerms ?outro . }
      ?case ?caseP ?invoice ;
        p2poPrice:hasVATCategoryCode ?vatRate .
      FILTER (?caseP = ext:invoice || ?caseP = ext:depositInvoice)
      ?vatRate a price:VatRate ;
        schema:value ?rate ;
        schema:identifier ?vatCode .
      OPTIONAL { ?case frapo:hasReferenceNumber ?reference . }
    } LIMIT 1
  }
  solution = Mu::query(query).first
  if solution
    {
      id: invoice_id,
      uri: solution[:invoice].value,
      is_credit_note: solution[:type]&.value == 'https://purl.org/p2p-o/invoice#E-CreditNote',
      invoice_date: solution[:date].value,
      number: solution[:number].value,
      amount: solution[:amount].value.to_f,
      date: solution[:date]&.value,
      due_date: solution[:dueDate]&.value,
      payment_date: solution[:paymentDate]&.value,
      paid_deposits: solution[:paidDeposits]&.value.to_f,
      vat_rate: solution[:rate].value.to_i,
      vat_code: solution[:vatCode],
      outro: solution[:outro]&.value,
      reference: solution[:reference]&.value,
      case_uri: solution[:case]&.value
    }
  else
    nil
  end
end

def fetch_calendar_event(subject_uri)
  query = %{
    PREFIX ncal: <http://www.semanticdesktop.org/ontologies/2007/04/02/ncal#>
    PREFIX dct: <http://purl.org/dc/terms/>
    SELECT ?event ?date ?subject
    WHERE {
      ?event a ncal:Event ;
        dct:subject <#{subject_uri}> ;
        ncal:date ?date ;
        ncal:summary ?subject .
    } LIMIT 1
  }
  solutions = Mu::query(query)

  events = solutions.map do |solution|
    {
      uri: solution[:event].value,
      date: solution[:date].value,
      subject: solution[:subject].value
    }
  end

  events.first
end

def fetch_telephones(record_uri)
  solutions = Mu::query %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX dct: <http://purl.org/dc/terms/>
    SELECT ?telephone ?value ?position ?prefix ?note
    WHERE {
      #{Mu::sparql_escape_uri(record_uri)} vcard:hasTelephone ?telephone .
      ?telephone a vcard:Telephone ;
        vcard:hasValue ?value ;
        vcard:hasCountryName ?country ;
        schema:position ?position ;
        dct:type <http://www.w3.org/2006/vcard/ns#Voice> .
      ?country a schema:Country ;
        crm:telephonePrefix ?prefix .
      OPTIONAL { ?telephone vcard:hasNote ?note . }
    } ORDER BY ?position
  }

  solutions.map do |solution|
    {
      uri: solution[:telephone].value,
      value: solution[:value].value,
      position: solution[:position].value,
      prefix: solution[:prefix].value,
      note: solution[:note]&.value
    }
  end
end


def fetch_emails(record_uri)
  solutions = Mu::query %{
    PREFIX schema: <http://schema.org/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX dct: <http://purl.org/dc/terms/>
    SELECT ?email ?value ?note
    WHERE {
      #{Mu::sparql_escape_uri(record_uri)} vcard:hasEmail ?email .
      ?email a vcard:Email ;
        vcard:hasValue ?value .
      OPTIONAL { ?email vcard:hasNote ?note . }
    } ORDER BY ?value
  }

  solutions.map do |solution|
    {
      uri: solution[:email].value,
      value: solution[:value].value,
      note: solution[:note]&.value
    }
  end
end

def fetch_offerlines(offer_uri)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>
    SELECT ?offerline ?description ?amount ?vatCode ?rate
    WHERE {
      ?offerline a crm:Offerline ;
        dct:isPartOf <#{offer_uri}> ;
        schema:amount ?amount ;
        price:hasVatRate ?vatRate ;
        schema:position ?position .
      ?vatRate a price:VatRate ;
        schema:value ?rate ;
        schema:identifier ?vatCode .
      OPTIONAL { ?offerline dct:description ?description . }
    } ORDER BY ?position
  }
  solutions = Mu::query(query)

  solutions.map do |solution|
    {
      uri: solution[:offerline].value,
      description: solution[:description]&.value,
      amount: solution[:amount].value.to_f,
      vat_rate: solution[:rate].value.to_i,
      vat_code: solution[:vatCode].value
    }
  end
end

def fetch_invoicelines(order_uri: nil, invoice_uri: nil)
  order_stmt = if (order_uri) then "?invoiceline dct:isPartOf <#{order_uri}> ." else '' end
  invoice_stmt = if (invoice_uri) then "<#{invoice_uri}> p2poInvoice:hasInvoiceLine ?invoiceline." else '' end

  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    SELECT ?invoiceline ?description ?amount ?rate ?vatCode
    WHERE {
      ?invoiceline a crm:Invoiceline ;
        schema:amount ?amount ;
        price:hasVatRate ?vatRate ;
        schema:position ?position .
      #{order_stmt}
      #{invoice_stmt}
      ?vatRate a price:VatRate ;
        schema:value ?rate ;
        schema:identifier ?vatCode .
      OPTIONAL { ?invoiceline dct:description ?description . }
    } ORDER BY ?position
  }
  solutions = Mu::query(query)

  solutions.map do |solution|
    {
      uri: solution[:invoiceline].value,
      description: if solution[:description] then solution[:description] end,
      amount: solution[:amount].value.to_f,
      vat_rate: solution[:rate].value.to_i,
      vat_code: solution[:vatCode]
    }
  end
end

def fetch_deposit_invoices_for_invoice(invoice_id)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX dossier: <https://data.vlaanderen.be/ns/dossier#>
    PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>
    PREFIX p2poPrice: <https://purl.org/p2p-o/price#>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    SELECT ?depositInvoice ?type ?number ?amount
    WHERE {
      ?depositInvoice a p2poInvoice:E-PrePaymentInvoice ;
        p2poInvoice:invoiceNumber ?number ;
        p2poInvoice:hasTotalLineNetAmount ?amount .
      OPTIONAL { ?depositInvoice dct:type ?type . }
      ?case ext:depositInvoice ?depositInvoice .
      ?case ext:invoice ?invoice .
      ?invoice a p2poInvoice:E-FinalInvoice ;
        mu:uuid #{invoice_id.sparql_escape} .
    } ORDER BY ?number
  }
  solutions = Mu::query(query)

  solutions.map do |solution|
    {
      uri: solution[:depositInvoice].value,
      is_credit_note: solution[:type]&.value == 'https://purl.org/p2p-o/invoice#E-CreditNote',
      number: solution[:number].value,
      amount: solution[:amount].value.to_f
    }
  end
end

def fetch_employee_by_name(name)
  query = %{
    PREFIX person: <http://www.w3.org/ns/person#>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>
    PREFIX frapo: <http://purl.org/cerif/frapo/>
    SELECT ?employee ?initials
    WHERE {
      ?employee a person:Person ;
        foaf:firstName ?firstName .
      FILTER(LCASE(?firstName) = #{name.downcase.sparql_escape})
      OPTIONAL { ?employee frapo:initial ?initials . }
    } LIMIT 1
  }
  solution = Mu::query(query).first
  if solution
    {
      uri: solution[:employee].value,
      initials: solution[:initials].value
    }
  else
    nil
  end
end

def fetch_recent_offers(customer_uri, case_uri)
  query = %{
    PREFIX schema: <http://schema.org/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX frapo: <http://purl.org/cerif/frapo/>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    SELECT ?offer ?request_number ?offer_date ?visitor ?order
    WHERE {
      #{Mu::sparql_escape_uri(customer_uri)} a vcard:VCard .
      ?case schema:customer #{Mu::sparql_escape_uri(customer_uri)} ;
        ext:request ?request ;
        ext:offer ?offer .
      ?offer dct:issued ?offer_date .
      ?request schema:identifier ?request_number .
      OPTIONAL { ?request crm:visitor/frapo:initial ?visitor .}
      OPTIONAL { ?case ext:order ?order . }
      FILTER (?case != #{Mu::sparql_escape_uri(case_uri)})
    } ORDER BY DESC(?offer_date) LIMIT 5
  }
  solutions = Mu::query(query)

  solutions.map do |solution|
    {
      uri: solution[:offer].value,
      number: solution[:request_number].value,
      date: DateTime.parse(solution[:offer_date].value),
      visitor: solution[:visitor]&.value,
      is_ordered: !solution[:order].nil?
    }
  end
end

def fetch_user_for_session(session)
  solutions = Mu::query %{
    PREFIX muSession: <http://mu.semte.ch/vocabularies/session/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>

    SELECT ?user
    WHERE {
      #{Mu::sparql_escape_uri(session)} muSession:account ?account .
      ?user foaf:account ?account .
    } LIMIT 1
  }
  solutions.first[:user]&.value
end
