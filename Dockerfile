FROM semtech/mu-ruby-template:2.11.1

LABEL maintainer="erika.pauwels@gmail.com"

RUN apt-get update && apt install -y --allow-unauthenticated fonts-crosextra-carlito

ADD . /usr/src/app
