# document-generation-service
Document generation service for Rollvolet CRM

## Installation
To add the service to your stack, add the following snippet to `docker-compose.yml`:
```yaml
services:
  documents:
    image: my-build-of-service
```

## Configuration
The following environment variables can be configured:
* `OFFER_TEMPLATE_NL`: absolute path of the offer template in Dutch
* `OFFER_TEMPLATE_FR`: absolute path of the offer template in French

## API
### POST /documents/visit-report
Generates a visit report (PDF file) for a given customer request. The request body must contain a customer request, including the related customer, contact, building, way-of-entry, language and visit.

### POST /documents/offer
Generates an offer (PDF file) for a given offer with a set of offerlines. The request body must contain the visitor initials and an offer. The offer must include the related offerlines with VAT rate, customer, contact, building, request and customer/contact telephones.
