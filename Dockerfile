FROM erikap/ruby-sinatra:1.0.0

LABEL maintainer="erika.pauwels@gmail.com"

RUN apt-get update && apt install -y --allow-unauthenticated fonts-crosextra-carlito

ADD . /usr/src/app
