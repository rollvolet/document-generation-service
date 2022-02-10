def fetch_telephones(data_id, scope = 'customers')
  customer_uri = get_resource_uri(scope, data_id)

  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " SELECT ?telephone ?value ?position ?prefix ?note"
  query += " WHERE {"
  query += "   GRAPH <http://mu.semte.ch/graphs/rollvolet> {"
  query += "     ?telephone a vcard:Telephone ;"
  query += "       vcard:hasTelephone <#{customer_uri}> ;"
  query += "       vcard:hasValue ?value ;"
  query += "       vcard:hasCountryName ?country ;"
  query += "       schema:position ?position ;"
  query += "       dct:type <http://www.w3.org/2006/vcard/ns#Voice> ."
  query += "     OPTIONAL { ?telephone vcard:hasNote ?note . }"
  query += "   }"
  query += "   GRAPH <http://mu.semte.ch/graphs/public> {"
  query += "     ?country a schema:Country ;"
  query += "       crm:telephonePrefix ?prefix ."
  query += "   }"
  query += " } ORDER BY ?position"

  solutions = Mu.query(query)

  solutions.map do |solution|
    {
      uri: solution[:telephone].value,
      value: solution[:value],
      position: solution[:position],
      prefix: solution[:prefix],
      note: if solution[:note] then solution[:note] end
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
  query += "   GRAPH <http://mu.semte.ch/graphs/rollvolet> {"
  query += "     ?offerline a crm:Offerline ;"
  query += "       dct:isPartOf <#{offer_uri}> ;"
  query += "       schema:amount ?amount ;"
  query += "       price:hasVatRate ?vatRate ;"
  query += "       schema:position ?position ."
  query += "     OPTIONAL { ?offerline dct:description ?description . }"
  query += "   }"
  query += "   GRAPH <http://mu.semte.ch/graphs/public> {"
  query += "     ?vatRate a price:VatRate ;"
  query += "       schema:value ?rate ;"
  query += "       schema:identifier ?vatCode ."
  query += "   }"
  query += " } ORDER BY ?position"

  solutions = Mu.query(query)

  solutions.map do |solution|
    {
      uri: solution[:offerline].value,
      description: if solution[:description] then solution[:description] end,
      amount: solution[:amount].value.to_f,
      vat_rate: solution[:rate].value.to_i,
      vat_code: solution[:vatCode]
    }
  end
end

def fetch_invoicelines(order_id: nil, invoice_id: nil)
  order_statement = ''
  if (order_id)
    order_uri = get_resource_uri('orders', order_id)
    order_statement = "?invoiceline prov:wasDerivedFrom <#{order_uri}> ."
  end

  invoice_statement = ''
  if (invoice_id)
    invoice_uri = get_resource_uri('invoices', invoice_id)
    invoice_statement = "?invoiceline dct:isPartOf <#{invoice_uri}> ."
  end

  query = " PREFIX schema: <http://schema.org/>"
  query += " PREFIX dct: <http://purl.org/dc/terms/>"
  query += " PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>"
  query += " PREFIX price: <http://data.rollvolet.be/vocabularies/pricing/>"
  query += " PREFIX prov: <http://www.w3.org/ns/prov#>"
  query += " SELECT ?invoiceline ?description ?amount ?rate ?vatCode"
  query += " WHERE {"
  query += "   GRAPH <http://mu.semte.ch/graphs/rollvolet> {"
  query += "     ?invoiceline a crm:Invoiceline ;"
  query += "       schema:amount ?amount ;"
  query += "       price:hasVatRate ?vatRate ;"
  query += "       schema:position ?position ."
  query += order_statement
  query += invoice_statement
  query += "     OPTIONAL { ?invoiceline dct:description ?description . }"
  query += "   }"
  query += "   GRAPH <http://mu.semte.ch/graphs/public> {"
  query += "     ?vatRate a price:VatRate ;"
  query += "       schema:value ?rate ;"
  query += "       schema:identifier ?vatCode ."
  query += "   }"
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