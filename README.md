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
n/a

## API
### POST /documents/visit-report
Generates a visit report (PDF file) for a given customer request. The request body must contain a customer request, including the related customer, contact, building, way-of-entry, language and visit.
