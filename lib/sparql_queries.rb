def fetch_telephones(data_id, scope = 'customers')
  customer_uri = "http://data.rollvolet.be/#{scope}/#{data_id}"
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
      value: solution[:value].value,
      position: solution[:position].value,
      prefix: solution[:prefix].value,
      note: if solution[:note] then solution[:note].value end
    }
  end
end
