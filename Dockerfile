ARG MONGODB_VERSION=5.0.3

FROM mongo:${MONGODB_VERSION} AS builder
ARG PWNED_DB_BASE_URL="https://downloads.pwnedpasswords.com/passwords"
ARG PWNED_DB_FILENAME="pwned-passwords-sha1-ordered-by-count-v7.7z"
# Map to env variables
ENV PWNED_DB_BASE_URL="${PWNED_DB_BASE_URL}"
ENV PWNED_DB_FILENAME="${PWNED_DB_FILENAME}"

WORKDIR /tmp

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends curl p7zip-full && \
    curl -O "${PWNED_DB_BASE_URL}/${PWNED_DB_FILENAME}" 
RUN 7z x ${PWNED_DB_FILENAME}

FROM mongo:${MONGODB_VERSION}
LABEL maintainer="Jens Frey <authsec@coffeecrew.org>" Version="2021-10-26"

WORKDIR /tmp

RUN mongod --fork --syslog && \
    cat ${PWNED_DB_FILENAME} | sed 's/:/,/g' | mongoimport --fields "_id.binary(base64),c.int32()" --columnsHaveTypes --db hibp --collection pwndpwds --type csv && \
    mongod --shutdown 