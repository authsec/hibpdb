ARG MONGODB_VERSION=5.0.3

FROM mongo:${MONGODB_VERSION}
LABEL maintainer="Jens Frey <authsec@coffeecrew.org>" Version="2021-10-26"

ARG PWNED_DB_BASE_URL="https://downloads.pwnedpasswords.com/passwords"
ARG PWNED_DB_FILENAME="pwned-passwords-sha1-ordered-by-count-v7.7z"
# Map to env variables
ENV PWNED_DB_BASE_URL="${PWNED_DB_BASE_URL}"
ENV PWNED_DB_FILENAME="${PWNED_DB_FILENAME}"

WORKDIR /tmp

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends curl p7zip-full && \
    curl -Ok "${PWNED_DB_BASE_URL}/${PWNED_DB_FILENAME}" && \
    7za x -so ${PWNED_DB_FILENAME} | sed 's/:/,/g' > ${PWNED_DB_FILENAME%.7z}.txt && \
    rm ${PWNED_DB_FILENAME}
 
RUN mongod --fork --syslog && \
    NUM_CPUS=$(lscpu | grep '^CPU(s):' | tr -s ' ' | cut -d' ' -f2) && echo "NUM_CPUS = '${NUM_CPUS}'" && \
    mongoimport --uri "mongodb://localhost:27017/hibp" --fields "_id.binary(base64),c.int32()" --columnsHaveTypes --db hibp --collection pwndpwds --type csv -j ${NUM_CPUS} --file ${PWNED_DB_FILENAME%.7z}.txt && \
    echo "show dbs" | mongo && \
    mongod --shutdown && \
    rm -f ${PWNED_DB_FILENAME} && \
    apt-get purge -y curl p7zip-full && \
    apt-get autoremove -y && \
    apt-get clean && \
    find /var/lib/apt/lists -type f | xargs rm && \
    find /var/log -type f -exec rm {} \; && \
    rm -rf /usr/share/man/* && \
    rm -rf /usr/share/doc/* && \
    rm -f /var/log/alternatives.log /var/log/apt/* && \
    rm -f /var/cache/debconf/*-old