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

def fetch_telephones(data_id, scope = 'customers')
  customer_uri = get_resource_uri(scope, data_id)

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


def fetch_emails(data_id, scope = 'customers')
  customer_uri = get_resource_uri(scope, data_id)

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
