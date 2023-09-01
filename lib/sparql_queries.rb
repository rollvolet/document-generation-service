def fetch_customer_by_case(case_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " SELECT ?uri ?type ?number ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?vat_number ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country"
  query += " WHERE {"
  query += "   #{Mu.sparql_escape_uri(case_uri)} schema:customer ?uri ."
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

def fetch_contact_by_case(case_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX nco: <http://www.semanticdesktop.org/ontologies/2007/03/22/nco#>"
  query += " SELECT ?uri ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country"
  query += " WHERE {"
  query += "   #{Mu.sparql_escape_uri(case_uri)} crm:contact ?uri ."
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

def fetch_building_by_case(case_uri)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
  query += " PREFIX gebouw: <https://data.vlaanderen.be/ns/gebouw#>"
  query += " SELECT ?uri ?hon_prefix ?first_name ?last_name ?suffix ?print_prefix ?print_suffix ?print_suffix_in_front ?language ?language_name ?language_code ?address ?street ?postal_code ?city ?country"
  query += " WHERE {"
  query += "   #{Mu.sparql_escape_uri(case_uri)} crm:building ?uri ."
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
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
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

  solutions = Mu.query(query)

  requests = solutions.map do |solution|
    if solution[:visitor]
      visitor = {
        uri: solution[:visitor].value,
        name: solution[:visitor_name]&.value,
        initials: solution[:visitor_initials]&.value
      }
    end
    {
      uri: solution[:uri].value,
      date: solution[:date].value,
      number: solution[:number].value,
      visitor: visitor,
      employee: solution[:employee]&.value,
      way_of_entry: solution[:way_of_entry]&.value,
      description: solution[:description]&.value,
      case_uri: solution[:case].value
    }
  end

  requests.first
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

def fetch_invoicelines(order_id: nil, invoice_uri: nil)
  order_statement = ''
  if (order_id)
    order_uri = get_resource_uri('orders', order_id)
    order_statement = "?invoiceline prov:wasDerivedFrom <#{order_uri}> ."
  end

  invoice_statement = ''
  if (invoice_uri)
    invoice_statement = "<#{invoice_uri}> p2poInvoice:hasInvoiceLine ?invoiceline."
  end

  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>"
  query += " PREFIX prov: <http://www.w3.org/ns/prov#>"
  query += " PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>"
  query += " SELECT ?invoiceline ?description ?amount ?rate ?vatCode"
  query += " WHERE {"
  query += "   ?invoiceline a crm:Invoiceline ;"
  query += "     schema:amount ?amount ;"
  query += "     price:hasVatRate ?vatRate ;"
  query += "     schema:position ?position ."
  query += order_statement
  query += invoice_statement
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
  query += " SELECT ?invoice ?date ?type ?number ?amount ?rate ?vatCode ?dueDate ?paymentDate ?paidDeposits ?outro ?reference"
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
  query += "   ?case dossier:Dossier.bestaatUit ?invoice ;"
  query += "     p2poPrice:hasVATCategoryCode ?vatRate ."
  query += "   ?vatRate a price:VatRate ;"
  query += "     schema:value ?rate ;"
  query += "     schema:identifier ?vatCode ."
  query += "   OPTIONAL { ?case frapo:hasReferenceNumber ?reference . }"
  query += " } LIMIT 1"

  solutions = Mu.query(query)
  solution = solutions.first
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
      reference: solution[:reference]&.value
    }
  else
    nil
  end
end

def fetch_deposit_invoices_for_invoice(invoice_id)
  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX mu: <http://mu.semte.ch/vocabularies/core/>"
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
  query += "   ?case dossier:Dossier.bestaatUit ?depositInvoice, ?invoice ."
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
