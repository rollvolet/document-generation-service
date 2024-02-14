FROM semtech/mu-ruby-template:3.1.0

LABEL maintainer="erika.pauwels@gmail.com"

ENV USE_LEGACY_UTILS "false"

RUN apt-get update && apt install -y --allow-unauthenticated fonts-crosextra-carlito
