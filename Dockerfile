FROM semtech/mu-ruby-template:feature-ruby-3

LABEL maintainer="erika.pauwels@gmail.com"

RUN apt-get update && apt install -y --allow-unauthenticated fonts-crosextra-carlito
