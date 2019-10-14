# document-generation-service
Document generation service for Rollvolet CRM. Documents are generated based on HTML templates in which placeholders will be replaced with actual content.

## Installation
To add the service to your stack, add the following snippet to `docker-compose.yml`:
```yaml
services:
  documents:
    image: rollvolet/document-generation-service
    volumes:
      - ./config/templates:/templates
```

## Configuration
### Templates
The following environment variables can be set to configure the absolute path to the template:
* `OFFER_TEMPLATE_NL`: absolute path of the offer template in Dutch (default: `/templates/offerte-nl.html`)
* `OFFER_TEMPLATE_FR`: absolute path of the offer template in French (default: `/templates/offerte-fr.html`)
* `OFFER_HEADER_TEMPLATE_NL`: absolute path of the offer header template in Dutch (default: `/templates/offerte-header-nl.html`)
* `OFFER_HEADER_TEMPLATE_FR`: absolute path of the offer header template in French (default: `/templates/offerte-header-fr.html`)
* `DEPOSIT_INVOICE_TEMPLATE_NL`: absolute path of the deposit invoice template in Dutch (default: `/templates/voorschotfactuur-nl.html`)
* `DEPOSIT_INVOICE_TEMPLATE_FR`: absolute path of the deposit invoice template in French (default: `/templates/voorschotfactuur-fr.html`)
* `DEPOSIT_INVOICE_HEADER_TEMPLATE_NL`: absolute path of the deposit invoice header template in Dutch (default: `/templates/voorschotfactuur-header-nl.html`)
* `DEPOSIT_INVOICE_HEADER_TEMPLATE_FR`: absolute path of the deposit invoice header template in French (default: `/templates/voorschotfactuur-header-fr.html`)
* `INVOICE_TEMPLATE_NL`: absolute path of the invoice template in Dutch (default: `/templates/factuur-nl.html`)
* `INVOICE_TEMPLATE_FR`: absolute path of the invoice template in French (default: `/templates/factuur-fr.html`)
* `INVOICE_HEADER_TEMPLATE_NL`: absolute path of the invoice header template in Dutch (default: `/templates/factuur-header-nl.html`)
* `INVOICE_HEADER_TEMPLATE_FR`: absolute path of the invoice header template in French (default: `/templates/factuur-header-fr.html`)
* `CREDIT_NOTE_TEMPLATE_NL`: absolute path of the credit note template in Dutch (default: `/templates/creditnota-nl.html`)
* `CREDIT_NOTE_TEMPLATE_FR`: absolute path of the credit note template in French (default: `/templates/creditnota-fr.html`)
* `CREDIT_NOTE_HEADER_TEMPLATE_NL`: absolute path of the credit note header template in Dutch (default: `/templates/creditnota-header-nl.html`)
* `CREDIT_NOTE_HEADER_TEMPLATE_FR`: absolute path of the credit note header template in French (default: `/templates/creditnota-header-fr.html`)
* `CERTIFICATE_TEMPLATE_NL`: absolute path of the VAT certificate template in Dutch (default: `/templates/attest-nl.html`)
* `CERTIFICATE_TEMPLATE_FR`: absolute path of the VAT certificate template in French (default: `/templates/attest-fr.html`)
* `VISIT_REPORT_TEMPLATE_NL`: absolute path of the visit report template in Dutch (default: `/templates/bezoekrapport-nl.html`)
* `FOOTER_TEMPLATE_NL`: absolute path of the footer template in Dutch (default: `/templates/footer-nl.html`)
* `FOOTER_TEMPLATE_FR`: absolute path of the footer template in French (default: `/templates/footer-fr.html`)

The header and footer templates are included in the following documents:
* offer
* deposit invoice
* invoice

### Volumes
All generated files (final output as well as intermediary files) are stored in `/tmp`.

## API
All endpoints receive a JSON body containing the data required to fill in the variables in the templates. The service doesn't query a database itself. The response of each request is a file.

### POST /documents/visit-report
Generates a visit report (PDF file) for a given customer request. The request body must contain a customer request, including the related customer, contact, building, way-of-entry, language and visit.

### POST /documents/offer
Generates an offer (PDF file) for a given offer with a set of offerlines. The request body must contain the visitor initials and an offer. The offer must include the related offerlines with VAT rate, customer, contact, building, request and customer/contact telephones.

### POST /documents/invoice
Generates an invoice or credit note (PDF file) for a given invoice with a set of ordered offerlines.

### POST /documents/deposit-invoice
Generates a deposit invoice (PDF file) for a given deposit invoice with a set of ordered offerlines.

### POST /documents/certificate
Generates a VAT certificate (PDF file) for a given invoice.

