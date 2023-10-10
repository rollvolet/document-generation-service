def fetch_case(case_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX frapo: <http://purl.org/cerif/frapo/>"
  query += " PREFIX skos: <http://www.w3.org/2004/02/skos/core#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX dossier: <https://data.vlaanderen.be/ns/dossier#>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX nco: <http://www.semanticdesktop.org/ontologies/2007/03/22/nco#>"
  query += " PREFIX gebouw: <https://data.vlaanderen.be/ns/gebouw#>"
  query += " PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>"
  query += " PREFIX p2poDocument: <https://purl.org/p2p-o/document#>"
  query += " SELECT ?identifier ?reference ?comment"
  query += "        ?customer_uri ?customer_id ?contact_uri ?contact_id ?building_uri ?building_id"
  query += "        ?intervention_uri ?intervention_id ?request_uri ?request_id ?offer_uri ?offer_id"
  query += "        ?order_uri ?order_id ?invoice_uri ?invoice_id"
  query += " WHERE {"
  query += "   #{Mu.sparql_escape_uri(case_uri)} a dossier:Dossier ;"
  query += "     dct:identifier ?identifier ."
  query += "   OPTIONAL { #{Mu.sparql_escape_uri(case_uri)} frapo:hasReferenceNumber ?reference . }"
  query += "   OPTIONAL { #{Mu.sparql_escape_uri(case_uri)} skos:comment ?comment . }"
  query += "   #{Mu.sparql_escape_uri(case_uri)} schema:customer ?customer_uri ."
  query += "   ?customer_uri a vcard:VCard ;"
  query += "     mu:uuid ?customer_id ."
  query += "   OPTIONAL {"
  query += "     #{Mu.sparql_escape_uri(case_uri)} crm:contact ?contact_uri ."
  query += "     ?contact_uri a nco:Contact ;"
  query += "       mu:uuid ?contact_id ."
  query += "   }"
  query += "   OPTIONAL {"
  query += "     #{Mu.sparql_escape_uri(case_uri)} crm:building ?building_uri ."
  query += "     ?building_uri a gebouw:Gebouw ;"
  query += "       mu:uuid ?building_id ."
  query += "   }"
  query += "   OPTIONAL {"
  query += "     #{Mu.sparql_escape_uri(case_uri)} ext:intervention ?intervention_uri ."
  query += "     ?intervention_uri a crm:Intervention ;"
  query += "       mu:uuid ?intervention_id ."
  query += "   }"
  query += "   OPTIONAL {"
  query += "     #{Mu.sparql_escape_uri(case_uri)} ext:request ?request_uri ."
  query += "     ?request_uri a crm:Request ;"
  query += "       mu:uuid ?request_id ."
  query += "   }"
  query += "   OPTIONAL {"
  query += "     #{Mu.sparql_escape_uri(case_uri)} ext:offer ?offer_uri ."
  query += "     ?offer_uri a schema:Offer ;"
  query += "       mu:uuid ?offer_id ."
  query += "   }"
  query += "   OPTIONAL {"
  query += "     #{Mu.sparql_escape_uri(case_uri)} ext:order ?order_uri ."
  query += "     ?order_uri a p2poDocument:PurchaseOrder ;"
  query += "       mu:uuid ?order_id ."
  query += "   }"
  query += "   OPTIONAL {"
  query += "     #{Mu.sparql_escape_uri(case_uri)} ext:invoice ?invoice_uri ."
  query += "     ?invoice_uri a p2poInvoice:E-FinalInvoice ;"
  query += "       mu:uuid ?invoice_id ."
  query += "   }"
  query += " } LIMIT 1"

  solution = Mu.query(query).first

  _case = {
    identifier: solution[:identifier].value,
    reference: solution[:reference]&.value,
    comment: solution[:comment]&.value
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
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " SELECT ?uri ?type ?number ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?vat_number ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country"
  query += " WHERE {"
  query += "   BIND (#{Mu.sparql_escape_uri(customer_uri)} as ?uri) ."
  query += "   ?uri a vcard:VCard ;"
  query += "     dct:type ?type ;"
  query += "     vcard:hasUID ?number ."
  query += "   OPTIONAL { ?uri vcard:hasHonorificPrefix ?hon_prefix . }"
  query += "   OPTIONAL { ?uri vcard:hasGivenName ?first_name . }"
  query += "   OPTIONAL { ?uri vcard:hasFamilyName ?last_name . }"
  query += "   OPTIONAL { ?uri vcard:hasHonorificSuffix ?suffix . }"
  query += "   OPTIONAL { ?uri crm:printPrefix ?print_prefix . }"
  query += "   OPTIONAL { ?uri crm:printSuffix ?print_suffix . }"
  query += "   OPTIONAL { ?uri crm:printSuffixInFront ?print_suffix_in_front . }"
  query += "   OPTIONAL { ?uri schema:vatID ?vat_number . }"
  query += "   OPTIONAL { "
  query += "     ?uri vcard:hasLanguage ?language . "
  query += "     ?language schema:name ?language_name ; "
  query += "       schema:identifier ?language_code . "
  query += "   }"
  query += "   OPTIONAL { "
  query += "     ?uri vcard:hasAddress ?address . "
  query += "     OPTIONAL { ?address vcard:hasStreetAddress ?street . }"
  query += "     OPTIONAL { ?address vcard:hasPostalCode ?postal_code . }"
  query += "     OPTIONAL { ?address vcard:hasLocality ?city . }"
  query += "     OPTIONAL { ?address vcard:hasCountryName/schema:name ?country . }"
  query += "   }"
  query += " } LIMIT 1"


  solutions = Mu.query(query)

  customers = solutions.map do |solution|
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
  end

  customers.first
end

def fetch_contact(contact_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX nco: <http://www.semanticdesktop.org/ontologies/2007/03/22/nco#>"
  query += " SELECT ?uri ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country"
  query += " WHERE {"
  query += "   BIND (#{Mu.sparql_escape_uri(contact_uri)} as ?uri) ."
  query += "   ?uri a nco:Contact ."
  query += "   OPTIONAL { ?uri vcard:hasHonorificPrefix ?hon_prefix . }"
  query += "   OPTIONAL { ?uri vcard:hasGivenName ?first_name . }"
  query += "   OPTIONAL { ?uri vcard:hasFamilyName ?last_name . }"
  query += "   OPTIONAL { ?uri vcard:hasHonorificSuffix ?suffix . }"
  query += "   OPTIONAL { ?uri crm:printPrefix ?print_prefix . }"
  query += "   OPTIONAL { ?uri crm:printSuffix ?print_suffix . }"
  query += "   OPTIONAL { ?uri crm:printSuffixInFront ?print_suffix_in_front . }"
  query += "   OPTIONAL { "
  query += "     ?uri vcard:hasLanguage ?language . "
  query += "     ?language schema:name ?language_name ; "
  query += "       schema:identifier ?language_code . "
  query += "   }"
  query += "   OPTIONAL { "
  query += "     ?uri vcard:hasAddress ?address . "
  query += "     OPTIONAL { ?address vcard:hasStreetAddress ?street . }"
  query += "     OPTIONAL { ?address vcard:hasPostalCode ?postal_code . }"
  query += "     OPTIONAL { ?address vcard:hasLocality ?city . }"
  query += "     OPTIONAL { ?address vcard:hasCountryName/schema:name ?country . }"
  query += "   }"
  query += " } LIMIT 1"

  solutions = Mu.query(query)

  contacts = solutions.map do |solution|
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
  end

  contacts.first
end

def fetch_building(building_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX gebouw: <https://data.vlaanderen.be/ns/gebouw#>"
  query += " SELECT ?uri ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country"
  query += " WHERE {"
  query += "   BIND (#{Mu.sparql_escape_uri(building_uri)} as ?uri) ."
  query += "   ?uri a gebouw:Gebouw ."
  query += "   OPTIONAL { ?uri vcard:hasHonorificPrefix ?hon_prefix . }"
  query += "   OPTIONAL { ?uri vcard:hasGivenName ?first_name . }"
  query += "   OPTIONAL { ?uri vcard:hasFamilyName ?last_name . }"
  query += "   OPTIONAL { ?uri vcard:hasHonorificSuffix ?suffix . }"
  query += "   OPTIONAL { ?uri crm:printPrefix ?print_prefix . }"
  query += "   OPTIONAL { ?uri crm:printSuffix ?print_suffix . }"
  query += "   OPTIONAL { ?uri crm:printSuffixInFront ?print_suffix_in_front . }"
  query += "   OPTIONAL { "
  query += "     ?uri vcard:hasLanguage ?language . "
  query += "     ?language schema:name ?language_name ; "
  query += "       schema:identifier ?language_code . "
  query += "   }"
  query += "   OPTIONAL { "
  query += "     ?uri vcard:hasAddress ?address . "
  query += "     OPTIONAL { ?address vcard:hasStreetAddress ?street . }"
  query += "     OPTIONAL { ?address vcard:hasPostalCode ?postal_code . }"
  query += "     OPTIONAL { ?address vcard:hasLocality ?city . }"
  query += "     OPTIONAL { ?address vcard:hasCountryName/schema:name ?country . }"
  query += "   }"
  query += " } LIMIT 1"

  solutions = Mu.query(query)

  buildings = solutions.map do |solution|
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
  end

  buildings.first
end

def fetch_request(id)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX frapo: <http://purl.org/cerif/frapo/>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX foaf: <http://xmlns.com/foaf/0.1/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>"
  query += " PREFIX skos: <http://www.w3.org/2004/02/skos/core#>"
  query += " SELECT ?uri ?date ?number ?visitor ?visitor_name ?visitor_initials ?employee ?way_of_entry ?case ?description"
  query += " WHERE {"
  query += "   ?uri a crm:Request ;"
  query += "     mu:uuid #{id.sparql_escape} ;"
  query += "     dct:issued ?date ;"
  query += "     schema:identifier ?number ."
  query += "   ?case ext:request ?uri ."
  query += "   OPTIONAL { "
  query += "     ?uri crm:visitor ?visitor . "
  query += "     ?visitor foaf:firstName ?visitor_name ; "
  query += "       frapo:initial ?visitor_initials . "
  query += "   }"
  query += "   OPTIONAL { ?uri crm:employee/foaf:firstName ?employee . }"
  query += "   OPTIONAL { ?uri crm:wayOfEntry/skos:prefLabel ?way_of_entry . }"
  query += "   OPTIONAL { ?uri dct:description ?description . }"
  query += " } LIMIT 1"

  solution = Mu.query(query).first

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
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX foaf: <http://xmlns.com/foaf/0.1/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>"
  query += " PREFIX skos: <http://www.w3.org/2004/02/skos/core#>"
  query += " SELECT ?uri ?date ?number ?employee ?way_of_entry ?case ?description ?comment"
  query += " WHERE {"
  query += "   ?uri a crm:Intervention ;"
  query += "     mu:uuid #{id.sparql_escape} ;"
  query += "     dct:issued ?date ;"
  query += "     schema:identifier ?number ."
  query += "   ?case ext:intervention ?uri ."
  query += "   OPTIONAL { ?uri crm:employee/foaf:firstName ?employee . }"
  query += "   OPTIONAL { ?uri crm:wayOfEntry/skos:prefLabel ?way_of_entry . }"
  query += "   OPTIONAL { ?uri dct:description ?description . }"
  query += "   OPTIONAL { ?uri skos:comment ?comment . }"
  query += " } LIMIT 1"

  solution = Mu.query(query).first

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
      case_uri: solution[:case].value
    }
  else
    nil
  end
end

def fetch_invoice(invoice_id)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX dossier: <https://data.vlaanderen.be/ns/dossier#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>"
  query += " PREFIX p2poPrice: <https://purl.org/p2p-o/price#>"
  query += " PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>"
  query += " PREFIX p2poDocument: <https://purl.org/p2p-o/document#>"
  query += " PREFIX frapo: <http://purl.org/cerif/frapo/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>"
  query += " SELECT ?invoice ?date ?type ?number ?amount ?rate ?vatCode ?dueDate ?paymentDate ?paidDeposits ?outro ?reference ?case"
  query += " WHERE {"
  query += "   ?invoice a p2poDocument:E-Invoice ;"
  query += "     mu:uuid #{invoice_id.sparql_escape} ;"
  query += "     p2poInvoice:dateOfIssue ?date ;"
  query += "     p2poInvoice:invoiceNumber ?number ;"
  query += "     p2poInvoice:hasTotalLineNetAmount ?amount ."
  query += "   OPTIONAL { ?invoice dct:type ?type . }"
  query += "   OPTIONAL { ?invoice p2poInvoice:paymentDueDate ?dueDate . }"
  query += "   OPTIONAL { ?invoice crm:paymentDate ?paymentDate . }"
  query += "   OPTIONAL { ?invoice crm:paidDeposits ?paidDeposits . }"
  query += "   OPTIONAL { ?invoice p2poInvoice:paymentTerms ?outro . }"
  query += "   ?case ?caseP ?invoice ;"
  query += "     p2poPrice:hasVATCategoryCode ?vatRate ."
  query += "   FILTER (?caseP = ext:invoice || ?caseP = ext:depositInvoice)"
  query += "   ?vatRate a price:VatRate ;"
  query += "     schema:value ?rate ;"
  query += "     schema:identifier ?vatCode ."
  query += "   OPTIONAL { ?case frapo:hasReferenceNumber ?reference . }"
  query += " } LIMIT 1"

  solution = Mu.query(query).first
  if solution
    {
      id: invoice_id,
      uri: solution[:invoice].value,
      is_credit_note: solution[:type]&.value == 'https://purl.org/p2p-o/invoice#E-CreditNote',
      invoice_date: solution[:date].value,
      number: solution[:number].value,
      amount: solution[:amount].value.to_f,
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

def fetch_calendar_event(id, scope = 'interventions')
  subject_uri = get_resource_uri(scope, id)

  query = " PREFIX ncal: <http://www.semanticdesktop.org/ontologies/2007/04/02/ncal#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " SELECT ?event ?date ?subject"
  query += " WHERE {"
  query += "   ?event a ncal:Event ;"
  query += "     dct:subject <#{subject_uri}> ;"
  query += "     ncal:date ?date ;"
  query += "     ncal:summary ?subject ."
  query += " } LIMIT 1"

  solutions = Mu.query(query)

  events = solutions.map do |solution|
    {
      uri: solution[:event].value,
      date: solution[:date].value,
      subject: solution[:subject].value
    }
  end

  events.first
end

def fetch_telephones(customer_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " SELECT ?telephone ?value ?position ?prefix ?note"
  query += " WHERE {"
  query += "   #{Mu.sparql_escape_uri(customer_uri)} vcard:hasTelephone ?telephone ."
  query += "   ?telephone a vcard:Telephone ;"
  query += "     vcard:hasValue ?value ;"
  query += "     vcard:hasCountryName ?country ;"
  query += "     schema:position ?position ;"
  query += "     dct:type <http://www.w3.org/2006/vcard/ns#Voice> ."
  query += "   ?country a schema:Country ;"
  query += "     crm:telephonePrefix ?prefix ."
  query += "   OPTIONAL { ?telephone vcard:hasNote ?note . }"
  query += " } ORDER BY ?position"

  solutions = Mu.query(query)

  solutions.map do |solution|
    {
      uri: solution[:telephone].value,
      value: solution[:value].value,
      position: solution[:position].value,
      prefix: solution[:prefix].value,
      note: if solution[:note] then solution[:note].value end
    }
  end
end


def fetch_emails(customer_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " SELECT ?email ?value ?note"
  query += " WHERE {"
  query += "   #{Mu.sparql_escape_uri(customer_uri)} vcard:hasEmail ?email ."
  query += "   ?email a vcard:Email ;"
  query += "     vcard:hasValue ?value ."
  query += "   OPTIONAL { ?email vcard:hasNote ?note . }"
  query += " } ORDER BY ?value"

  solutions = Mu.query(query)

  solutions.map do |solution|
    {
      uri: solution[:email].value,
      value: solution[:value].value,
      note: if solution[:note] then solution[:note].value end
    }
  end
end

def fetch_offerlines(id)
  offer_uri = get_resource_uri('offers', id)

  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>"
  query += " SELECT ?offerline ?description ?amount ?vatCode ?rate"
  query += " WHERE {"
  query += "   ?offerline a crm:Offerline ;"
  query += "     dct:isPartOf <#{offer_uri}> ;"
  query += "     schema:amount ?amount ;"
  query += "     price:hasVatRate ?vatRate ;"
  query += "     schema:position ?position ."
  query += "   ?vatRate a price:VatRate ;"
  query += "     schema:value ?rate ;"
  query += "     schema:identifier ?vatCode ."
  query += "   OPTIONAL { ?offerline dct:description ?description . }"
  query += " } ORDER BY ?position"

  solutions = Mu.query(query)

  solutions.map do |solution|
    {
      uri: solution[:offerline].value,
      description: if solution[:description] then solution[:description].value end,
      amount: solution[:amount].value.to_f,
      vat_rate: solution[:rate].value.to_i,
      vat_code: solution[:vatCode].value
    }
  end
end

def fetch_invoicelines(order_uri: nil, invoice_uri: nil)
  order_stmt = if (order_uri) then "?invoiceline dct:isPartOf <#{order_uri}> ." else '' end
  invoice_stmt = if (invoice_uri) then "<#{invoice_uri}> p2poInvoice:hasInvoiceLine ?invoiceline." else '' end

  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>"
  query += " PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>"
  query += " SELECT ?invoiceline ?description ?amount ?rate ?vatCode"
  query += " WHERE {"
  query += "   ?invoiceline a crm:Invoiceline ;"
  query += "     schema:amount ?amount ;"
  query += "     price:hasVatRate ?vatRate ;"
  query += "     schema:position ?position ."
  query += order_stmt
  query += invoice_stmt
  query += "   ?vatRate a price:VatRate ;"
  query += "     schema:value ?rate ;"
  query += "     schema:identifier ?vatCode ."
  query += "   OPTIONAL { ?invoiceline dct:description ?description . }"
  query += " } ORDER BY ?position"

  solutions = Mu.query(query)

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
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX dossier: <https://data.vlaanderen.be/ns/dossier#>"
  query += " PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>"
  query += " PREFIX p2poPrice: <https://purl.org/p2p-o/price#>"
  query += " PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>"
  query += " SELECT ?depositInvoice ?type ?number ?amount"
  query += " WHERE {"
  query += "   ?depositInvoice a p2poInvoice:E-PrePaymentInvoice ;"
  query += "     p2poInvoice:invoiceNumber ?number ;"
  query += "     p2poInvoice:hasTotalLineNetAmount ?amount ."
  query += "   OPTIONAL { ?depositInvoice dct:type ?type . }"
  query += "   ?case ext:depositInvoice ?depositInvoice ."
  query += "   ?case ext:invoice ?invoice ."
  query += "   ?invoice a p2poInvoice:E-FinalInvoice ;"
  query += "     mu:uuid #{invoice_id.sparql_escape} ."
  query += " } ORDER BY ?number"

  solutions = Mu.query(query)

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
  query = " PREFIX person: <http://www.w3.org/ns/person#>"
  query += " PREFIX foaf: <http://xmlns.com/foaf/0.1/>"
  query += " PREFIX frapo: <http://purl.org/cerif/frapo/>"
  query += " SELECT ?employee ?initials"
  query += " WHERE {"
  query += "   ?employee a person:Person ;"
  query += "     foaf:firstName ?firstName ."
  query += "   FILTER(LCASE(?firstName) = #{name.downcase.sparql_escape})"
  query += "   OPTIONAL { ?employee frapo:initial ?initials . }"
  query += " } LIMIT 1"

  solutions = Mu.query(query)
  solution = solutions.first
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
  query = "PREFIX schema: <http://schema.org/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>"
  query += " PREFIX frapo: <http://purl.org/cerif/frapo/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " SELECT ?offer ?request_number ?offer_date ?visitor ?order"
  query += " WHERE {"
  query += "   #{Mu.sparql_escape_uri(customer_uri)} a vcard:VCard ."
  query += "   ?case schema:customer #{Mu.sparql_escape_uri(customer_uri)} ;"
  query += "     ext:request ?request ;"
  query += "     ext:offer ?offer ."
  query += "   ?offer dct:issued ?offer_date ."
  query += "   ?request schema:identifier ?request_number ."
  query += "   OPTIONAL { ?request crm:visitor/frapo:initial ?visitor .}"
  query += "   OPTIONAL { ?case ext:order ?order . }"
  query += "   FILTER (?case != #{Mu.sparql_escape_uri(case_uri)})"
  query += " } ORDER BY DESC(?offer_date) LIMIT 5"

  solutions = Mu.query(query)

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
  solutions = Mu.query %{
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
